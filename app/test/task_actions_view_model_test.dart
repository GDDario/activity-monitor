import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';

import 'helpers/task_action_fixture.dart';

TaskMutationReceipt _receipt(
  TaskAggregate aggregate, {
  bool changed = true,
  bool recoverable = true,
}) => TaskMutationReceipt(
  taskId: aggregate.task.id,
  occurrenceId: aggregate.occurrence.id,
  taskRevision: aggregate.task.revision,
  occurrenceRevision: aggregate.occurrence.revision + 1,
  affectedDates: {aggregate.occurrence.effectiveDate},
  changed: changed,
  undo: recoverable
      ? TaskUndoSnapshot(
          before: aggregate.occurrence,
          expected: ExpectedRevisions(
            taskId: aggregate.task.id,
            taskRevision: aggregate.task.revision,
            occurrenceRevision: aggregate.occurrence.revision + 1,
          ),
        )
      : null,
);

void main() {
  late TaskActionFixture fixture;
  late TaskAggregate selected;
  late TaskAggregate other;
  var elapsed = Duration.zero;
  setUp(() {
    fixture = TaskActionFixture();
    selected = fixture.repository.aggregate(fixture.occurrence);
    other = fixture.repository.aggregate(
      fixture.repository.occurrences[fixture.otherId]!,
    );
    elapsed = Duration.zero;
  });
  tearDown(() => fixture.repository.dispose());

  TaskActionsViewModel model({
    OccurrenceCommand? command,
    Future<TaskResult<TaskMutationReceipt>> Function(TaskUndoSnapshot)? undo,
  }) {
    final result = TaskActionsViewModel(
      commands: {
        for (final action in TaskAction.values)
          action:
              command ??
              (id, expected) async => TaskSuccess(
                _receipt(id == selected.occurrence.id ? selected : other),
              ),
      },
      undo:
          undo ??
          (snapshot) async =>
              TaskSuccess(_receipt(selected, recoverable: false)),
      elapsed: () => elapsed,
    );
    addTearDown(result.dispose);
    return result;
  }

  test('Undo retains remaining elapsed time across screen consumers and expires exactly at five active seconds', () async {
    final actions = model();
    await actions.perform(TaskAction.delete, selected);
    elapsed = const Duration(seconds: 2);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 3);
    final anotherScreenConsumer = actions;
    expect(anotherScreenConsumer.remainingSeconds, 3);
    elapsed = const Duration(milliseconds: 4999);
    actions.refreshRemaining();
    expect(actions.canUndo, isTrue);
    elapsed = const Duration(seconds: 5);
    actions.refreshRemaining();
    expect(actions.canUndo, isFalse);
    await actions.undoLatest();
    expect(actions.failure!.code, TaskFailureCode.undoExpired);
  });
  test('keyboard focus and accessibility extensions pause active time and resume the remaining budget', () async {
    final actions = model();
    await actions.perform(TaskAction.delete, selected);
    elapsed = const Duration(seconds: 2);
    actions.setFocused(true);
    elapsed = const Duration(seconds: 20);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 3);
    actions.setFocused(false);
    elapsed = const Duration(seconds: 21);
    actions.setAccessibleNavigation(true);
    expect(actions.remainingSeconds, 2);
    elapsed = const Duration(minutes: 2);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 2);
    actions.setAccessibleNavigation(false);
    elapsed = const Duration(minutes: 2, seconds: 2);
    actions.refreshRemaining();
    expect(actions.canUndo, isFalse);
  });
  test('newer recovery replaces the token and an obsolete sequence never invokes persistence', () async {
    var undoCalls = 0;
    final actions = model(
      undo: (snapshot) async {
        undoCalls++;
        return TaskSuccess(_receipt(other));
      },
    );
    await actions.perform(TaskAction.complete, selected);
    final oldSequence = actions.undoSequence;
    elapsed = const Duration(seconds: 2);
    await actions.perform(TaskAction.delete, other);
    expect(actions.undoSequence, greaterThan(oldSequence));
    expect(actions.remainingSeconds, 5);
    await actions.undoLatest(sequence: oldSequence);
    expect(actions.failure!.code, TaskFailureCode.undoReplaced);
    expect(undoCalls, 0);
    expect(actions.canUndo, isTrue);
    await actions.undoLatest(sequence: actions.undoSequence);
    expect(undoCalls, 1);
    expect(actions.canUndo, isFalse);
  });
  test(
    'a no-op or failed action preserves the current recovery token',
    () async {
      var calls = 0;
      final actions = model(
        command: (id, expected) async {
          calls++;
          if (calls == 2) {
            return TaskSuccess(
              _receipt(selected, changed: false, recoverable: false),
            );
          }
          if (calls == 3) {
            return TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
          }
          return TaskSuccess(_receipt(selected));
        },
      );
      await actions.perform(TaskAction.delete, selected);
      final sequence = actions.undoSequence;
      elapsed = const Duration(seconds: 2);
      actions.refreshRemaining();
      await actions.perform(TaskAction.complete, selected);
      expect(actions.undoSequence, sequence);
      expect(actions.remainingSeconds, 3);
      expect(actions.messageKey, 'taskDeleted');
      await actions.perform(TaskAction.postpone, other);
      expect(actions.failure!.code, TaskFailureCode.storageUnavailable);
      expect(actions.undoSequence, sequence);
      expect(actions.canUndo, isTrue);
    },
  );
  test('one pending occurrence blocks repeated commands but permits independent occurrences', () async {
    final pending = Completer<TaskResult<TaskMutationReceipt>>();
    final ids = <OccurrenceId>[];
    final actions = model(
      command: (id, expected) {
        ids.add(id);
        return id == selected.occurrence.id
            ? pending.future
            : Future.value(TaskSuccess(_receipt(other)));
      },
    );
    final first = actions.perform(TaskAction.complete, selected);
    expect(actions.isPending(selected.occurrence.id), isTrue);
    await actions.perform(TaskAction.delete, selected);
    await actions.perform(TaskAction.delete, other);
    expect(ids, [selected.occurrence.id, other.occurrence.id]);
    pending.complete(TaskSuccess(_receipt(selected)));
    await first;
    expect(actions.isPending(selected.occurrence.id), isFalse);
  });
  test('Undo writes suspend expiry, reject duplicate Undo, and preserve remaining time after a transient failure', () async {
    final pending = Completer<TaskResult<TaskMutationReceipt>>();
    var calls = 0;
    final actions = model(
      undo: (snapshot) {
        calls++;
        return pending.future;
      },
    );
    await actions.perform(TaskAction.delete, selected);
    elapsed = const Duration(seconds: 2);
    actions.refreshRemaining();
    final first = actions.undoLatest();
    expect(actions.isUndoPending, isTrue);
    elapsed = const Duration(seconds: 30);
    actions.refreshRemaining();
    await actions.undoLatest();
    expect(calls, 1);
    pending.complete(
      TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
    );
    await first;
    expect(actions.isUndoPending, isFalse);
    expect(actions.remainingSeconds, 3);
    expect(actions.canUndo, isTrue);
    elapsed = const Duration(seconds: 31);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 2);
  });
  test('Undo and normal commands share the occurrence mutation lock', () async {
    final pending = Completer<TaskResult<TaskMutationReceipt>>();
    var commands = 0;
    final actions = model(
      command: (id, expected) async {
        commands++;
        return TaskSuccess(_receipt(selected));
      },
      undo: (snapshot) => pending.future,
    );
    await actions.perform(TaskAction.delete, selected);
    final undo = actions.undoLatest();
    expect(actions.isPending(selected.occurrence.id), isTrue);
    await actions.perform(TaskAction.complete, selected);
    expect(commands, 1);
    pending.complete(TaskSuccess(_receipt(selected)));
    await undo;
    expect(actions.isPending(selected.occurrence.id), isFalse);
  });
  test(
    'Undo waits while a normal command for its occurrence is pending',
    () async {
      final pending = Completer<TaskResult<TaskMutationReceipt>>();
      var calls = 0;
      var undoCalls = 0;
      final actions = model(
        command: (id, expected) {
          calls++;
          return calls == 1
              ? Future.value(TaskSuccess(_receipt(selected)))
              : pending.future;
        },
        undo: (snapshot) async {
          undoCalls++;
          return TaskSuccess(_receipt(selected));
        },
      );
      await actions.perform(TaskAction.complete, selected);
      final command = actions.perform(TaskAction.reopen, selected);
      await actions.undoLatest();
      expect(undoCalls, 0);
      pending.complete(TaskSuccess(_receipt(selected, recoverable: false)));
      await command;
    },
  );
  test('a stale persisted Undo ends the invalid recovery token', () async {
    var calls = 0;
    final actions = model(
      undo: (snapshot) async {
        calls++;
        return TaskError(TaskFailure(TaskFailureCode.staleRevision));
      },
    );
    await actions.perform(TaskAction.delete, selected);
    await actions.undoLatest();
    expect(actions.failure!.code, TaskFailureCode.staleRevision);
    expect(actions.canUndo, isFalse);
    await actions.undoLatest();
    expect(calls, 1);
  });
  test(
    'an older in-flight Undo failure cannot replace a newer recovery banner',
    () async {
      final pending = Completer<TaskResult<TaskMutationReceipt>>();
      final actions = model(undo: (snapshot) => pending.future);
      await actions.perform(TaskAction.complete, selected);
      final undo = actions.undoLatest();
      await actions.perform(TaskAction.delete, other);
      final latestSequence = actions.undoSequence;
      pending.complete(TaskError(TaskFailure(TaskFailureCode.staleRevision)));
      await undo;
      expect(actions.undoSequence, latestSequence);
      expect(actions.canUndo, isTrue);
      expect(actions.failure, isNull);
      expect(actions.messageKey, 'taskDeleted');
    },
  );
  test('wall-clock changes in command timestamps do not affect elapsed recovery time', () async {
    var wall = DateTime.utc(2026, 11, 7);
    final actions = model(
      command: (id, expected) async {
        final prior = selected.occurrence.copyWith(
          completed: true,
          completedAtUtc: wall,
        );
        return TaskSuccess(
          TaskMutationReceipt(
            taskId: selected.task.id,
            occurrenceId: id,
            taskRevision: selected.task.revision,
            occurrenceRevision: 5,
            affectedDates: {prior.effectiveDate},
            undo: TaskUndoSnapshot(before: prior, expected: selected.expected),
          ),
        );
      },
    );
    await actions.perform(TaskAction.delete, selected);
    wall = DateTime.utc(2036, 11, 7);
    elapsed = const Duration(seconds: 2);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 3);
    wall = DateTime.utc(2006, 11, 7);
    elapsed = const Duration(seconds: 3);
    actions.refreshRemaining();
    expect(actions.remainingSeconds, 2);
  });
  test(
    'disposal closes the recovery window without running an inverse mutation',
    () async {
      var calls = 0;
      final actions = TaskActionsViewModel(
        commands: {
          TaskAction.delete: (id, expected) async =>
              TaskSuccess(_receipt(selected)),
        },
        undo: (snapshot) async {
          calls++;
          return TaskSuccess(_receipt(selected));
        },
        elapsed: () => elapsed,
      );
      await actions.perform(TaskAction.delete, selected);
      actions.dispose();
      expect(actions.canUndo, isFalse);
      await actions.undoLatest();
      expect(calls, 0);
    },
  );
  test(
    'thrown command and Undo failures become safe retryable results',
    () async {
      var failCommand = true;
      final actions = model(
        command: (id, expected) async {
          if (failCommand) {
            throw StateError('private task content');
          }
          return TaskSuccess(_receipt(selected));
        },
        undo: (snapshot) async => throw StateError('private task content'),
      );
      await actions.perform(TaskAction.delete, selected);
      expect(actions.failure!.code, TaskFailureCode.storageUnavailable);
      expect(actions.isPending(selected.occurrence.id), isFalse);
      failCommand = false;
      await actions.perform(TaskAction.delete, selected);
      await actions.undoLatest();
      expect(actions.failure!.code, TaskFailureCode.storageUnavailable);
      expect(actions.canUndo, isTrue);
    },
  );
  test('a committed nonrecoverable change ends the prior token for that same occurrence', () async {
    var calls = 0;
    final actions = model(
      command: (id, expected) async =>
          TaskSuccess(_receipt(selected, recoverable: ++calls == 1)),
    );
    await actions.perform(TaskAction.complete, selected);
    expect(actions.canUndo, isTrue);
    await actions.perform(TaskAction.reopen, selected);
    expect(actions.messageKey, 'taskReopened');
    expect(actions.canUndo, isFalse);
  });

  test('a nonrecoverable change on another occurrence preserves the active recovery message and token', () async {
    var calls = 0;
    final actions = model(
      command: (id, expected) async => TaskSuccess(
        _receipt(
          id == selected.occurrence.id ? selected : other,
          recoverable: ++calls == 1,
        ),
      ),
    );
    await actions.perform(TaskAction.complete, selected);
    final sequence = actions.undoSequence;
    await actions.perform(TaskAction.postpone, other);
    expect(actions.canUndo, isTrue);
    expect(actions.undoSequence, sequence);
    expect(actions.messageKey, 'taskCompleted');
  });
}
