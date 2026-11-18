import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/time_window.dart';

final homeDay = LocalDate(2026, 11, 17);
TaskAggregate homeTask(
  String id, {
  String? title,
  String notes = '',
  int? minute,
  bool completed = false,
  bool deleted = false,
  LocalDate? date,
  DayPeriod? period,
  List<TaskParticipant> participants = const [],
}) => TaskAggregate(
  task: Task(
    id: TaskId(id),
    title: TaskTitle(title ?? id),
    notes: notes,
    participants: participants,
    schedule: TaskSchedule(
      cadence: period == null ? TaskCadence.oneTime : TaskCadence.daily,
      recurrenceEnabled: period != null,
      startDate: homeDay,
      dayPeriod: period,
    ),
  ),
  occurrence: TaskOccurrence(
    id: OccurrenceId('occ-$id'),
    taskId: TaskId(id),
    scheduledDate: homeDay,
    effectiveDate: date ?? homeDay,
    timeWindow: minute == null ? null : TimeWindow(minute, minute + 30),
    completed: completed,
    deletedAtUtc: deleted ? DateTime.utc(2026, 11, 17) : null,
  ),
);
