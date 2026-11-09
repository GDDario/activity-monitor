import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

abstract class TaskRepository {
  Stream<TaskChange> get changes;
  Future<TaskResult<TaskAggregate>> loadTask(
    TaskId taskId,
    OccurrenceId occurrenceId,
  );
  Future<TaskResult<List<TaskAggregate>>> loadRange(LocalDateRange range);
  Future<TaskResult<List<TaskScheduleSnapshot>>> loadScheduleSnapshot(
    LocalDateRange range,
  );
  Future<TaskResult<List<TaskOccurrence>>> loadFutureOccurrences(
    TaskId taskId,
    LocalDate after,
  );
  Future<TaskResult<List<TaskStreakHistory>>> loadStreakHistory(
    Set<TaskId> taskIds,
    LocalDate throughDate,
  );
  Future<TaskResult<TaskSaveResult>> saveTask(PreparedTaskSave change);
  Future<TaskResult<bool>> ensureOccurrences(
    List<TaskOccurrence> candidates,
    Map<TaskId, int> expectedTaskRevisions,
  );
  Future<TaskResult<TaskMutationReceipt>> applyOccurrenceChange(
    PreparedOccurrenceChange change,
  );
  Future<TaskResult<TaskMutationReceipt>> restoreOccurrence(
    TaskUndoSnapshot snapshot,
  );
  Future<void> dispose();
}
