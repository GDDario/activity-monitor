import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  test('task assignment persists and stale or missing people cannot partially save', () async {
    final dir = Directory('../.scratches/people-validation')
        .createTempSync('assignment-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    initializeDatabaseAtPath(path);
    final people = LocalPeopleRepository(PeopleDatabase(path: path));
    final tasks = LocalTaskRepository(TaskDatabase(path: path));
    addTearDown(people.dispose);
    addTearDown(tasks.dispose);
    await people.savePerson(PersonDraft(id: 'p', name: 'Ana'));
    var next = 0;
    String id() => 'assign-${next++}';
    final save = SaveTask(
      tasks,
      newId: id,
      clock: () => DateTime(2026, 11, 18, 9),
    );
    final created = (await save.execute(
      TaskDraft.newTask(date: LocalDate(2026, 11, 18), newId: id).copyWith(
        title: 'Shared walk',
        participants: [const TaskParticipant('p', 'Ana')],
      ),
    )).value!.aggregate;
    expect(created.task.participants.single.id, 'p');
    final loaded = (await tasks.loadTask(
      created.task.id,
      created.occurrence.id,
    )).value!;
    expect(loaded.task.participants.single.id, 'p');
    final missing = await save.execute(
      TaskDraft.fromAggregate(loaded).copyWith(
        title: 'Must roll back',
        participants: [const TaskParticipant('missing', 'Unknown')],
      ),
    );
    expect(missing.isSuccess, false);
    expect(
      (await tasks.loadTask(
        created.task.id,
        created.occurrence.id,
      )).value!.task.title.value,
      'Shared walk',
    );
    final cleared = (await save.execute(
      TaskDraft.fromAggregate(loaded).copyWith(participants: []),
    )).value!.aggregate;
    expect(cleared.task.participants, isEmpty);
    expect(cleared.task.revision, greaterThan(loaded.task.revision));
    final stale = await save.execute(
      TaskDraft.fromAggregate(loaded).copyWith(
        participants: [const TaskParticipant('p', 'Ana')],
        title: 'Old draft',
      ),
    );
    expect(stale.isSuccess, false);
    expect((await people.loadPersonActivities('p')).value!.total, 0);
  });
}
