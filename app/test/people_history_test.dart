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
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('history pages stable saved occurrences and metrics exclude deleted/future completions', () async {
    final dir = Directory('../.scratches/people-validation')
        .createTempSync('history-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    initializeDatabaseAtPath(path);
    final clean = sqlite3.open(path);
    clean.execute('PRAGMA foreign_keys=ON');
    clean.execute('DELETE FROM tasks');
    clean.close();
    final people = LocalPeopleRepository(PeopleDatabase(path: path));
    final tasks = LocalTaskRepository(TaskDatabase(path: path));
    addTearDown(people.dispose);
    addTearDown(tasks.dispose);
    await people.savePerson(PersonDraft(id: 'a', name: 'Ana'));
    await people.savePerson(PersonDraft(id: 'b', name: 'Ben'));
    var n = 0;
    String id() => 'history-${n++}';
    final day = LocalDate(2026, 11, 18);
    final save = SaveTask(
      tasks,
      newId: id,
      clock: () => DateTime(2026, 11, 18, 9),
    );
    final created = <TaskAggregate>[];
    for (var i = 0; i < 25; i++) {
      final date = i < 22
          ? day
          : i == 22
          ? day.addDays(-29)
          : i == 23
          ? day.addDays(-30)
          : day.addDays(1);
      final draft = TaskDraft.newTask(date: date, newId: id).copyWith(
        title: 'Activity ${i.toString().padLeft(2, '0')}',
        timeWindow: i % 2 == 0 ? TimeWindow(600, 630) : null,
        participants: [
          const TaskParticipant('a', 'Ana'),
          const TaskParticipant('b', 'Ben'),
        ],
      );
      final result = await save.execute(draft);
      expect(result.isSuccess, true);
      created.add(result.value!.aggregate);
    }
    final db = sqlite3.open(path);
    for (final i in [0, 1, 22, 23, 24]) {
      db.execute("UPDATE task_occurrences SET completed=1 WHERE id=?", [
        created[i].occurrence.id.value,
      ]);
    }
    db.execute(
      "UPDATE task_occurrences SET deleted_at_utc='2026-11-18T12:00:00Z' WHERE id=?",
      [created[2].occurrence.id.value],
    );
    db.close();
    final snap = (await people.loadSnapshot(day)).value!;
    expect(snap.shared, 21);
    expect(snap.activeShared, 19);
    expect(snap.stats['a']!.active, 19);
    expect(snap.stats['a']!.recent, 3);
    expect(snap.stats['a']!.lastTitle, 'Activity 00');
    final first = (await people.loadPersonActivities('a')).value!;
    final second = (await people.loadPersonActivities('a', page: 1)).value!;
    expect(first.total, 24);
    expect(first.entries.length, 20);
    expect(second.entries.length, 4);
    expect(
      {
        ...first.entries.map((e) => e.occurrence.id),
        ...second.entries.map((e) => e.occurrence.id),
      }.length,
      24,
    );
    expect(first.entries.first.task.title.value, 'Activity 24');
    final ascending = (await people.loadPersonActivities(
      'a',
      ascending: true,
    )).value!;
    expect(ascending.entries.first.task.title.value, 'Activity 23');
    expect((await people.loadPersonActivities('a', page: 99)).value!.page, 1);
  });
}
