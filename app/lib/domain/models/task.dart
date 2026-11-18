import 'package:app/domain/models/task_schedule.dart';
import 'package:app/domain/models/task_occurrence.dart';
import 'package:app/domain/models/task_subtask.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/task_notes.dart';
import 'package:app/domain/value_objects/tag_name.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

export 'task_schedule.dart';
export 'task_occurrence.dart';
export 'task_subtask.dart';

enum TaskPriority { low, medium, high }

class TaskTag {
  const TaskTag({required this.id, required this.name});
  final TagId id;
  final TagName name;
}

class DraftTag {
  const DraftTag({required this.id, required this.name});
  final TagId id;
  final String name;
}

class TaskParticipant {
  const TaskParticipant(this.id, this.name);
  final String id;
  final String name;
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.priority = TaskPriority.low,
    required this.schedule,
    this.revision = 0,
    this.createdAtUtc,
    this.updatedAtUtc,
    List<TaskTag> tags = const [],
    List<TaskSubtask> subtasks = const [],
    List<TaskParticipant> participants = const [],
  }) : tags = List.unmodifiable(tags),
       subtasks = List.unmodifiable(subtasks),
       participants = List.unmodifiable(participants) {
    if (revision < 0 ||
        tags.length > 10 ||
        subtasks.where((s) => s.active).length > 50) {
      throw ArgumentError('Invalid task state');
    }
    TaskNotes(notes);
  }
  final TaskId id;
  final TaskTitle title;
  final String notes;
  final TaskPriority priority;
  final TaskSchedule schedule;
  final int revision;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;
  final List<TaskTag> tags;
  final List<TaskSubtask> subtasks;
  final List<TaskParticipant> participants;
}

class SchedulePeriod {
  const SchedulePeriod(this.schedule, {this.until});
  final TaskSchedule schedule;
  final LocalDate? until;
}

class TaskAggregate {
  TaskAggregate({
    required this.task,
    required this.occurrence,
    List<SchedulePeriod> history = const [],
  }) : history = List.unmodifiable(history) {
    if (task.id != occurrence.taskId) {
      throw ArgumentError('Invalid occurrence owner');
    }
    _validateHistory(task.schedule, history);
  }
  final Task task;
  final TaskOccurrence occurrence;
  final List<SchedulePeriod> history;
  ExpectedRevisions get expected => ExpectedRevisions(
    taskId: task.id,
    taskRevision: task.revision,
    occurrenceRevision: occurrence.revision,
  );
  int get subtaskTotal => task.subtasks.where((s) => s.active).length;
  int get subtaskCompleted => task.subtasks
      .where((s) => s.active && occurrence.subtaskStates[s.id] == true)
      .length;
}

class ExpectedRevisions {
  const ExpectedRevisions({
    required this.taskId,
    required this.taskRevision,
    required this.occurrenceRevision,
  });
  final TaskId taskId;
  final int taskRevision;
  final int occurrenceRevision;
}

const _keep = Object();

class TaskDraft {
  TaskDraft({
    required this.taskId,
    required this.occurrenceId,
    required this.date,
    LocalDate? startDate,
    this.title = '',
    this.notes = '',
    this.priority = TaskPriority.low,
    this.cadence = TaskCadence.oneTime,
    this.recurrenceEnabled = false,
    this.weeklyDays,
    this.timeWindow,
    this.reminder = const ReminderPreference.off(),
    this.streakEnabled = false,
    this.dayPeriod,
    this.occurrenceTimeWindow,
    this.occurrenceReminder = const ReminderPreference.off(),
    this.hasOccurrenceOverride = false,
    List<DraftTag> tags = const [],
    List<DraftSubtask> subtasks = const [],
    this.expected,
  }) : startDate = startDate ?? date,
       tags = List.unmodifiable(tags),
       subtasks = List.unmodifiable(subtasks);
  factory TaskDraft.newTask({
    required LocalDate date,
    required String Function() newId,
  }) => TaskDraft(
    taskId: TaskId(newId()),
    occurrenceId: OccurrenceId(newId()),
    date: date,
  );
  factory TaskDraft.fromAggregate(TaskAggregate value) {
    final t = value.task;
    final o = value.occurrence;
    final s = t.schedule;
    return TaskDraft(
      taskId: t.id,
      occurrenceId: o.id,
      date: o.effectiveDate,
      startDate: s.startDate,
      title: t.title.value,
      notes: t.notes,
      priority: t.priority,
      cadence: s.cadence,
      recurrenceEnabled: s.recurrenceEnabled,
      weeklyDays: s.weeklyDays,
      timeWindow: s.timeWindow,
      reminder: s.reminder,
      streakEnabled: s.streakEnabled,
      dayPeriod: s.dayPeriod,
      occurrenceTimeWindow: o.timeWindow,
      occurrenceReminder: o.reminder,
      hasOccurrenceOverride:
          s.cadence != TaskCadence.oneTime &&
          (o.timeWindow != s.timeWindow || o.reminder != s.reminder),
      tags: t.tags.map((e) => DraftTag(id: e.id, name: e.name.value)).toList(),
      subtasks: t.subtasks
          .where((e) => e.active)
          .map(
            (e) => DraftSubtask(
              id: e.id,
              title: e.title.value,
              completed: o.subtaskStates[e.id] ?? false,
            ),
          )
          .toList(),
      expected: value.expected,
    );
  }
  final TaskId taskId;
  final OccurrenceId occurrenceId;
  final LocalDate date;
  final LocalDate startDate;
  final String title;
  final String notes;
  final TaskPriority priority;
  final TaskCadence cadence;
  final bool recurrenceEnabled;
  final WeeklyDays? weeklyDays;
  final TimeWindow? timeWindow;
  final ReminderPreference reminder;
  final bool streakEnabled;
  final DayPeriod? dayPeriod;
  final TimeWindow? occurrenceTimeWindow;
  final ReminderPreference occurrenceReminder;
  final bool hasOccurrenceOverride;
  final List<DraftTag> tags;
  final List<DraftSubtask> subtasks;
  final ExpectedRevisions? expected;
  bool get isNew => expected == null;
  TaskDraft copyWith({
    LocalDate? date,
    LocalDate? startDate,
    String? title,
    String? notes,
    TaskPriority? priority,
    TaskCadence? cadence,
    bool? recurrenceEnabled,
    Object? weeklyDays = _keep,
    Object? timeWindow = _keep,
    ReminderPreference? reminder,
    bool? streakEnabled,
    Object? dayPeriod = _keep,
    Object? occurrenceTimeWindow = _keep,
    ReminderPreference? occurrenceReminder,
    bool? hasOccurrenceOverride,
    List<DraftTag>? tags,
    List<DraftSubtask>? subtasks,
  }) => TaskDraft(
    taskId: taskId,
    occurrenceId: occurrenceId,
    date: date ?? this.date,
    startDate: startDate ?? (isNew && date != null ? date : this.startDate),
    title: title ?? this.title,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    cadence: cadence ?? this.cadence,
    recurrenceEnabled: recurrenceEnabled ?? this.recurrenceEnabled,
    weeklyDays: identical(weeklyDays, _keep)
        ? this.weeklyDays
        : weeklyDays as WeeklyDays?,
    timeWindow: identical(timeWindow, _keep)
        ? this.timeWindow
        : timeWindow as TimeWindow?,
    reminder: reminder ?? this.reminder,
    streakEnabled: streakEnabled ?? this.streakEnabled,
    dayPeriod: identical(dayPeriod, _keep)
        ? this.dayPeriod
        : dayPeriod as DayPeriod?,
    occurrenceTimeWindow: identical(occurrenceTimeWindow, _keep)
        ? this.occurrenceTimeWindow
        : occurrenceTimeWindow as TimeWindow?,
    occurrenceReminder: occurrenceReminder ?? this.occurrenceReminder,
    hasOccurrenceOverride: hasOccurrenceOverride ?? this.hasOccurrenceOverride,
    tags: tags ?? this.tags,
    subtasks: subtasks ?? this.subtasks,
    expected: expected,
  );
}

class TaskChange {
  TaskChange({
    required Set<TaskId> taskIds,
    required Set<LocalDate> dates,
    this.sharedMetadataChanged = false,
  }) : taskIds = Set.unmodifiable(taskIds),
       dates = Set.unmodifiable(dates);
  final Set<TaskId> taskIds;
  final Set<LocalDate> dates;
  final bool sharedMetadataChanged;
}

class TaskUndoSnapshot {
  const TaskUndoSnapshot({required this.before, required this.expected});
  final TaskOccurrence before;
  final ExpectedRevisions expected;
}

class TaskMutationReceipt {
  TaskMutationReceipt({
    required this.taskId,
    required this.occurrenceId,
    required this.taskRevision,
    required this.occurrenceRevision,
    required Set<LocalDate> affectedDates,
    this.changed = true,
    this.undo,
  }) : affectedDates = Set.unmodifiable(affectedDates);
  final TaskId taskId;
  final OccurrenceId occurrenceId;
  final int taskRevision;
  final int occurrenceRevision;
  final Set<LocalDate> affectedDates;
  final bool changed;
  final TaskUndoSnapshot? undo;
}

class TaskSaveResult {
  const TaskSaveResult(this.aggregate, this.receipt);
  final TaskAggregate aggregate;
  final TaskMutationReceipt receipt;
}

class TaskScheduleSnapshot {
  TaskScheduleSnapshot({
    required this.task,
    List<SchedulePeriod> history = const [],
  }) : history = List.unmodifiable(history) {
    _validateHistory(task.schedule, history);
  }
  final Task task;
  final List<SchedulePeriod> history;
}

class TaskStreakHistory {
  TaskStreakHistory({
    required this.snapshot,
    required List<TaskOccurrence> occurrences,
  }) : occurrences = List.unmodifiable(occurrences);
  final TaskScheduleSnapshot snapshot;
  final List<TaskOccurrence> occurrences;
}

class PreparedTaskSave {
  PreparedTaskSave({
    required this.aggregate,
    required this.expected,
    required this.now,
    required this.today,
    List<TaskOccurrence> reconciled = const [],
    List<OccurrenceId> removed = const [],
    List<TaskOccurrence> generated = const [],
  }) : reconciled = List.unmodifiable(reconciled),
       removed = List.unmodifiable(removed),
       generated = List.unmodifiable(generated);
  final TaskAggregate aggregate;
  final ExpectedRevisions? expected;
  final DateTime now;
  final LocalDate today;
  final List<TaskOccurrence> reconciled;
  final List<TaskOccurrence> generated;
  final List<OccurrenceId> removed;
}

class PreparedOccurrenceChange {
  const PreparedOccurrenceChange({
    required this.before,
    required this.after,
    required this.expected,
    this.undoable = false,
  });
  final TaskOccurrence before;
  final TaskOccurrence after;
  final ExpectedRevisions expected;
  final bool undoable;
}

void _validateHistory(TaskSchedule current, List<SchedulePeriod> history) {
  LocalDate? previousUntil;
  for (final period in history) {
    final from = period.schedule.effectiveFrom ?? period.schedule.startDate;
    final until = period.until;
    if (until == null ||
        from.compareTo(until) >= 0 ||
        previousUntil != null && previousUntil.compareTo(from) > 0) {
      throw ArgumentError('Invalid schedule history');
    }
    previousUntil = until;
  }
  if (previousUntil != null &&
      previousUntil.compareTo(current.effectiveFrom ?? current.startDate) > 0) {
    throw ArgumentError('Overlapping schedule history');
  }
}
