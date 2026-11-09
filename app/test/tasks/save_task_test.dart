import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';

import '../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repo;
  late SaveTask save;
  var next = 0;
  final now = DateTime.utc(2026, 1, 30, 12);
  String newId() => 'new-${next++}';
  setUp(() {
    next = 0;
    repo = FakeTaskRepository();
    save = SaveTask(repo, newId: newId, clock: () => now);
  });
  tearDown(() => repo.dispose());
  test('invalid drafts never reach storage and return field codes', () async {
    final draft = TaskDraft.newTask(date: LocalDate(2026, 1, 30), newId: newId);
    final result = await save.execute(draft);
    expect(result.failure!.code, TaskFailureCode.validation);
    expect(result.failure!.fields, contains('title'));
    expect(repo.saves, 0);
  });
  test(
    'creation normalizes title, preserves notes and IDs on failed retry',
    () async {
      final draft =
          TaskDraft.newTask(
            date: LocalDate(2026, 1, 30),
            newId: newId,
          ).copyWith(
            title: ' Read ',
            notes: ' a\n ',
            timeWindow: TimeWindow(600, 630),
            reminder: ReminderPreference(5),
          );
      repo.failNext = TaskFailure(TaskFailureCode.storageUnavailable);
      expect((await save.execute(draft)).isSuccess, false);
      expect(repo.tasks, isEmpty);
      final result = await save.execute(draft);
      expect(result.value!.aggregate.task.id, draft.taskId);
      expect(result.value!.aggregate.occurrence.id, draft.occurrenceId);
      expect(result.value!.aggregate.task.title.value, 'Read');
      expect(result.value!.aggregate.task.notes, ' a\n ');
      expect(
        result.value!.aggregate.occurrence.timeWindow,
        TimeWindow(600, 630),
      );
      expect(result.value!.aggregate.task.createdAtUtc, now);
    },
  );
  test(
    'aggregate limits and normalized duplicates fail before storage',
    () async {
      final draft = TaskDraft.newTask(
        date: LocalDate(2026, 1, 30),
        newId: newId,
      ).copyWith(title: 'Read');
      final children = [
        for (var i = 0; i < 51; i++)
          DraftSubtask(id: SubtaskId(newId()), title: 'Child'),
      ];
      expect(
        (await save.execute(draft.copyWith(subtasks: children)))
            .failure!
            .fields['subtasks'],
        'tooMany',
      );
      final tags = [
        for (var i = 0; i < 11; i++)
          DraftTag(id: TagId(newId()), name: 'Tag $i'),
      ];
      expect(
        (await save.execute(draft.copyWith(tags: tags)))
            .failure!
            .fields['tags'],
        'tooMany',
      );
      expect(
        (await save.execute(
          draft.copyWith(
            tags: [
              DraftTag(id: TagId(newId()), name: ' # Café '),
              DraftTag(id: TagId(newId()), name: 'CAFÉ'),
            ],
          ),
        )).failure!.code,
        TaskFailureCode.validation,
      );
      expect(repo.saves, 0);
    },
  );

  test('changing a new draft date changes its saved lower bound and only occurrence', () async {
    final moved = LocalDate(2026, 2, 3);
    final draft = TaskDraft.newTask(
      date: LocalDate(2026, 1, 30),
      newId: newId,
    ).copyWith(title: 'Read', date: moved);
    final saved = (await save.execute(draft)).value!.aggregate;
    expect(saved.task.schedule.startDate, moved);
    expect(saved.occurrence.scheduledDate, moved);
    expect(saved.occurrence.effectiveDate, moved);
    expect(draft.taskId, saved.task.id);
    expect(draft.occurrenceId, saved.occurrence.id);
  });
}
