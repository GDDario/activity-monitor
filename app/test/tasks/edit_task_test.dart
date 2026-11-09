import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/time_window.dart';

import '../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repo;
  late SaveTask save;
  var next = 0;
  String newId() => 'e-${next++}';
  setUp(() {
    repo = FakeTaskRepository();
    save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
  });
  tearDown(() => repo.dispose());
  test(
    'unchanged Save is a no-op and leaves revisions and events intact',
    () async {
      final initial = (await save.execute(
        TaskDraft.newTask(
          date: LocalDate(2026, 1, 30),
          newId: newId,
        ).copyWith(title: 'Read'),
      )).value!.aggregate;
      final result = (await save.execute(TaskDraft.fromAggregate(initial)))
          .value!;
      expect(result.receipt.changed, false);
      expect(result.aggregate.task.revision, 0);
      expect(repo.saves, 1);
    },
  );
  test(
    'stale edit rejects newer data and never falls back to create',
    () async {
      final initial = (await save.execute(
        TaskDraft.newTask(
          date: LocalDate(2026, 1, 30),
          newId: newId,
        ).copyWith(title: 'Read'),
      )).value!.aggregate;
      final stale = TaskDraft.fromAggregate(initial).copyWith(title: 'Stale');
      expect(
        (await save.execute(
          TaskDraft.fromAggregate(initial).copyWith(title: 'New'),
        )).isSuccess,
        true,
      );
      expect(
        (await save.execute(stale)).failure!.code,
        TaskFailureCode.staleRevision,
      );
      expect(repo.tasks[initial.task.id]!.title.value, 'New');
      expect(repo.tasks.length, 1);
    },
  );
  test('reordering/renaming retains child state; removal retains inactive definitions', () async {
    final first = SubtaskId(newId());
    final second = SubtaskId(newId());
    final draft = TaskDraft.newTask(date: LocalDate(2026, 1, 30), newId: newId)
        .copyWith(
          title: 'Read',
          subtasks: [
            DraftSubtask(id: first, title: 'First', completed: true),
            DraftSubtask(id: second, title: 'Second', completed: true),
          ],
        );
    final initial = (await save.execute(draft)).value!.aggregate;
    final reordered = (await save.execute(
      TaskDraft.fromAggregate(initial).copyWith(
        subtasks: [
          DraftSubtask(id: second, title: 'Renamed', completed: true),
          DraftSubtask(id: first, title: 'First', completed: true),
        ],
      ),
    )).value!.aggregate;
    expect(reordered.task.subtasks.where((s) => s.active).map((s) => s.id), [
      second,
      first,
    ]);
    expect(reordered.subtaskCompleted, 2);
    expect(reordered.occurrence.completed, false);
    final removed = (await save.execute(
      TaskDraft.fromAggregate(reordered).copyWith(
        subtasks: [DraftSubtask(id: second, title: 'Renamed', completed: true)],
      ),
    )).value!.aggregate;
    expect(
      removed.task.subtasks.singleWhere((s) => s.id == first).active,
      false,
    );
    expect(removed.occurrence.subtaskStates[first], true);
    expect(removed.subtaskTotal, 1);
  });
  test(
    'completed one-time tasks still edit their only effective window',
    () async {
      final initial = (await save.execute(
        TaskDraft.newTask(
          date: LocalDate(2026, 1, 30),
          newId: newId,
        ).copyWith(title: 'Read', timeWindow: TimeWindow(600, 630)),
      )).value!.aggregate;
      repo.occurrences[initial.occurrence.id] = initial.occurrence.copyWith(
        completed: true,
        completedAtUtc: DateTime.utc(2026, 1, 30, 12),
        isScheduleException: true,
        revision: 1,
      );
      final current = (await repo.loadTask(
        initial.task.id,
        initial.occurrence.id,
      )).value!;
      final draft = TaskDraft.fromAggregate(current)
          .copyWith(timeWindow: TimeWindow(700, 730));
      final saved = (await save.execute(draft)).value!.aggregate;
      expect(saved.occurrence.timeWindow, TimeWindow(700, 730));
      expect(saved.occurrence.completed, true);
    },
  );
}
