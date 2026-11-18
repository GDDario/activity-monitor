import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/subtask_title.dart';
import 'package:app/domain/value_objects/task_notes.dart';
import 'package:app/domain/value_objects/tag_name.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

/// This is the single validation boundary used by Save and editor enablement.
Map<String, String> validateTaskDraft(TaskDraft draft) {
  final errors = <String, String>{};
  void validate(String field, void Function() work) {
    try {
      work();
    } on ArgumentError {
      errors[field] = 'invalid';
    }
  }

  validate('title', () => TaskTitle(draft.title));
  validate('notes', () => TaskNotes(draft.notes));
  if (draft.tags.length > 10) errors['tags'] = 'tooMany';
  if (draft.subtasks.length > 50) errors['subtasks'] = 'tooMany';
  final tagKeys = <String>{};
  final tagIds = <Object>{};
  final subtaskIds = <Object>{};
  for (var i = 0; i < draft.tags.length; i++) {
    validate('tags.$i', () {
      final tag = TagName(draft.tags[i].name);
      if (!tagKeys.add(tag.key) || !tagIds.add(draft.tags[i].id)) {
        throw ArgumentError();
      }
    });
  }
  for (var i = 0; i < draft.subtasks.length; i++) {
    validate('subtasks.$i.title', () => SubtaskTitle(draft.subtasks[i].title));
    if (!subtaskIds.add(draft.subtasks[i].id)) {
      errors['subtasks.$i'] = 'duplicateIdentity';
    }
  }
  validate('schedule', () => scheduleForDraft(draft));
  return Map.unmodifiable(errors);
}

TaskSchedule scheduleForDraft(TaskDraft d, {LocalDate? effectiveFrom}) {
  final enabled =
      d.cadence != TaskCadence.oneTime && (d.isNew || d.recurrenceEnabled);
  return TaskSchedule(
    cadence: d.cadence,
    recurrenceEnabled: enabled,
    startDate: d.startDate,
    effectiveFrom: effectiveFrom ?? d.startDate,
    weeklyDays: d.cadence == TaskCadence.weekly && enabled
        ? d.weeklyDays
        : null,
    timeWindow: d.timeWindow,
    reminder: d.timeWindow == null
        ? const ReminderPreference.off()
        : d.reminder,
    streakEnabled: d.cadence == TaskCadence.daily && enabled && d.streakEnabled,
    dayPeriod: d.cadence == TaskCadence.daily ? d.dayPeriod : null,
  );
}

LocalDate firstTaskOccurrenceDate(TaskSchedule schedule) {
  var date = schedule.startDate;
  if (schedule.recurrenceEnabled && schedule.cadence == TaskCadence.weekly) {
    while (!schedule.matches(date)) {
      date = date.addDays(1);
    }
  }
  return date;
}

class SaveTask {
  const SaveTask(this.repository, {required this.newId, required this.clock});
  final TaskRepository repository;
  final String Function() newId;
  final DateTime Function() clock;
  Future<TaskResult<TaskSaveResult>> execute(
    TaskDraft draft, {
    LocalDateRange? requestedRange,
  }) async {
    final errors = validateTaskDraft(draft);
    if (errors.isNotEmpty) return TaskError(TaskFailure.validation(errors));
    final now = clock();
    final local = now.toLocal();
    final today = LocalDate(local.year, local.month, local.day);
    if (!draft.isNew) return _edit(draft, now.toUtc(), today, requestedRange);
    final schedule = scheduleForDraft(draft);
    final date = firstTaskOccurrenceDate(schedule);
    final task = _task(draft, schedule, 0, now.toUtc(), now.toUtc());
    final occurrence = TaskOccurrence(
      id: draft.occurrenceId,
      taskId: draft.taskId,
      scheduledDate: date,
      effectiveDate: date,
      timeWindow: schedule.timeWindow,
      reminder: schedule.reminder,
      subtaskStates: {for (final s in draft.subtasks) s.id: s.completed},
    );
    final generated = expandTaskOccurrences(
      TaskScheduleSnapshot(task: task),
      requestedRange ?? LocalDateRange(date, date),
      newId,
      excludedSlots: {date},
    );
    return repository.saveTask(
      PreparedTaskSave(
        aggregate: TaskAggregate(task: task, occurrence: occurrence),
        expected: null,
        now: now.toUtc(),
        today: today,
        generated: generated,
      ),
    );
  }

  Task _task(
    TaskDraft draft,
    TaskSchedule schedule,
    int revision,
    DateTime? created,
    DateTime updated, {
    List<TaskParticipant> participants = const [],
    List<TaskSubtask> inactive = const [],
  }) => Task(
    id: draft.taskId,
    title: TaskTitle(draft.title),
    notes: TaskNotes(draft.notes).value,
    priority: draft.priority,
    schedule: schedule,
    revision: revision,
    createdAtUtc: created,
    updatedAtUtc: updated,
    tags: draft.tags
        .map((t) => TaskTag(id: t.id, name: TagName(t.name)))
        .toList(),
    subtasks: [
      ...inactive,
      ...draft.subtasks.indexed.map(
        (e) => TaskSubtask(
          id: e.$2.id,
          title: SubtaskTitle(e.$2.title),
          position: e.$1,
        ),
      ),
    ],
    participants: participants,
  );

  Future<TaskResult<TaskSaveResult>> _edit(
    TaskDraft draft,
    DateTime now,
    LocalDate today,
    LocalDateRange? requestedRange,
  ) async {
    final loaded = await repository.loadTask(draft.taskId, draft.occurrenceId);
    if (!loaded.isSuccess) return TaskError(loaded.failure!);
    final old = loaded.value!;
    final e = draft.expected!;
    if (old.task.revision != e.taskRevision ||
        old.occurrence.revision != e.occurrenceRevision) {
      return TaskError(TaskFailure(TaskFailureCode.staleRevision));
    }
    var schedule = scheduleForDraft(
      draft,
      effectiveFrom: old.task.schedule.effectiveFrom,
    );
    final ruleChanged = !_sameRule(old.task.schedule, schedule);
    final timelineChanged =
        ruleChanged &&
        (old.task.schedule.recurrenceEnabled || schedule.recurrenceEnabled);
    var history = old.history;
    if (timelineChanged) {
      final boundary = today.addDays(1);
      final oldFrom =
          old.task.schedule.effectiveFrom ?? old.task.schedule.startDate;
      history = [
        for (final period in old.history)
          if ((period.schedule.effectiveFrom ?? period.schedule.startDate)
                  .compareTo(boundary) <
              0)
            SchedulePeriod(
              period.schedule,
              until: period.until!.compareTo(boundary) > 0
                  ? boundary
                  : period.until,
            ),
      ];
      if (oldFrom.compareTo(boundary) < 0 &&
          old.task.schedule.startDate.compareTo(boundary) < 0) {
        history.add(SchedulePeriod(old.task.schedule, until: boundary));
      }
      schedule = _withBoundary(schedule, boundary);
    }
    final selectedWindow = draft.hasOccurrenceOverride
        ? draft.occurrenceTimeWindow
        : old.occurrence.timeWindow;
    final selectedReminder = draft.hasOccurrenceOverride
        ? (selectedWindow == null
              ? const ReminderPreference.off()
              : draft.occurrenceReminder)
        : old.occurrence.reminder;
    final oneTime =
        old.task.schedule.cadence == TaskCadence.oneTime &&
        !old.task.schedule.recurrenceEnabled;
    final window = oneTime && !draft.hasOccurrenceOverride
        ? schedule.timeWindow
        : selectedWindow;
    final reminder = oneTime && !draft.hasOccurrenceOverride
        ? schedule.reminder
        : selectedReminder;
    final states = {
      ...old.occurrence.subtaskStates,
      for (final s in draft.subtasks) s.id: s.completed,
    };
    final protectSelected =
        timelineChanged && old.occurrence.scheduledDate.compareTo(today) > 0;
    final occurrenceChanged =
        draft.date != old.occurrence.effectiveDate ||
        window != old.occurrence.timeWindow ||
        reminder != old.occurrence.reminder ||
        !_mapEqual(states, old.occurrence.subtaskStates) ||
        protectSelected && !old.occurrence.isScheduleException;
    final occurrence = old.occurrence.copyWith(
      effectiveDate: draft.date,
      timeWindow: window,
      reminder: reminder,
      subtaskStates: states,
      isScheduleException:
          old.occurrence.isScheduleException || occurrenceChanged,
      revision: old.occurrence.revision + (occurrenceChanged ? 1 : 0),
    );
    final activeIds = draft.subtasks.map((s) => s.id).toSet();
    final inactive = old.task.subtasks
        .where((s) => !activeIds.contains(s.id))
        .map(
          (s) => TaskSubtask(
            id: s.id,
            title: s.title,
            position: s.position,
            active: false,
          ),
        )
        .toList();
    final candidate = _task(
      draft,
      schedule,
      old.task.revision,
      old.task.createdAtUtc,
      now,
      participants: old.task.participants,
      inactive: inactive,
    );
    final sharedChanged = !_sameTaskContent(old.task, candidate);
    if (!sharedChanged && !occurrenceChanged) {
      return TaskSuccess(
        TaskSaveResult(
          old,
          TaskMutationReceipt(
            taskId: old.task.id,
            occurrenceId: old.occurrence.id,
            taskRevision: old.task.revision,
            occurrenceRevision: old.occurrence.revision,
            affectedDates: {
              old.occurrence.scheduledDate,
              old.occurrence.effectiveDate,
            },
            changed: false,
          ),
        ),
      );
    }
    final task = _task(
      draft,
      schedule,
      old.task.revision + (sharedChanged ? 1 : 0),
      old.task.createdAtUtc,
      now,
      participants: old.task.participants,
      inactive: inactive,
    );
    final reconciled = <TaskOccurrence>[];
    final removed = <OccurrenceId>[];
    if (timelineChanged) {
      final future = await repository.loadFutureOccurrences(
        draft.taskId,
        today,
      );
      if (!future.isSuccess) return TaskError(future.failure!);
      for (final o in future.value!) {
        if (o.id == occurrence.id ||
            o.completed ||
            o.isDeleted ||
            o.isScheduleException) {
          continue;
        }
        if (!schedule.recurrenceEnabled || !schedule.matches(o.scheduledDate)) {
          removed.add(o.id);
          continue;
        }
        if (o.timeWindow != schedule.timeWindow ||
            o.reminder != schedule.reminder) {
          reconciled.add(
            o.copyWith(
              timeWindow: schedule.timeWindow,
              reminder: schedule.reminder,
              revision: o.revision + 1,
            ),
          );
        }
      }
    }
    final generated = expandTaskOccurrences(
      TaskScheduleSnapshot(task: task, history: history),
      requestedRange ??
          LocalDateRange(occurrence.effectiveDate, occurrence.effectiveDate),
      newId,
      excludedSlots: {occurrence.scheduledDate},
    );
    return repository.saveTask(
      PreparedTaskSave(
        aggregate: TaskAggregate(
          task: task,
          occurrence: occurrence,
          history: history,
        ),
        expected: e,
        now: now,
        today: today,
        reconciled: reconciled,
        removed: removed,
        generated: generated,
      ),
    );
  }
}

bool _mapEqual(Map<Object, bool> a, Map<Object, bool> b) =>
    {...a.keys, ...b.keys}.every((id) => (a[id] ?? false) == (b[id] ?? false));
bool _sameRule(TaskSchedule a, TaskSchedule b) =>
    a.cadence == b.cadence &&
    a.recurrenceEnabled == b.recurrenceEnabled &&
    a.startDate == b.startDate &&
    a.weeklyDays == b.weeklyDays &&
    a.timeWindow == b.timeWindow &&
    a.reminder == b.reminder;
TaskSchedule _withBoundary(TaskSchedule s, LocalDate from) => TaskSchedule(
  cadence: s.cadence,
  recurrenceEnabled: s.recurrenceEnabled,
  startDate: s.startDate,
  effectiveFrom: from,
  weeklyDays: s.weeklyDays,
  timeWindow: s.timeWindow,
  reminder: s.reminder,
  streakEnabled: s.streakEnabled,
  dayPeriod: s.dayPeriod,
);
bool _sameTaskContent(Task a, Task b) {
  if (a.title != b.title ||
      a.notes != b.notes ||
      a.priority != b.priority ||
      a.schedule != b.schedule) {
    return false;
  }
  final aTags = a.tags.map((t) => t.name.key).toSet();
  final bTags = b.tags.map((t) => t.name.key).toSet();
  if (aTags.length != bTags.length || !aTags.containsAll(bTags)) return false;
  final aSubs = a.subtasks.where((s) => s.active).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  final bSubs = b.subtasks.where((s) => s.active).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  if (aSubs.length != bSubs.length) return false;
  for (var i = 0; i < aSubs.length; i++) {
    if (aSubs[i].id != bSubs[i].id ||
        aSubs[i].title != bSubs[i].title ||
        aSubs[i].position != bSubs[i].position) {
      return false;
    }
  }
  return true;
}
