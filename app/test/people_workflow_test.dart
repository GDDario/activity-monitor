import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/people_database.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/repositories/people_repository.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/reopen_task_occurrence.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';
import 'package:app/domain/value_objects/local_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('People reflects committed completion reopen postpone deletion Undo and storage reopen', () async {
    final dir = Directory('../.scratches/people-validation')
        .createTempSync('workflow-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    initializeDatabaseAtPath(path);
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('DELETE FROM tasks');
    db.close();
    final people = LocalPeopleRepository(PeopleDatabase(path: path));
    final tasks = LocalTaskRepository(TaskDatabase(path: path));
    addTearDown(people.dispose);
    addTearDown(tasks.dispose);
    final day = LocalDate(2026, 11, 18);
    DateTime now() => DateTime(2026, 11, 18, 9);
    var n = 0;
    String id() => 'workflow-people-${n++}';
    await people.savePerson(
      PersonDraft(id: 'p', name: 'Robin', categories: {PersonCategory.work}),
    );
    final created = (await SaveTask(tasks, newId: id, clock: now).execute(
      TaskDraft.newTask(date: day, newId: id).copyWith(
        title: 'Shared walk',
        participants: [const TaskParticipant('p', 'Robin')],
      ),
    )).value!.aggregate;
    Future<TaskAggregate> current() async =>
        (await tasks.loadTask(created.task.id, created.occurrence.id)).value!;
    Future<PersonStats> stats() async =>
        (await people.loadSnapshot(day)).value!.stats['p']!;
    expect((await stats()).active, 1);
    var a = await current();
    expect(
      (await CompleteTaskOccurrence(
        tasks,
        now: now,
      ).execute(a.occurrence.id, a.expected)).isSuccess,
      true,
    );
    expect((await stats()).active, 0);
    expect((await stats()).lastTitle, 'Shared walk');
    a = await current();
    expect(
      (await ReopenTaskOccurrence(
        tasks,
        now: now,
      ).execute(a.occurrence.id, a.expected)).isSuccess,
      true,
    );
    expect((await stats()).lastDate, isNull);
    expect((await stats()).active, 1);
    a = await current();
    final postponed = await PostponeTaskOccurrence(
      tasks,
      now: now,
    ).execute(a.occurrence.id, a.expected);
    expect(postponed.isSuccess, true);
    expect((await stats()).active, 0);
    expect(
      (await people.loadPersonActivities('p'))
          .value!
          .entries
          .single
          .occurrence
          .effectiveDate,
      day.addDays(1),
    );
    a = await current();
    final deleted = await DeleteTaskOccurrence(
      tasks,
      now: now,
    ).execute(a.occurrence.id, a.expected);
    expect(deleted.isSuccess, true);
    expect((await people.loadPersonActivities('p')).value!.total, 0);
    expect(
      (await UndoTaskOccurrenceAction(tasks).execute(deleted.value!.undo!))
          .isSuccess,
      true,
    );
    final reopened = LocalPeopleRepository(PeopleDatabase(path: path));
    addTearDown(reopened.dispose);
    final history = (await reopened.loadPersonActivities('p')).value!;
    expect(history.total, 1);
    expect(history.entries.single.task.participants.single.id, 'p');
    expect(
      (await reopened.loadSnapshot(day)).value!.people
          .singleWhere((p) => p.id == 'p')
          .categories,
      {PersonCategory.work},
    );
  });
}
