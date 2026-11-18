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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'large saved history returns only selected page and uses participant index',
    () async {
      final dir = Directory('../.scratches/people-validation')
          .createTempSync('scale-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/test.db';
      initializeDatabaseAtPath(path);
      final people = LocalPeopleRepository(PeopleDatabase(path: path));
      final tasks = LocalTaskRepository(TaskDatabase(path: path));
      addTearDown(people.dispose);
      addTearDown(tasks.dispose);
      await people.savePerson(PersonDraft(id: 'p', name: 'Ana'));
      var n = 0;
      String id() => 'scale-${n++}';
      final a =
          (await SaveTask(
                tasks,
                newId: id,
                clock: () => DateTime(2026, 11, 18),
              ).execute(
                TaskDraft.newTask(
                  date: LocalDate(2026, 11, 18),
                  newId: id,
                ).copyWith(
                  title: 'Daily rhythm',
                  cadence: TaskCadence.daily,
                  participants: [const TaskParticipant('p', 'Ana')],
                ),
              ))
              .value!
              .aggregate;
      final db = sqlite3.open(path);
      db.execute('BEGIN');
      for (var i = 1; i <= 2000; i++) {
        final date = LocalDate(2026, 11, 18).addDays(-i).toString();
        db.execute(
          'INSERT INTO task_occurrences(id,task_id,scheduled_date,effective_date,completed,revision,is_schedule_exception) VALUES (?,?,?,?,0,0,0)',
          ['bulk-$i', a.task.id.value, date, date],
        );
      }
      db.execute('COMMIT');
      final plan = db.select(
        'EXPLAIN QUERY PLAN SELECT o.id FROM task_participants tp JOIN task_occurrences o ON o.task_id=tp.task_id WHERE tp.participant_id=? AND o.deleted_at_utc IS NULL ORDER BY o.effective_date DESC LIMIT 20',
        ['p'],
      );
      expect(
        plan.map((r) => r['detail']).join(' '),
        contains('task_participants_participant'),
      );
      db.close();
      final last = (await people.loadPersonActivities('p', page: 100)).value!;
      expect(last.total, 2001);
      expect(last.entries.length, 1);
      expect(last.page, 100);
      final first = (await people.loadPersonActivities('p')).value!;
      expect(first.entries.length, 20);
      expect(first.entries.first.occurrence.id, a.occurrence.id);
    },
  );
}
