import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/database/migrations.dart';

void main() {
  test(
    'initializes a fresh database and preserves data on reopening',
    () async {
      Directory('../.scratches').createSync(recursive: true);
      final directory = await Directory('../.scratches')
          .createTemp('activity_database_');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/activity_monitor.db';
      initializeDatabaseAtPath(path);
      final first = sqlite3.open(path);
      expect(first.select('PRAGMA user_version').single.values.single, 4);
      first.execute(
        "INSERT INTO tasks (id, title, start_date, cadence) VALUES ('id', 'Walk', '2024-02-29', 'daily')",
      );
      first.close();
      initializeDatabaseAtPath(path);
      final reopened = sqlite3.open(path);
      addTearDown(reopened.close);
      expect(
        reopened
            .select("SELECT title FROM tasks WHERE id = 'id'")
            .single['title'],
        'Walk',
      );
    },
  );

  test('rejects newer schemas without modifying data', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE preserved (value TEXT)');
    db.execute("INSERT INTO preserved VALUES ('kept')");
    db.execute('PRAGMA user_version = 99');
    expect(() => migrateDatabase(db), throwsStateError);
    expect(db.select('PRAGMA user_version').single.values.single, 99);
    expect(db.select('SELECT value FROM preserved').single['value'], 'kept');
  });

  test(
    'enforces persisted schema constraints on a reopened database',
    () async {
      Directory('../.scratches').createSync(recursive: true);
      final directory = await Directory('../.scratches')
          .createTemp('activity_integrity_');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/activity_monitor.db';
      initializeDatabaseAtPath(path);
      final db = sqlite3.open(path);
      addTearDown(db.close);
      db.execute('PRAGMA foreign_keys = ON');
      expect(
        () => db.execute(
          "INSERT INTO tasks (id, title, start_date, cadence) VALUES ('invalid', '', '2024-01-01', 'daily')",
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.execute(
          "INSERT INTO task_participants VALUES ('missing', 'missing')",
        ),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test('applies only pending migrations to an existing database', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE existing (value TEXT)');
    db.execute("INSERT INTO existing VALUES ('kept')");
    db.execute('PRAGMA user_version = 1');
    migrateDatabase(
      db,
      migrations: [
        DatabaseMigration(1, (_) => throw StateError('already applied')),
        DatabaseMigration(
          2,
          (database) => database.execute(
            'ALTER TABLE existing ADD COLUMN added INTEGER DEFAULT 7',
          ),
        ),
      ],
    );
    expect(db.select('PRAGMA user_version').single.values.single, 2);
    expect(
      db.select('SELECT value, added FROM existing').single['value'],
      'kept',
    );
    expect(db.select('SELECT added FROM existing').single['added'], 7);
  });

  test('rolls back schema and version when a migration fails', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(
      () => migrateDatabase(
        db,
        migrations: [
          DatabaseMigration(1, (database) {
            database.execute('CREATE TABLE partial (id INTEGER)');
            throw StateError('failure');
          }),
        ],
      ),
      throwsStateError,
    );
    expect(db.select('PRAGMA user_version').single.values.single, 0);
    expect(
      db.select("SELECT name FROM sqlite_master WHERE name = 'partial'"),
      isEmpty,
    );
  });
}
