import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/people_database.dart';
import 'package:app/data/repositories/people_repository.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/value_objects/local_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String path;
  late PeopleRepository repo;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('people-test-');
    path = '${dir.path}/test.db';
    initializeDatabaseAtPath(path);
    repo = LocalPeopleRepository(PeopleDatabase(path: path));
  });
  tearDown(() async {
    await repo.dispose();
    dir.deleteSync(recursive: true);
  });
  test(
    'person metadata survives reopen and rejects stale updates atomically',
    () async {
      final created = await repo.savePerson(
        PersonDraft(
          id: 'p',
          name: ' Ana ',
          role: ' Artist ',
          categories: {PersonCategory.work},
        ),
      );
      expect(created.isSuccess, true);
      expect(created.value!.name, 'Ana');
      expect(
        (await repo.savePerson(
          PersonDraft(id: 'p', name: 'Changed', expectedRevision: 0),
        )).isSuccess,
        true,
      );
      final stale = await repo.savePerson(
        PersonDraft(
          id: 'p',
          name: 'Stale',
          expectedRevision: 0,
          categories: {PersonCategory.family},
        ),
      );
      expect(stale.failure, PeopleFailure.staleRevision);
      final reopened = LocalPeopleRepository(PeopleDatabase(path: path));
      final snapshot = await reopened.loadSnapshot(LocalDate(2026, 11, 18));
      final p = snapshot.value!.people.singleWhere((p) => p.id == 'p');
      expect(p.name, 'Changed');
      expect(p.categories, isEmpty);
      await reopened.dispose();
    },
  );
  test(
    'same create identity cannot create twice and invalid input saves nothing',
    () async {
      expect(
        (await repo.savePerson(PersonDraft(id: 'p', name: ''))).failure,
        PeopleFailure.validation,
      );
      expect(
        (await repo.savePerson(PersonDraft(id: 'p', name: 'One'))).isSuccess,
        true,
      );
      expect(
        (await repo.savePerson(PersonDraft(id: 'p', name: 'Two'))).failure,
        PeopleFailure.identityConflict,
      );
    },
  );
  test('migration preserves participants and existing links; empty history is explicit', () async {
    final db = sqlite3.open(path);
    expect(db.select('PRAGMA user_version').single.values.single, 5);
    final original =
        db.select('SELECT id FROM calendar_participants').first['id'] as String;
    db.close();
    final page = await repo.loadPersonActivities(original, page: 99);
    expect(page.isSuccess, true);
    expect(page.value!.page, lessThanOrEqualTo(page.value!.pages - 1));
    expect(
      (await repo.loadPersonActivities('missing')).failure,
      PeopleFailure.notFound,
    );
  });
  test('unavailable database is not a successful empty snapshot', () async {
    final missing = LocalPeopleRepository(
      PeopleDatabase(path: '${dir.path}/missing.db'),
    );
    expect(
      (await missing.loadSnapshot(LocalDate(2026, 11, 18))).failure,
      PeopleFailure.storageUnavailable,
    );
    await missing.dispose();
  });
}
