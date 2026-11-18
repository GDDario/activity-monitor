import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/tag_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/reopen_task_occurrence.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';

void main() {
  late String path;
  late LocalTaskRepository repository;
  final now = DateTime(2026, 12, 31, 12);
  final date = LocalDate(2026, 12, 31);
  final taskId = TaskId('task');
  final occurrenceId = OccurrenceId('selected');
  final childId = SubtaskId('child');
  setUp(() async {
    Directory('../.scratches').createSync(recursive: true);
    final directory = await Directory('../.scratches')
        .createTemp('task_actions_');
    addTearDown(() => directory.delete(recursive: true));
    path = '${directory.path}/actions.sqlite';
    initializeDatabaseAtPath(path);
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('DELETE FROM tasks');
    db.execute('DELETE FROM calendar_participants');
    db.close();
    repository = LocalTaskRepository(TaskDatabase(path: path));
    addTearDown(() => repository.dispose());
    final saved =
        await SaveTask(
          repository,
          newId: () => 'unused',
          clock: () => now,
        ).execute(
          TaskDraft(
            taskId: taskId,
            occurrenceId: occurrenceId,
            date: date,
            title: 'Read',
            notes: 'Keep details',
            cadence: TaskCadence.daily,
            recurrenceEnabled: true,
            timeWindow: TimeWindow(900, 960),
            reminder: ReminderPreference(15),
            tags: [DraftTag(id: TagId('tag'), name: 'Books')],
            subtasks: [
              DraftSubtask(id: childId, title: 'Chapter', completed: true),
            ],
          ),
        );
    expect(saved.isSuccess, isTrue);
    final links = sqlite3.open(path);
    links.execute('PRAGMA foreign_keys = ON');
    links.execute(
      "INSERT INTO calendar_participants VALUES ('person', 'Alex')",
    );
    links.execute("INSERT INTO task_participants VALUES ('task', 'person')");
    links.close();
  });

  Future<TaskAggregate> load() async =>
      (await repository.loadTask(taskId, occurrenceId)).value!;

  test('actions preserve details, coexist after postponing, restore exact state and keep tombstones across restart', () async {
    var current = await load();
    final completed = await CompleteTaskOccurrence(
      repository,
      now: () => now,
    ).execute(occurrenceId, current.expected);
    expect(completed.isSuccess, isTrue);
    current = await load();
    expect(current.occurrence.completedAtUtc, now.toUtc());
    expect(current.occurrence.subtaskStates[childId], isTrue);
    expect(
      (await UndoTaskOccurrenceAction(repository)
              .execute(completed.value!.undo!))
          .isSuccess,
      isTrue,
    );
    current = await load();
    expect(current.occurrence.completed, isFalse);
    expect(current.occurrence.isScheduleException, isFalse);
    expect(
      (await CompleteTaskOccurrence(
        repository,
        now: () => now,
      ).execute(occurrenceId, current.expected)).isSuccess,
      isTrue,
    );
    current = await load();
    expect(
      (await ReopenTaskOccurrence(
        repository,
        now: () => now,
      ).execute(occurrenceId, current.expected)).isSuccess,
      isTrue,
    );
    current = await load();
    final tomorrow = date.addDays(1);
    final normal = TaskOccurrence(
      id: OccurrenceId('normal-tomorrow'),
      taskId: taskId,
      scheduledDate: tomorrow,
      effectiveDate: tomorrow,
      timeWindow: TimeWindow(900, 960),
      reminder: ReminderPreference(15),
      subtaskStates: {childId: false},
    );
    expect(
      (await repository.ensureOccurrences(
        [normal],
        {taskId: current.task.revision},
      )).isSuccess,
      isTrue,
    );
    expect(
      (await PostponeTaskOccurrence(
        repository,
        now: () => now,
      ).execute(occurrenceId, current.expected)).isSuccess,
      isTrue,
    );
    current = await load();
    expect(current.occurrence.scheduledDate, date);
    expect(current.occurrence.effectiveDate, tomorrow);
    final tomorrowRange = LocalDateRange(tomorrow, tomorrow);
    expect((await repository.loadRange(tomorrowRange)).value, hasLength(2));
    final beforeDelete = current;
    final deleted = await DeleteTaskOccurrence(
      repository,
      now: () => now,
    ).execute(occurrenceId, current.expected);
    expect(deleted.isSuccess, isTrue);
    expect((await repository.loadRange(tomorrowRange)).value, hasLength(1));
    expect(
      (await UndoTaskOccurrenceAction(repository).execute(deleted.value!.undo!))
          .isSuccess,
      isTrue,
    );
    current = await load();
    expect(current.occurrence.id, beforeDelete.occurrence.id);
    expect(
      current.occurrence.scheduledDate,
      beforeDelete.occurrence.scheduledDate,
    );
    expect(
      current.occurrence.effectiveDate,
      beforeDelete.occurrence.effectiveDate,
    );
    expect(current.occurrence.timeWindow, beforeDelete.occurrence.timeWindow);
    expect(current.occurrence.reminder, beforeDelete.occurrence.reminder);
    expect(
      current.occurrence.subtaskStates,
      beforeDelete.occurrence.subtaskStates,
    );
    expect(current.task.tags.single.id, beforeDelete.task.tags.single.id);
    expect(current.task.participants.single.id, 'person');
    expect(current.task.notes, 'Keep details');
    expect(
      (await DeleteTaskOccurrence(
        repository,
        now: () => now,
      ).execute(occurrenceId, current.expected)).isSuccess,
      isTrue,
    );
    await repository.dispose();
    repository = LocalTaskRepository(TaskDatabase(path: path));
    expect(
      (await repository.loadTask(taskId, occurrenceId)).failure!.code,
      TaskFailureCode.deleted,
    );
    expect(
      (await repository.loadRange(tomorrowRange)).value!.single.occurrence.id,
      normal.id,
    );
    final recreated = await repository.ensureOccurrences(
      [
        TaskOccurrence(
          id: OccurrenceId('should-not-exist'),
          taskId: taskId,
          scheduledDate: date,
          effectiveDate: date,
        ),
      ],
      {taskId: current.task.revision},
    );
    expect(recreated.value, isFalse);
    expect(
      (await repository.loadRange(LocalDateRange(date, date))).value,
      isEmpty,
    );
    final db = sqlite3.open(path);
    addTearDown(db.close);
    expect(db.select('SELECT * FROM task_occurrences'), hasLength(2));
    expect(
      db
          .select(
            "SELECT deleted_at_utc FROM task_occurrences WHERE id = 'selected'",
          )
          .single['deleted_at_utc'],
      isNotNull,
    );
  });

  test(
    'a shared metadata edit invalidates completion Undo in real SQLite',
    () async {
      final before = await load();
      final completed = await CompleteTaskOccurrence(
        repository,
        now: () => now,
      ).execute(occurrenceId, before.expected);
      final current = await load();
      final edited =
          await SaveTask(
            repository,
            newId: () => 'unused',
            clock: () => now,
          ).execute(
            TaskDraft.fromAggregate(current).copyWith(title: 'Updated title'),
          );
      expect(edited.isSuccess, isTrue);
      final undo = await UndoTaskOccurrenceAction(repository)
          .execute(completed.value!.undo!);
      expect(undo.failure!.code, TaskFailureCode.staleRevision);
      final after = await load();
      expect(after.task.title.value, 'Updated title');
      expect(after.occurrence.completed, isTrue);
      expect(after.task.participants.single.id, 'person');
    },
  );
  test('a failed child restore rolls back the tombstone and revision and emits no success before retry', () async {
    final current = await load();
    final deleted = await DeleteTaskOccurrence(
      repository,
      now: () => now,
    ).execute(occurrenceId, current.expected);
    expect(deleted.isSuccess, isTrue);
    final db = sqlite3.open(path);
    addTearDown(db.close);
    final before = Map<String, Object?>.from(
      db.select("SELECT * FROM task_occurrences WHERE id = 'selected'").single,
    );
    final beforeState = Map<String, Object?>.from(
      db
          .select(
            "SELECT * FROM task_occurrence_subtasks WHERE occurrence_id = 'selected'",
          )
          .single,
    );
    db.execute(
      "CREATE TRIGGER fail_restore BEFORE UPDATE OF completed ON task_occurrence_subtasks BEGIN SELECT RAISE(ABORT, 'injected restore failure'); END",
    );
    final changes = <TaskChange>[];
    final subscription = repository.changes.listen(changes.add);
    addTearDown(subscription.cancel);
    final restored = await UndoTaskOccurrenceAction(repository)
        .execute(deleted.value!.undo!);
    expect(restored.failure!.code, TaskFailureCode.storageUnavailable);
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);
    expect(
      Map<String, Object?>.from(
        db
            .select("SELECT * FROM task_occurrences WHERE id = 'selected'")
            .single,
      ),
      before,
    );
    expect(
      Map<String, Object?>.from(
        db
            .select(
              "SELECT * FROM task_occurrence_subtasks WHERE occurrence_id = 'selected'",
            )
            .single,
      ),
      beforeState,
    );
    db.execute('DROP TRIGGER fail_restore');
    expect(
      (await UndoTaskOccurrenceAction(repository).execute(deleted.value!.undo!))
          .isSuccess,
      isTrue,
    );
    expect((await load()).occurrence.isDeleted, isFalse);
  });
}
