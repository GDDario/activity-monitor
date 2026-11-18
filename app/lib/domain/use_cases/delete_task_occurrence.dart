import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/use_cases/occurrence_action_support.dart';

class DeleteTaskOccurrence {
  DeleteTaskOccurrence(this.repository, {required this.now});
  final TaskRepository repository;
  final DateTime Function() now;
  Future<TaskResult<TaskMutationReceipt>> execute(
    OccurrenceId id,
    ExpectedRevisions expected,
  ) async {
    final loaded = await loadOccurrenceForAction(repository, id, expected);
    final aggregate = loaded.value;
    if (aggregate == null) {
      return TaskError(loaded.failure!);
    }
    final before = aggregate.occurrence;
    return repository.applyOccurrenceChange(
      PreparedOccurrenceChange(
        before: before,
        after: before.copyWith(
          deletedAtUtc: now().toUtc(),
          revision: before.revision + 1,
        ),
        expected: expected,
        undoable: true,
      ),
    );
  }
}
