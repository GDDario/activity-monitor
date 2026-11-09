import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';

import 'helpers/task_action_fixture.dart';

void main() {
  late TaskActionFixture fixture;
  late TaskDraft draft;
  var next = 0;
  setUp(() {
    fixture = TaskActionFixture();
    next = 0;
    draft = TaskDraft.newTask(
      date: LocalDate(2026, 11, 7),
      newId: () => 'new-${next++}',
    ).copyWith(title: 'Read', notes: 'Keep notes');
  });
  tearDown(() => fixture.repository.dispose());
  TaskAggregate aggregate([bool other = false]) => fixture.repository.aggregate(
    other
        ? fixture.repository.occurrences[fixture.otherId]!
        : fixture.occurrence,
  );
  TaskSaveResult saved() {
    final a = aggregate();
    return TaskSaveResult(
      a,
      TaskMutationReceipt(
        taskId: a.task.id,
        occurrenceId: a.occurrence.id,
        taskRevision: a.task.revision,
        occurrenceRevision: a.occurrence.revision,
        affectedDates: {a.occurrence.effectiveDate},
      ),
    );
  }

  TaskEditorViewModel model({
    Map<String, String> Function(TaskDraft)? validate,
    Future<TaskResult<TaskSaveResult>> Function(TaskDraft)? save,
    Future<TaskResult<bool>> Function(TaskDraft)? checkOverlap,
    Future<TaskResult<TaskAggregate>> Function(TaskId, OccurrenceId)? load,
  }) {
    final result = TaskEditorViewModel(
      draft: draft,
      newId: () => 'new-${next++}',
      validate: validate ?? (_) => {},
      save: save ?? (_) async => TaskSuccess(saved()),
      checkOverlap: checkOverlap,
      load: load,
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'a failed save retains the full draft and stable identities for retry',
    () async {
      final editor = model(
        save: (_) async =>
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
      );
      editor.addTag('Books');
      editor.addSubtask();
      editor.changeSubtask(0, title: 'Chapter', completed: true);
      final before = editor.state.draft;
      expect(await editor.save(), isFalse);
      expect(editor.state.draft, same(before));
      expect(editor.state.draft.taskId, draft.taskId);
      expect(editor.state.draft.occurrenceId, draft.occurrenceId);
      expect(editor.state.draft.tags.single.id, before.tags.single.id);
      expect(editor.state.draft.subtasks.single.id, before.subtasks.single.id);
      expect(editor.state.draft.notes, 'Keep notes');
      expect(editor.state.isSaving, isFalse);
      expect(editor.canSave, isTrue);
    },
  );
  for (final code in [
    TaskFailureCode.notFound,
    TaskFailureCode.deleted,
    TaskFailureCode.staleRevision,
    TaskFailureCode.storageUnavailable,
  ]) {
    test(
      'failed existing load $code cannot turn into task creation after typing',
      () async {
        var saves = 0;
        final editor = model(
          load: (taskId, occurrenceId) async => TaskError(TaskFailure(code)),
          save: (_) async {
            saves++;
            return TaskSuccess(saved());
          },
        );
        await editor.loadExisting(fixture.taskId, fixture.id);
        editor.change(
          editor.state.draft.copyWith(title: 'Accidental replacement'),
        );
        final didSave = await editor.save();
        expect(didSave, isFalse);
        expect(editor.canSave, isFalse);
        expect(saves, 0);
        expect(editor.state.failure!.code, code);
      },
    );
  }
  test('a thrown existing load becomes a safe fatal load result and can be retried', () async {
    var attempts = 0;
    final editor = model(
      load: (taskId, occurrenceId) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('private load detail');
        }
        return TaskSuccess(aggregate());
      },
    );
    await expectLater(
      editor.loadExisting(fixture.taskId, fixture.id),
      completes,
    );
    expect(editor.state.isLoading, isFalse);
    expect(editor.state.failure!.code, TaskFailureCode.storageUnavailable);
    expect(editor.canSave, isFalse);
    await editor.loadExisting(fixture.taskId, fixture.id);
    expect(editor.state.draft.taskId, fixture.taskId);
    expect(editor.state.draft.occurrenceId, fixture.id);
    expect(editor.state.failure, isNull);
    expect(editor.canSave, isTrue);
  });
  test(
    'an older load response cannot overwrite a newer requested occurrence',
    () async {
      final first = Completer<TaskResult<TaskAggregate>>();
      final second = Completer<TaskResult<TaskAggregate>>();
      final editor = model(
        load: (taskId, occurrenceId) =>
            occurrenceId == fixture.id ? first.future : second.future,
      );
      final loadFirst = editor.loadExisting(fixture.taskId, fixture.id);
      final loadSecond = editor.loadExisting(fixture.taskId, fixture.otherId);
      second.complete(TaskSuccess(aggregate(true)));
      await loadSecond;
      first.complete(TaskSuccess(aggregate()));
      await loadFirst;
      expect(editor.state.draft.occurrenceId, fixture.otherId);
      expect(editor.state.draft.date, aggregate(true).occurrence.effectiveDate);
    },
  );
  test(
    'a stale failed load response cannot erase a successful newer prefill',
    () async {
      final first = Completer<TaskResult<TaskAggregate>>();
      final editor = model(
        load: (taskId, occurrenceId) => occurrenceId == fixture.id
            ? first.future
            : Future.value(TaskSuccess(aggregate(true))),
      );
      final pending = editor.loadExisting(fixture.taskId, fixture.id);
      await editor.loadExisting(fixture.taskId, fixture.otherId);
      first.complete(TaskError(TaskFailure(TaskFailureCode.notFound)));
      await pending;
      expect(editor.state.draft.occurrenceId, fixture.otherId);
      expect(editor.state.failure, isNull);
      expect(editor.canSave, isTrue);
    },
  );
  test('prefill preserves shared defaults, occurrence exceptions and checklist identities without enabling legacy repeat', () async {
    final original = aggregate();
    final legacy = Task(
      id: original.task.id,
      title: original.task.title,
      notes: original.task.notes,
      priority: original.task.priority,
      schedule: TaskSchedule(
        cadence: TaskCadence.weekly,
        recurrenceEnabled: false,
        startDate: fixture.date,
      ),
      tags: original.task.tags,
      subtasks: original.task.subtasks,
      participants: original.task.participants,
    );
    final loaded = TaskAggregate(
      task: legacy,
      occurrence: original.occurrence.copyWith(isScheduleException: true),
    );
    final editor = model(
      load: (taskId, occurrenceId) async => TaskSuccess(loaded),
    );
    await editor.loadExisting(fixture.taskId, fixture.id);
    final current = editor.state.draft;
    expect(current.expected!.taskId, fixture.taskId);
    expect(current.cadence, TaskCadence.weekly);
    expect(current.recurrenceEnabled, isFalse);
    expect(current.notes, original.task.notes);
    expect(current.tags.single.id, original.task.tags.single.id);
    expect(current.subtasks.single.id, fixture.subtaskId);
    expect(current.subtasks.single.completed, isTrue);
    expect(current.hasOccurrenceOverride, isTrue);
    expect(current.occurrenceTimeWindow, original.occurrence.timeWindow);
    expect(current.occurrenceReminder, original.occurrence.reminder);
    expect(editor.state.isDirty, isFalse);
  });
  test(
    'loading blocks draft and field-error mutation until exact prefill arrives',
    () async {
      final pending = Completer<TaskResult<TaskAggregate>>();
      final editor = model(load: (taskId, occurrenceId) => pending.future);
      final loading = editor.loadExisting(fixture.taskId, fixture.id);
      editor.change(draft.copyWith(title: 'Should not apply'));
      editor.setInputError('title', 'invalid');
      expect(editor.state.draft.title, 'Read');
      pending.complete(TaskSuccess(aggregate()));
      await loading;
      expect(editor.state.fieldErrors, isEmpty);
      expect(editor.canSave, isTrue);
    },
  );
  test('save blocks repeated commands, mutation, dismissal and new loads while retaining retry state', () async {
    final pending = Completer<TaskResult<TaskSaveResult>>();
    var saves = 0;
    var loads = 0;
    final editor = model(
      save: (_) {
        saves++;
        return pending.future;
      },
      load: (taskId, occurrenceId) async {
        loads++;
        return TaskSuccess(aggregate());
      },
    );
    expect(editor.requestDismissal(), DraftDismissal.close);
    editor.change(draft.copyWith(notes: 'Dirty notes'));
    final before = editor.state.draft;
    expect(editor.requestDismissal(), DraftDismissal.confirmDiscard);
    final saving = editor.save();
    expect(editor.state.isSaving, isTrue);
    expect(editor.requestDismissal(), DraftDismissal.blocked);
    editor.change(draft.copyWith(title: 'Should not apply'));
    editor.setInputError('title', 'invalid');
    editor.addTag('Should not apply');
    await editor.loadExisting(fixture.taskId, fixture.id);
    expect(await editor.save(), isFalse);
    expect(saves, 1);
    expect(loads, 0);
    expect(editor.state.draft, same(before));
    pending.complete(
      TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
    );
    expect(await saving, isFalse);
    expect(editor.canSave, isTrue);
    expect(editor.requestDismissal(), DraftDismissal.confirmDiscard);
    expect(editor.state.draft, same(before));
  });
  test('successful save closes the dirty draft and ignores later edits or save commands', () async {
    var saves = 0;
    final editor = model(
      save: (_) async {
        saves++;
        return TaskSuccess(saved());
      },
    );
    editor.change(draft.copyWith(notes: 'Saved notes'));
    final before = editor.state.draft;
    expect(await editor.save(), isTrue);
    expect(editor.state.hasSaved, isTrue);
    expect(editor.state.isDirty, isFalse);
    expect(editor.requestDismissal(), DraftDismissal.close);
    editor.change(draft.copyWith(title: 'Late edit'));
    expect(editor.state.draft, same(before));
    expect(await editor.save(), isFalse);
    expect(saves, 1);
  });
  test(
    'invalid Save exposes domain field identifiers and performs no persistence',
    () async {
      var saves = 0;
      final editor = model(
        validate: (_) => {'title': 'required', 'notes': 'tooLong'},
        save: (_) async {
          saves++;
          return TaskSuccess(saved());
        },
      );
      expect(await editor.save(), isFalse);
      expect(editor.state.showErrors, isTrue);
      expect(editor.firstInvalidField, 'title');
      expect(editor.state.fieldErrors['notes'], 'tooLong');
      expect(saves, 0);
    },
  );
  test('a thrown submission advisory does not block a valid save', () async {
    var saves = 0;
    final editor = model(
      checkOverlap: (_) async => throw StateError('private advisory detail'),
      save: (_) async {
        saves++;
        return TaskSuccess(saved());
      },
    );
    expect(await editor.save(), isTrue);
    expect(saves, 1);
    expect(editor.state.hasSaved, isTrue);
  });
  test(
    'an unavailable or overlapping advisory remains nonblocking at submission',
    () async {
      for (final advisory in <TaskResult<bool>>[
        TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
        const TaskSuccess(true),
      ]) {
        var saves = 0;
        final editor = model(
          checkOverlap: (_) async => advisory,
          save: (_) async {
            saves++;
            return TaskSuccess(saved());
          },
        );
        expect(await editor.save(), isTrue);
        expect(saves, 1);
      }
    },
  );
  testWidgets(
    'advisory debounce requests only the newest draft after 250 milliseconds',
    (tester) async {
      final titles = <String>[];
      final editor = model(
        checkOverlap: (draft) async {
          titles.add(draft.title);
          return const TaskSuccess(false);
        },
      );
      editor.change(draft.copyWith(title: 'First'));
      await tester.pump(const Duration(milliseconds: 200));
      editor.change(draft.copyWith(title: 'Second'));
      await tester.pump(const Duration(milliseconds: 249));
      expect(titles, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(titles, ['Second']);
    },
  );
  testWidgets(
    'stale advisory completion cannot overwrite a newer warning or safe error state',
    (tester) async {
      final first = Completer<TaskResult<bool>>();
      final second = Completer<TaskResult<bool>>();
      var calls = 0;
      final editor = model(
        checkOverlap: (_) => ++calls == 1 ? first.future : second.future,
      );
      editor.change(draft.copyWith(title: 'First'));
      await tester.pump(const Duration(milliseconds: 250));
      editor.change(draft.copyWith(title: 'Second'));
      await tester.pump(const Duration(milliseconds: 250));
      second.complete(const TaskSuccess(true));
      await tester.pump();
      first.complete(
        TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
      );
      await tester.pump();
      expect(editor.state.overlaps, isTrue);
      expect(editor.state.failure, isNull);
      expect(editor.state.draft.title, 'Second');
    },
  );
  testWidgets(
    'a thrown debounced advisory becomes a safe unavailable state without erasing the draft',
    (tester) async {
      final editor = model(
        checkOverlap: (_) async => throw StateError('private advisory detail'),
      );
      editor.change(draft.copyWith(title: 'Keep this'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(editor.state.failure!.code, TaskFailureCode.storageUnavailable);
      expect(editor.state.overlaps, isNull);
      expect(editor.state.draft.title, 'Keep this');
      expect(editor.canSave, isTrue);
    },
  );
  testWidgets(
    'submission invalidates an older advisory response and rechecks the selected draft once',
    (tester) async {
      final first = Completer<TaskResult<bool>>();
      var calls = 0;
      final editor = model(
        checkOverlap: (_) =>
            ++calls == 1 ? first.future : Future.value(const TaskSuccess(true)),
      );
      editor.change(draft.copyWith(title: 'Selected draft'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(await editor.save(), isTrue);
      first.complete(const TaskSuccess(false));
      await tester.pump();
      expect(calls, 2);
      expect(editor.state.hasSaved, isTrue);
      expect(editor.state.overlaps, isTrue);
    },
  );
}
