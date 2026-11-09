import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/reopen_task_occurrence.dart';

import 'helpers/task_action_fixture.dart';

void main() {
  late TaskActionFixture fixture;
  final instant = DateTime.utc(2027, 1, 1, 2, 30);
  setUp(() => fixture = TaskActionFixture());
  tearDown(() => fixture.repository.dispose());

  test('completes only the selected occurrence, preserving checklist and shared metadata', () async {
    final task = fixture.repository.tasks[fixture.taskId];
    final before = fixture.occurrence;
    final events = <TaskChange>[];
    final subscription = fixture.repository.changes.listen(events.add);
    addTearDown(subscription.cancel);
    final result = await CompleteTaskOccurrence(
      fixture.repository,
      now: () => instant,
    ).execute(fixture.id, fixture.expected);
    expect(result.isSuccess, isTrue);
    expect(fixture.occurrence.completed, isTrue);
    expect(fixture.occurrence.completedAtUtc, instant);
    expect(fixture.occurrence.revision, 5);
    expect(fixture.occurrence.subtaskStates, before.subtaskStates);
    expect(fixture.repository.occurrences[fixture.otherId]!.completed, isFalse);
    expect(fixture.repository.tasks[fixture.taskId], same(task));
    expect(result.value!.undo!.before, same(before));
    expect(events, hasLength(1));
  });
  test('repeated completion preserves timestamp and returns a no-op without events or Undo', () async {
    fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
      completed: true,
      completedAtUtc: instant,
    );
    final before = fixture.occurrence;
    final result = await CompleteTaskOccurrence(
      fixture.repository,
      now: () => instant.add(const Duration(hours: 1)),
    ).execute(fixture.id, fixture.expected);
    expect(result.isSuccess, isTrue);
    expect(result.value!.changed, isFalse);
    expect(result.value!.undo, isNull);
    expect(fixture.occurrence, same(before));
    expect(fixture.repository.mutationAttempts, 0);
  });
  test('reopening clears unknown or known completion time and protects intentional pending work', () async {
    for (final completionTime in [instant, null]) {
      fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
        completed: true,
        completedAtUtc: completionTime,
      );
      final result = await ReopenTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      expect(result.isSuccess, isTrue);
      expect(fixture.occurrence.completed, isFalse);
      expect(fixture.occurrence.completedAtUtc, isNull);
      expect(fixture.occurrence.isScheduleException, isTrue);
      expect(fixture.occurrence.subtaskStates[fixture.subtaskId], isTrue);
      expect(result.value!.undo, isNull);
    }
  });
  test('reopening a pending occurrence is an idempotent no-op', () async {
    final result = await ReopenTaskOccurrence(
      fixture.repository,
      now: () => instant,
    ).execute(fixture.id, fixture.expected);
    expect(result.value!.changed, isFalse);
    expect(fixture.repository.mutationAttempts, 0);
  });
  test(
    'stale intent is rejected even when its target is already complete',
    () async {
      final stale = fixture.expected;
      fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
        completed: true,
        revision: 5,
      );
      final result = await CompleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, stale);
      expect(result.failure!.code, TaskFailureCode.staleRevision);
      expect(fixture.repository.mutationAttempts, 0);
    },
  );
  test(
    'missing, deleted, stale and unavailable targets do not write',
    () async {
      final action = CompleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      );
      expect(
        (await action.execute(
          OccurrenceId('missing'),
          fixture.expected,
        )).failure!.code,
        TaskFailureCode.notFound,
      );
      fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
        deletedAtUtc: instant,
      );
      expect(
        (await action.execute(fixture.id, fixture.expected)).failure!.code,
        TaskFailureCode.deleted,
      );
      fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
        deletedAtUtc: null,
      );
      fixture.repository.failNext = TaskFailure(
        TaskFailureCode.storageUnavailable,
      );
      expect(
        (await action.execute(fixture.id, fixture.expected)).failure!.code,
        TaskFailureCode.storageUnavailable,
      );
      expect(fixture.repository.mutationAttempts, 0);
    },
  );
  test(
    'failed persistence returns failure without committed state or events',
    () async {
      final before = fixture.occurrence;
      fixture.repository.mutationFailure = TaskFailure(
        TaskFailureCode.storageUnavailable,
      );
      final events = <TaskChange>[];
      final subscription = fixture.repository.changes.listen(events.add);
      addTearDown(subscription.cancel);
      final result = await CompleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      expect(result.failure!.code, TaskFailureCode.storageUnavailable);
      expect(fixture.occurrence, same(before));
      expect(events, isEmpty);
    },
  );
}
