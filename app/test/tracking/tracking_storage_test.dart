import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/task_migration_fixture.dart';

import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/database/migrations/migration_0005_add_people_metadata.dart';
import 'package:app/data/services/database/migrations/migration_0006_create_local_profile.dart';
import 'package:app/data/services/database/migrations/migration_0007_create_notification_settings.dart';
import 'package:app/data/services/database/migrations/migration_0008_add_task_tracking.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/domain/models/task_tracking.dart';

void main() {
  test('version 7 upgrade retains task ownership and announces later catalog additions once', () async {
    final dir = await Directory('../.scratches')
        .createTemp('tracking-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/test.db';
    final db = sqlite3.open(path);
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
        const Migration0005AddPeopleMetadata(),
        const Migration0006CreateLocalProfile(),
        const Migration0007CreateNotificationSettings(),
      ],
    );
    final ids = db
        .select('SELECT id,title FROM tasks')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    migrateDatabase(db);
    expect(db.select('PRAGMA user_version').single.values.single, 8);
    expect(
      db
          .select('SELECT id,title FROM tasks')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      ids,
    );
    expect(
      db.select('SELECT notice FROM task_types').every((r) => r['notice'] == 0),
      true,
    );
    final added = TaskType(
      id: '01900000-0000-7000-8000-000000000098',
      name: 'Swimming',
      icon: 'fitness',
      builtin: true,
    );
    installBuiltinTaskTypes(db, [added]);
    db.close();
    final repo = TrackingRepository(TrackingDatabase(path));
    addTearDown(repo.dispose);
    final noticed = (await repo.loadTypes()).singleWhere(
      (t) => t.id == added.id,
    );
    expect(noticed.notice, true);
    await repo.dismissNotice(noticed.id, noticed.revision);
    final reopened = sqlite3.open(path);
    installBuiltinTaskTypes(reopened, [added]);
    reopened.close();
    expect(
      (await repo.loadTypes()).singleWhere((t) => t.id == added.id).notice,
      false,
    );
  });
  test(
    'catalog survives restart, defaults are immutable and visibility persists',
    () async {
      final dir = await Directory('../.scratches').createTemp('tracking-test-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.db';
      final db = sqlite3.open(path);
      migrateDatabase(db);
      final before = db.select('SELECT COUNT(*) AS n FROM tasks').single['n'];
      migrateDatabase(db);
      expect(db.select('SELECT COUNT(*) AS n FROM tasks').single['n'], before);
      db.close();
      final repo = TrackingRepository(TrackingDatabase(path));
      final types = await repo.loadTypes();
      expect(types, hasLength(9));
      final book = types.firstWhere((t) => t.icon == 'book');
      await expectLater(
        repo.saveType(book.copyWith(name: 'Changed'), expected: book.revision),
        throwsA(isA<TrackingFailure>()),
      );
      await repo.setVisibility(book.id, true, book.revision);
      final restarted = TrackingRepository(TrackingDatabase(path));
      expect(
        (await restarted.loadTypes()).firstWhere((t) => t.id == book.id).hidden,
        isTrue,
      );
      await expectLater(
        repo.setVisibility(generalTaskType().id, true, 0),
        throwsA(isA<TrackingFailure>()),
      );
    },
  );
  test('custom schema rejects reused units and stale revisions', () async {
    final dir = await Directory('../.scratches').createTemp('tracking-test-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/test.db';
    final db = sqlite3.open(path);
    migrateDatabase(db);
    db.close();
    final repo = TrackingRepository(TrackingDatabase(path));
    final type = TaskType(
      id: '01900000-0000-7000-8000-000000000099',
      name: 'Lifting',
      icon: 'fitness',
      fields: [
        TrackingField(
          id: 'weight',
          label: 'Weight',
          kind: FieldKind.number,
          scope: FieldScope.log,
          unit: 'kg',
        ),
      ],
    );
    await repo.saveType(type);
    await expectLater(
      repo.saveType(
        type.copyWith(
          fields: [
            TrackingField(
              id: 'weight',
              label: 'Weight',
              kind: FieldKind.number,
              scope: FieldScope.log,
              unit: 'lb',
            ),
          ],
        ),
        expected: 0,
      ),
      throwsA(isA<TrackingFailure>()),
    );
    await repo.saveType(type.copyWith(name: 'Strength'), expected: 0);
    await expectLater(
      repo.saveType(type.copyWith(name: 'Outdated'), expected: 0),
      throwsA(isA<TrackingFailure>()),
    );
    expect((await repo.loadTypes()).last.name, 'Strength');
  });
}
