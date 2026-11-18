import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';

import 'helpers/task_action_fixture.dart';

void main() {
  late TaskActionFixture fixture;
  final instant = DateTime.utc(2027, 1, 1, 2, 30);
  setUp(() => fixture = TaskActionFixture());
  tearDown(() => fixture.repository.dispose());
  test('deletion tombstones one identity and Undo restores its exact state without rewriting shared metadata', () async {
    fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
      completed: true,
      completedAtUtc: instant,
      isScheduleException: true,
    );
    final before = fixture.occurrence;
    final task = fixture.repository.tasks[fixture.taskId];
    final deleted = await DeleteTaskOccurrence(
      fixture.repository,
      now: () => instant,
    ).execute(fixture.id, fixture.expected);
    expect(deleted.isSuccess, isTrue);
    expect(fixture.occurrence.deletedAtUtc, instant);
    expect(fixture.occurrence.completed, isTrue);
    expect(fixture.repository.occurrences, hasLength(2));
    expect(
      fixture.repository.occurrences[fixture.otherId]!.deletedAtUtc,
      isNull,
    );
    final restored = await UndoTaskOccurrenceAction(fixture.repository)
        .execute(deleted.value!.undo!);
    expect(restored.isSuccess, isTrue);
    final after = fixture.occurrence;
    expect(after.id, before.id);
    expect(after.scheduledDate, before.scheduledDate);
    expect(after.effectiveDate, before.effectiveDate);
    expect(after.timeWindow, before.timeWindow);
    expect(after.reminder, before.reminder);
    expect(after.completed, before.completed);
    expect(after.completedAtUtc, before.completedAtUtc);
    expect(after.isScheduleException, before.isScheduleException);
    expect(after.subtaskStates, before.subtaskStates);
    expect(after.deletedAtUtc, isNull);
    expect(after.revision, before.revision + 2);
    expect(fixture.repository.tasks[fixture.taskId], same(task));
  });
  test(
    'completion Undo restores pending state and its original exception flag',
    () async {
      final completed = await CompleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      final restored = await UndoTaskOccurrenceAction(fixture.repository)
          .execute(completed.value!.undo!);
      expect(restored.isSuccess, isTrue);
      expect(fixture.occurrence.completed, isFalse);
      expect(fixture.occurrence.completedAtUtc, isNull);
      expect(fixture.occurrence.isScheduleException, isFalse);
      expect(fixture.occurrence.subtaskStates[fixture.subtaskId], isTrue);
    },
  );
  test(
    'shared metadata edits invalidate Undo without overwriting newer content',
    () async {
      final result = await DeleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      final originalTask = fixture.repository.tasks[fixture.taskId]!;
      final edited = Task(
        id: fixture.taskId,
        title: TaskTitle('Changed'),
        schedule: originalTask.schedule,
        revision: 4,
      );
      fixture.repository.tasks[fixture.taskId] = edited;
      final restored = await UndoTaskOccurrenceAction(fixture.repository)
          .execute(result.value!.undo!);
      expect(restored.failure!.code, TaskFailureCode.staleRevision);
      expect(fixture.repository.tasks[fixture.taskId], same(edited));
      expect(fixture.occurrence.isDeleted, isTrue);
    },
  );
  test(
    'occurrence changes and token replay cannot overwrite newer state',
    () async {
      final result = await DeleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      final undo = UndoTaskOccurrenceAction(fixture.repository);
      expect((await undo.execute(result.value!.undo!)).isSuccess, isTrue);
      final after = fixture.occurrence;
      expect(
        (await undo.execute(result.value!.undo!)).failure!.code,
        TaskFailureCode.staleRevision,
      );
      expect(fixture.occurrence, same(after));
    },
  );
  test(
    'failed restore leaves tombstone and emits no committed change',
    () async {
      final result = await DeleteTaskOccurrence(
        fixture.repository,
        now: () => instant,
      ).execute(fixture.id, fixture.expected);
      final before = fixture.occurrence;
      final changes = <TaskChange>[];
      final subscription = fixture.repository.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      fixture.repository.restoreFailure = TaskFailure(
        TaskFailureCode.storageUnavailable,
      );
      final restored = await UndoTaskOccurrenceAction(fixture.repository)
          .execute(result.value!.undo!);
      expect(restored.failure!.code, TaskFailureCode.storageUnavailable);
      expect(fixture.occurrence, same(before));
      expect(changes, isEmpty);
    },
  );
}
