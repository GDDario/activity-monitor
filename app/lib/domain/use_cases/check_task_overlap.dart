import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/use_cases/save_task.dart';

class CheckTaskOverlap {
  CheckTaskOverlap(this.repository, {required this.ensure});
  final TaskRepository repository;
  final Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange) ensure;
  Future<TaskResult<bool>> execute(TaskDraft draft) async {
    TaskAggregate? saved;
    if (!draft.isNew) {
      final loaded = await repository.loadTask(
        draft.taskId,
        draft.occurrenceId,
      );
      if (!loaded.isSuccess) {
        return TaskError(loaded.failure!);
      }
      saved = loaded.value!;
      if (saved.occurrence.completed) {
        return const TaskSuccess(false);
      }
    }
    final oneTime =
        saved != null &&
        saved.task.schedule.cadence == TaskCadence.oneTime &&
        !saved.task.schedule.recurrenceEnabled;
    final window = draft.hasOccurrenceOverride
        ? draft.occurrenceTimeWindow
        : saved == null || oneTime
        ? draft.timeWindow
        : saved.occurrence.timeWindow;
    if (window == null) {
      return const TaskSuccess(false);
    }
    var effectiveDate = draft.date;
    if (draft.isNew) {
      try {
        effectiveDate = firstTaskOccurrenceDate(scheduleForDraft(draft));
      } on ArgumentError {
        return TaskError(TaskFailure.validation({'schedule': 'invalid'}));
      }
    }
    final range = LocalDateRange(effectiveDate, effectiveDate);
    final loaded = await ensure(range);
    if (!loaded.isSuccess) {
      return TaskError(loaded.failure!);
    }
    final conflict = loaded.value!.any((candidate) {
      final occurrence = candidate.occurrence;
      final other = occurrence.timeWindow;
      return occurrence.id != draft.occurrenceId &&
          occurrence.effectiveDate == effectiveDate &&
          !occurrence.completed &&
          !occurrence.isDeleted &&
          other != null &&
          taskWindowsOverlap(window, other);
    });
    return TaskSuccess(conflict);
  }
}

/// Intervals are half-open: a task may start exactly when another ends.
bool taskWindowsOverlap(TimeWindow first, TimeWindow second) =>
    first.startMinute < second.endMinute &&
    second.startMinute < first.endMinute;
