import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

import '../helpers/task_migration_fixture.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalTaskRepository repo;
  var next = 0;
  final today = LocalDate(2026, 1, 30);
  String newId() => 'write-${next++}';
  LocalTaskRepository reopen() => LocalTaskRepository(TaskDatabase(path: path));
  setUp(() {
    next = 0;
    directory = Directory(
      '../.scratches/task-write-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    path = '${directory.path}/tasks.sqlite';
    final db = sqlite3.open(path);
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
      ],
    );
    db.execute('DELETE FROM tasks');
    db.close();
    repo = reopen();
  });
  tearDown(() async {
    await repo.dispose();
    directory.deleteSync(recursive: true);
  });
  test(
    'one aggregate is durable with tags and checklist after reopening',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: ' Read ',
        tags: [DraftTag(id: TagId(newId()), name: '# Study')],
        subtasks: [
          DraftSubtask(
            id: SubtaskId(newId()),
            title: ' First ',
            completed: true,
          ),
        ],
      );
      final changes = <TaskChange>[];
      final subscription = repo.changes.listen(changes.add);
      final result = await save.execute(draft);
      expect(result.isSuccess, true, reason: '${result.failure?.code}');
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      expect(changes.single.taskIds, {draft.taskId});
      await subscription.cancel();
      await repo.dispose();
      repo = reopen();
      final loaded = (await repo.loadTask(
        draft.taskId,
        draft.occurrenceId,
      )).value!;
      expect(loaded.task.title.value, 'Read');
      expect(loaded.task.tags.single.name.key, 'study');
      expect(loaded.subtaskCompleted, 1);
      expect(loaded.occurrence.completed, false);
      expect(
        (await repo.loadRange(LocalDateRange(today, today))).value!.length,
        1,
      );
    },
  );
  test(
    'child-write failure rolls back all rows; retry retains stable IDs',
    () async {
      final db = sqlite3.open(path);
      db.execute(
        "CREATE TRIGGER fail_child BEFORE INSERT ON task_subtasks BEGIN SELECT RAISE(ABORT, 'private content'); END",
      );
      db.close();
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Secret title',
        subtasks: [DraftSubtask(id: SubtaskId(newId()), title: 'Secret child')],
      );
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final changes = <TaskChange>[];
      final subscription = repo.changes.listen(changes.add);
      expect(
        (await save.execute(draft)).failure!.code,
        TaskFailureCode.storageUnavailable,
      );
      final check = sqlite3.open(path);
      expect(check.select('SELECT * FROM tasks'), isEmpty);
      expect(check.select('SELECT * FROM task_occurrences'), isEmpty);
      check.execute('DROP TRIGGER fail_child');
      check.close();
      expect(changes, isEmpty);
      expect(
        (await save.execute(draft)).value!.aggregate.task.id,
        draft.taskId,
      );
      await subscription.cancel();
    },
  );
  test(
    'equivalent tags reuse canonical identity and shared edits are conditional',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final a = (await save.execute(
        TaskDraft.newTask(date: today, newId: newId).copyWith(
          title: 'First',
          tags: [DraftTag(id: TagId(newId()), name: ' # Café ')],
        ),
      )).value!.aggregate;
      final b = (await save.execute(
        TaskDraft.newTask(date: today, newId: newId).copyWith(
          title: 'Second',
          tags: [DraftTag(id: TagId(newId()), name: 'CAFÉ')],
        ),
      )).value!.aggregate;
      expect(a.task.tags.single.id, b.task.tags.single.id);
      final db = sqlite3.open(path);
      expect(db.select('SELECT * FROM tags').length, 1);
      db.execute(
        "INSERT INTO calendar_participants VALUES ('participant','Alex')",
      );
      db.execute('INSERT INTO task_participants VALUES (?,?)', [
        a.task.id.value,
        'participant',
      ]);
      db.close();
      final loaded = (await repo.loadTask(a.task.id, a.occurrence.id)).value!;
      final changed = (await save.execute(
        TaskDraft.fromAggregate(loaded).copyWith(title: 'Shared changed'),
      )).value!.aggregate;
      expect(changed.task.participants.single.id, 'participant');
      expect(
        (await save.execute(
          TaskDraft.fromAggregate(loaded).copyWith(title: 'Stale'),
        )).failure!.code,
        TaskFailureCode.staleRevision,
      );
      expect(
        (await repo.loadTask(
          a.task.id,
          a.occurrence.id,
        )).value!.task.title.value,
        'Shared changed',
      );
    },
  );
  test(
    'reordered checklists preserve states; removing keeps inactive history',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final first = SubtaskId(newId());
      final second = SubtaskId(newId());
      final a = (await save.execute(
        TaskDraft.newTask(date: today, newId: newId).copyWith(
          title: 'Checklist',
          subtasks: [
            DraftSubtask(id: first, title: 'First', completed: true),
            DraftSubtask(id: second, title: 'Second', completed: true),
          ],
        ),
      )).value!.aggregate;
      final b = (await save.execute(
        TaskDraft.fromAggregate(a).copyWith(
          subtasks: [
            DraftSubtask(id: second, title: 'Renamed', completed: true),
            DraftSubtask(id: first, title: 'First', completed: true),
          ],
        ),
      )).value!.aggregate;
      expect(b.task.subtasks.where((s) => s.active).map((s) => s.id), [
        second,
        first,
      ]);
      expect(b.subtaskCompleted, 2);
      expect(b.occurrence.completed, false);
      final c = (await save.execute(
        TaskDraft.fromAggregate(b).copyWith(
          subtasks: [
            DraftSubtask(id: second, title: 'Renamed', completed: true),
          ],
        ),
      )).value!.aggregate;
      expect(c.subtaskTotal, 1);
      expect(c.occurrence.subtaskStates[first], true);
      final db = sqlite3.open(path);
      expect(
        db.select('SELECT active FROM task_subtasks WHERE id=?', [
          first.value,
        ]).single['active'],
        0,
      );
      expect(
        db.select(
          'SELECT completed FROM task_occurrence_subtasks WHERE subtask_id=?',
          [first.value],
        ).single['completed'],
        1,
      );
      db.close();
    },
  );
  test(
    'failed edit after tag writes rolls back metadata links and children',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final a = (await save.execute(
        TaskDraft.newTask(date: today, newId: newId).copyWith(
          title: 'Original',
          tags: [DraftTag(id: TagId(newId()), name: 'Old')],
          subtasks: [DraftSubtask(id: SubtaskId(newId()), title: 'First')],
        ),
      )).value!.aggregate;
      final db = sqlite3.open(path);
      db.execute(
        "CREATE TRIGGER fail_edit BEFORE INSERT ON task_subtasks BEGIN SELECT RAISE(ABORT, 'sensitive'); END",
      );
      db.close();
      final changes = <TaskChange>[];
      final subscription = repo.changes.listen(changes.add);
      final edited = TaskDraft.fromAggregate(a).copyWith(
        title: 'Replacement',
        tags: [DraftTag(id: TagId(newId()), name: 'New')],
      );
      expect(
        (await save.execute(edited)).failure!.code,
        TaskFailureCode.storageUnavailable,
      );
      final b = (await repo.loadTask(a.task.id, a.occurrence.id)).value!;
      expect(b.task.title.value, 'Original');
      expect(b.task.tags.single.name.value, 'Old');
      expect(b.task.revision, a.task.revision);
      expect(changes, isEmpty);
      await subscription.cancel();
    },
  );

  test('occurrence-only checklist save reports instance change without shared revision', () async {
    final save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
    final sub = SubtaskId(newId());
    final a = (await save.execute(
      TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Checklist',
        subtasks: [DraftSubtask(id: sub, title: 'First')],
      ),
    )).value!.aggregate;
    final changes = <TaskChange>[];
    final subscription = repo.changes.listen(changes.add);
    final b = (await save.execute(
      TaskDraft.fromAggregate(a).copyWith(
        subtasks: [DraftSubtask(id: sub, title: 'First', completed: true)],
      ),
    )).value!.aggregate;
    await Future<void>.delayed(Duration.zero);
    expect(b.task.revision, a.task.revision);
    expect(b.occurrence.revision, a.occurrence.revision + 1);
    expect(changes.single.sharedMetadataChanged, false);
    expect(b.occurrence.isScheduleException, true);
    await subscription.cancel();
  });

  test('window reminder priority and multiline notes round trip and disabling clears', () async {
    final save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
    final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
      title: 'Timed',
      notes: ' a\n b ',
      priority: TaskPriority.high,
      timeWindow: TimeWindow(600, 660),
      reminder: ReminderPreference(15),
    );
    final a = (await save.execute(draft)).value!.aggregate;
    expect(a.task.notes, ' a\n b ');
    expect(a.task.priority, TaskPriority.high);
    expect(a.occurrence.reminder.minutesBefore, 15);
    final b = (await save.execute(
      TaskDraft.fromAggregate(a).copyWith(timeWindow: null),
    )).value!.aggregate;
    expect(b.task.schedule.timeWindow, isNull);
    expect(b.task.schedule.reminder.minutesBefore, isNull);
    expect(b.occurrence.timeWindow, isNull);
    expect(b.occurrence.reminder.minutesBefore, isNull);
    final db = sqlite3.open(path);
    final row = db.select(
      'SELECT start_minute,end_minute,reminder_minutes_before FROM task_occurrences WHERE id=?',
      [draft.occurrenceId.value],
    ).single;
    expect(row.values, everyElement(isNull));
    db.close();
  });

  test(
    'malformed existing normalized tags cannot cause a failed save to commit',
    () async {
      final db = sqlite3.open(path);
      db.execute(
        "INSERT INTO tags(id,name,normalized_name) VALUES ('corrupt','Different','study')",
      );
      db.close();
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Read',
        tags: [DraftTag(id: TagId(newId()), name: 'Study')],
      );
      final result = await save.execute(draft);
      expect(result.failure!.code, TaskFailureCode.storageUnavailable);
      final check = sqlite3.open(path);
      expect(check.select('SELECT * FROM tasks'), isEmpty);
      expect(check.select('SELECT * FROM task_tags'), isEmpty);
      expect(check.select('SELECT * FROM tags').length, 1);
      check.close();
    },
  );

  test(
    'concurrent equivalent tags reuse one canonical tag across connections',
    () async {
      final other = LocalTaskRepository(TaskDatabase(path: path));
      addTearDown(other.dispose);
      final first = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'First',
        tags: [DraftTag(id: TagId(newId()), name: 'Café')],
      );
      final second = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Second',
        tags: [DraftTag(id: TagId(newId()), name: ' # CAFÉ ')],
      );
      final results = await Future.wait([
        SaveTask(
          repo,
          newId: newId,
          clock: () => DateTime.utc(2026, 1, 30, 12),
        ).execute(first),
        SaveTask(
          other,
          newId: newId,
          clock: () => DateTime.utc(2026, 1, 30, 12),
        ).execute(second),
      ]);
      expect(results.every((r) => r.isSuccess), true);
      expect(
        results[0].value!.aggregate.task.tags.single.id,
        results[1].value!.aggregate.task.tags.single.id,
      );
      final db = sqlite3.open(path);
      expect(db.select('SELECT * FROM tags').length, 1);
      expect(db.select('SELECT * FROM task_tags').length, 2);
      db.close();
    },
  );
  test(
    'competing edits never overwrite the first committed shared revision',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final initial = (await save.execute(
        TaskDraft.newTask(
          date: today,
          newId: newId,
        ).copyWith(title: 'Original'),
      )).value!.aggregate;
      final other = LocalTaskRepository(TaskDatabase(path: path));
      addTearDown(other.dispose);
      final stale = TaskDraft.fromAggregate(initial);
      final results = await Future.wait([
        save.execute(stale.copyWith(title: 'First')),
        SaveTask(
          other,
          newId: newId,
          clock: () => DateTime.utc(2026, 1, 30, 12),
        ).execute(stale.copyWith(title: 'Second')),
      ]);
      expect(results.where((r) => r.isSuccess).length, 1);
      expect(
        results.singleWhere((r) => !r.isSuccess).failure!.code,
        TaskFailureCode.staleRevision,
      );
      final loaded = (await repo.loadTask(
        initial.task.id,
        initial.occurrence.id,
      )).value!;
      expect(loaded.task.revision, 1);
      expect(
        loaded.task.title.value,
        results
            .singleWhere((r) => r.isSuccess)
            .value!
            .aggregate
            .task
            .title
            .value,
      );
    },
  );
}
