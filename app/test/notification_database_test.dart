import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/notification_database.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';
import 'package:app/data/services/database/migrations/migration_0003_add_calendar_completion.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/database/migrations/migration_0005_add_people_metadata.dart';
import 'package:app/data/services/database/migrations/migration_0006_create_local_profile.dart';

List<DatabaseMigration> v6() => [
  const Migration0001CreateCalendarTables(),
  Migration0002SeedCalendarExamples(
    CalendarSeeder(
      now: () => DateTime(2026, 11, 18),
      newId: () => 'seed-${_next++}',
    ),
  ),
  const Migration0003AddCalendarCompletion(),
  const Migration0004CreateTaskTables(),
  const Migration0005AddPeopleMetadata(),
  const Migration0006CreateLocalProfile(),
];
int _next = 0;
void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('notification-db');
    path = '${dir.path}/test.db';
    final db = sqlite3.open(path);
    migrateDatabase(db, migrations: v6());
    db.execute(
      "INSERT INTO local_profile(slot,id,display_name,appearance,language,revision) VALUES(1,'local','Robin','system','device',0)",
    );
    db.close();
  });
  tearDown(() => dir.deleteSync(recursive: true));
  test(
    'v6 migration preserves profile and durable opt-in and native mappings',
    () async {
      final db = sqlite3.open(path);
      migrateDatabase(db);
      expect(
        db
            .select('SELECT display_name FROM local_profile')
            .single['display_name'],
        'Robin',
      );
      db.close();
      final store = NotificationDatabase(path: path);
      expect(await store.readEnabled(), false);
      await store.writeEnabled(true);
      final ids = await store.allocate(['a', 'b']);
      expect(ids['a'], isNot(ids['b']));
      final reopened = NotificationDatabase(path: path);
      expect(await reopened.readEnabled(), true);
      expect((await reopened.allocate(['b', 'a']))['a'], ids['a']);
    },
  );
  test('invalid settings and duplicate native identifiers are constrained', () {
    final db = sqlite3.open(path);
    addTearDown(db.close);
    migrateDatabase(db);
    expect(
      () => db.execute('UPDATE notification_settings SET enabled=2'),
      throwsA(isA<SqliteException>()),
    );
    db.execute("INSERT INTO notification_ids(occurrence_id) VALUES('a')");
    expect(
      () =>
          db.execute("INSERT INTO notification_ids(occurrence_id) VALUES('a')"),
      throwsA(isA<SqliteException>()),
    );
  });
  test('failed migration rolls back new tables and preserves prior schema', () {
    final db = sqlite3.open(path);
    addTearDown(db.close);
    db.execute('CREATE TABLE notification_ids(id INTEGER)');
    expect(() => migrateDatabase(db), throwsA(isA<SqliteException>()));
    expect(db.select('PRAGMA user_version').single.values.single, 6);
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name='notification_settings'",
      ),
      isEmpty,
    );
    expect(
      db
          .select('SELECT display_name FROM local_profile')
          .single['display_name'],
      'Robin',
    );
  });
}
