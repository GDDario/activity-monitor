import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/subtask_title.dart';
import 'package:app/domain/value_objects/task_notes.dart';
import 'package:app/domain/value_objects/tag_name.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

typedef TaskRow = Map<String, Object?>;
TaskRow _map(Object? value) => Map<String, Object?>.from(value as Map);
List<TaskRow> _list(Object? value) => (value as List? ?? []).map(_map).toList();
DateTime? _instant(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();
TimeWindow? _window(TaskRow row) => row['start_minute'] == null
    ? null
    : TimeWindow(row['start_minute'] as int, row['end_minute'] as int);
TaskCadence _cadence(Object? v) => switch (v) {
  'daily' => TaskCadence.daily,
  'weekly' => TaskCadence.weekly,
  'one-time' => TaskCadence.oneTime,
  _ => throw const FormatException('Invalid cadence'),
};

TaskSchedule taskScheduleFromRow(
  TaskRow row, {
  int? weekdayMask,
  bool history = false,
}) => TaskSchedule(
  cadence: _cadence(row['cadence']),
  recurrenceEnabled: row['recurrence_enabled'] == 1,
  startDate: LocalDate.parse(row['start_date'] as String),
  effectiveFrom: row[history ? 'effective_from' : 'rule_effective_date'] == null
      ? null
      : LocalDate.parse(
          row[history ? 'effective_from' : 'rule_effective_date'] as String,
        ),
  weeklyDays: weekdayMask == null || weekdayMask == 0
      ? null
      : WeeklyDays(weekdayMask),
  timeWindow: _window(row),
  reminder: ReminderPreference(row['reminder_minutes_before'] as int?),
  streakEnabled: row['streak_enabled'] == 1,
  dayPeriod: row['day_period'] == null
      ? null
      : DayPeriod.values.byName(row['day_period'] as String),
);
TaskTag _tagFromRow(TaskRow row) {
  final name = TagName(row['name'] as String);
  if (name.key != row['normalized_name']) {
    throw const FormatException('Inconsistent normalized tag');
  }
  return TaskTag(id: TagId(row['id'] as String), name: name);
}

Task taskFromRow(TaskRow graph) {
  final row = _map(graph['task']);
  final mask = _list(graph['weekdays'])
      .fold<int>(0, (value, r) => value | (1 << ((r['weekday'] as int) - 1)));
  final title = TaskTitle.persisted(row['title'] as String);
  final notes = TaskNotes(row['notes'] as String? ?? '').value;
  return Task(
    id: TaskId(row['id'] as String),
    title: title,
    notes: notes,
    priority: TaskPriority.values.byName(row['priority'] as String),
    schedule: taskScheduleFromRow(row, weekdayMask: mask),
    revision: row['revision'] as int,
    createdAtUtc: _instant(row['created_at_utc']),
    updatedAtUtc: _instant(row['updated_at_utc']),
    tags: _list(graph['tags']).map(_tagFromRow).toList(),
    subtasks: _list(graph['subtasks'])
        .map(
          (r) => TaskSubtask(
            id: SubtaskId(r['id'] as String),
            title: SubtaskTitle(r['title'] as String),
            position: r['position'] as int,
            active: r['active'] == 1,
          ),
        )
        .toList(),
    participants: _list(graph['participants'])
        .map((r) => TaskParticipant(r['id'] as String, r['name'] as String))
        .toList(),
  );
}

List<SchedulePeriod> taskHistoryFromRow(TaskRow graph) =>
    _list(graph['history'])
        .map(
          (r) => SchedulePeriod(
            taskScheduleFromRow(
              r,
              weekdayMask: r['weekday_mask'] as int,
              history: true,
            ),
            until: LocalDate.parse(r['effective_until'] as String),
          ),
        )
        .toList();
TaskOccurrence taskOccurrenceFromRow(
  TaskRow row, {
  List<TaskRow> states = const [],
}) => TaskOccurrence(
  id: OccurrenceId(row['id'] as String),
  taskId: TaskId(row['task_id'] as String),
  scheduledDate: LocalDate.parse(row['scheduled_date'] as String),
  effectiveDate: LocalDate.parse(row['effective_date'] as String),
  timeWindow: _window(row),
  reminder: ReminderPreference(row['reminder_minutes_before'] as int?),
  completed: row['completed'] == 1,
  completedAtUtc: _instant(row['completed_at_utc']),
  deletedAtUtc: _instant(row['deleted_at_utc']),
  isScheduleException: row['is_schedule_exception'] == 1,
  revision: row['revision'] as int,
  subtaskStates: {
    for (final r in states)
      SubtaskId(r['subtask_id'] as String): r['completed'] == 1,
  },
);
TaskAggregate taskAggregateFromRow(TaskRow graph) => TaskAggregate(
  task: taskFromRow(graph),
  occurrence: taskOccurrenceFromRow(
    _map(graph['occurrence']),
    states: _list(graph['states']),
  ),
  history: taskHistoryFromRow(graph),
);
