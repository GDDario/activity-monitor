import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';

class UndoTaskOccurrenceAction {
  UndoTaskOccurrenceAction(this.repository);
  final TaskRepository repository;
  Future<TaskResult<TaskMutationReceipt>> execute(TaskUndoSnapshot snapshot) =>
      repository.restoreOccurrence(snapshot);
}
