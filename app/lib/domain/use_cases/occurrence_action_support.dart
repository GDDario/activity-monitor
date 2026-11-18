import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';

Future<TaskResult<TaskAggregate>> loadOccurrenceForAction(
  TaskRepository repository,
  OccurrenceId id,
  ExpectedRevisions expected,
) async {
  final result = await repository.loadTask(expected.taskId, id);
  final aggregate = result.value;
  if (aggregate == null) {
    return result;
  }
  if (aggregate.task.revision != expected.taskRevision ||
      aggregate.occurrence.revision != expected.occurrenceRevision) {
    return TaskError(TaskFailure(TaskFailureCode.staleRevision));
  }
  return result;
}

TaskResult<TaskMutationReceipt> unchangedOccurrence(TaskAggregate aggregate) =>
    TaskSuccess(
      TaskMutationReceipt(
        taskId: aggregate.task.id,
        occurrenceId: aggregate.occurrence.id,
        taskRevision: aggregate.task.revision,
        occurrenceRevision: aggregate.occurrence.revision,
        affectedDates: const {},
        changed: false,
      ),
    );
