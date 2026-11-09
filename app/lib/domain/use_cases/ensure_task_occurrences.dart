import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

/// Resolves archived half-open periods before the newest effective rule.
TaskSchedule? scheduleAt(TaskScheduleSnapshot snapshot, LocalDate date) {
  final current = snapshot.task.schedule;
  if (date.compareTo(current.effectiveFrom ?? current.startDate) >= 0) {
    return current;
  }
  for (final period in snapshot.history.reversed) {
    if (date.compareTo(
              period.schedule.effectiveFrom ?? period.schedule.startDate,
            ) >=
            0 &&
        (period.until == null || date.compareTo(period.until!) < 0)) {
      return period.schedule;
    }
  }
  return null;
}

List<TaskOccurrence> expandTaskOccurrences(
  TaskScheduleSnapshot snapshot,
  LocalDateRange range,
  String Function() newId, {
  Set<LocalDate> excludedSlots = const {},
}) {
  final candidates = <TaskOccurrence>[];
  var date = range.start;
  while (true) {
    final schedule = scheduleAt(snapshot, date);
    if (schedule != null &&
        schedule.recurrenceEnabled &&
        schedule.matches(date) &&
        !excludedSlots.contains(date)) {
      candidates.add(
        TaskOccurrence(
          id: OccurrenceId(newId()),
          taskId: snapshot.task.id,
          scheduledDate: date,
          effectiveDate: date,
          timeWindow: schedule.timeWindow,
          reminder: schedule.reminder,
        ),
      );
    }
    if (date == range.end) break;
    date = date.addDays(1);
  }
  return candidates;
}

class EnsureTaskOccurrences {
  const EnsureTaskOccurrences(this.repository, {required this.newId});
  final TaskRepository repository;
  final String Function() newId;
  Future<TaskResult<List<TaskAggregate>>> execute(LocalDateRange range) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final loaded = await repository.loadScheduleSnapshot(range);
      if (!loaded.isSuccess) return TaskError(loaded.failure!);
      final candidates = <TaskOccurrence>[];
      for (final snapshot in loaded.value!) {
        candidates.addAll(expandTaskOccurrences(snapshot, range, newId));
      }
      final result = await repository.ensureOccurrences(candidates, {
        for (final snapshot in loaded.value!)
          snapshot.task.id: snapshot.task.revision,
      });
      if (result.isSuccess) return repository.loadRange(range);
      if (result.failure!.code != TaskFailureCode.staleRevision ||
          attempt == 1) {
        return TaskError(result.failure!);
      }
    }
    return TaskError(TaskFailure(TaskFailureCode.staleRevision));
  }
}
