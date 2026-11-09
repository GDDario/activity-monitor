import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/use_cases/occurrence_action_support.dart';

class PostponeTaskOccurrence {
  PostponeTaskOccurrence(this.repository, {required this.now});
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
    if (before.completed) {
      return TaskError(TaskFailure(TaskFailureCode.invalidTransition));
    }
    final local = now().toLocal();
    final tomorrow = LocalDate(local.year, local.month, local.day).addDays(1);
    if (before.effectiveDate == tomorrow) {
      return unchangedOccurrence(aggregate);
    }
    return repository.applyOccurrenceChange(
      PreparedOccurrenceChange(
        before: before,
        after: before.copyWith(
          effectiveDate: tomorrow,
          isScheduleException: true,
          revision: before.revision + 1,
        ),
        expected: expected,
      ),
    );
  }
}
