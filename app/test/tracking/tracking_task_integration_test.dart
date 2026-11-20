import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/tracking_metrics.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

void main() {
  late Directory dir;
  late LocalTaskRepository tasks;
  late TrackingRepository tracking;
  late String path;
  var sequence = 0;
  final today = LocalDate(2026, 11, 19);
  DateTime now = DateTime.utc(2026, 11, 19, 12);
  String newId() => 'integration-${sequence++}';
  setUp(() {
    dir = Directory(
      '../.scratches/tracking-integration-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    path = '${dir.path}/db.sqlite';
    final db = sqlite3.open(path);
    migrateDatabase(db);
    db.execute('DELETE FROM tasks');
    db.close();
    tasks = LocalTaskRepository(TaskDatabase(path: path));
    tracking = TrackingRepository(TrackingDatabase(path));
  });
  tearDown(() async {
    await tasks.dispose();
    dir.deleteSync(recursive: true);
  });
  test(
    'task setup and logs survive restart without completing occurrences',
    () async {
      final book = (await tracking.loadTypes()).firstWhere(
        (t) => t.icon == 'book',
      );
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Dune',
        tracking: TrackingSetup(
          type: book,
          values: {'totalPages': 300, 'startingPage': 40},
        ),
      );
      final saved = await SaveTask(
        tasks,
        newId: newId,
        clock: () => now,
      ).execute(draft);
      expect(saved.isSuccess, isTrue, reason: '${saved.failure?.code}');
      final log = ActivityLog(
        id: newId(),
        taskId: draft.taskId.value,
        type: book,
        recordedAt: now,
        values: {'currentPage': 60},
      );
      await tracking.saveLog(log, taskRevision: 0, now: now);
      final detail = await tracking.loadDetail(draft.taskId.value);
      expect(detail.setup.values['startingPage'], 40);
      expect(detail.logs.single.values['currentPage'], 60);
      expect(
        (await tasks.loadTask(
          draft.taskId,
          draft.occurrenceId,
        )).value!.occurrence.completed,
        isFalse,
      );
      await expectLater(
        tracking.saveLog(log, taskRevision: 0, now: now),
        throwsA(isA<TrackingFailure>()),
      );
      await tracking.deleteLog(detail.logs.single, 0);
      expect((await tracking.loadDetail(draft.taskId.value)).logs, isEmpty);
    },
  );
  test(
    'finish removes untouched future slots and reopening excludes the gap',
    () async {
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Study',
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
      );
      final saved = await SaveTask(tasks, newId: newId, clock: () => now)
          .execute(
            draft,
            requestedRange: LocalDateRange(today, today.addDays(10)),
          );
      expect(saved.isSuccess, isTrue);
      await tracking.lifecycle(draft.taskId.value, 0, true, today.toString());
      final ensure = EnsureTaskOccurrences(tasks, newId: newId);
      expect(
        (await ensure.execute(
          LocalDateRange(today.addDays(1), today.addDays(10)),
        )).value,
        isEmpty,
      );
      await tracking.lifecycle(
        draft.taskId.value,
        1,
        false,
        today.addDays(4).toString(),
      );
      final range = (await ensure.execute(
        LocalDateRange(today.addDays(1), today.addDays(5)),
      )).value!;
      expect(range.map((a) => a.occurrence.scheduledDate), [
        today.addDays(4),
        today.addDays(5),
      ]);
    },
  );
  test(
    'stale schemas and invalid progress roll back without partial task edits',
    () async {
      final book = (await tracking.loadTypes()).firstWhere(
        (t) => t.icon == 'book',
      );
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Book',
        tracking: TrackingSetup(
          type: book,
          values: {'totalPages': 100, 'startingPage': 0},
        ),
      );
      final saved = (await SaveTask(
        tasks,
        newId: newId,
        clock: () => now,
      ).execute(draft)).value!;
      await tracking.saveLog(
        ActivityLog(
          id: newId(),
          taskId: draft.taskId.value,
          recordedAt: now,
          type: book,
          values: {'currentPage': 80},
        ),
        taskRevision: 0,
        now: now,
      );
      final edit = TaskDraft.fromAggregate(saved.aggregate).copyWith(
        title: 'Changed',
        tracking: TrackingSetup(
          type: book,
          values: {'totalPages': 50, 'startingPage': 0},
        ),
      );
      expect(
        (await SaveTask(tasks, newId: newId, clock: () => now).execute(edit))
            .isSuccess,
        isFalse,
      );
      expect(
        (await tasks.loadTask(
          draft.taskId,
          draft.occurrenceId,
        )).value!.task.title.value,
        'Book',
      );
    },
  );
  test('renaming and replacing fields preserves historical logs and incompatible units', () async {
    final field = TrackingField(
      id: 'distance-km',
      label: 'Distance',
      kind: FieldKind.number,
      scope: FieldScope.log,
      unit: 'km',
    );
    final custom = TaskType(
      id: 'custom-distance',
      name: 'Walking',
      icon: 'walk',
      fields: [field],
    );
    await tracking.saveType(custom);
    final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
      title: 'Walk',
      tracking: TrackingSetup(type: custom),
    );
    await SaveTask(tasks, newId: newId, clock: () => now).execute(draft);
    await tracking.saveLog(
      ActivityLog(
        id: 'distance-log',
        taskId: draft.taskId.value,
        recordedAt: now,
        type: custom,
        values: {field.id: 2},
      ),
      taskRevision: 0,
      now: now,
    );
    await tracking.saveType(
      custom.copyWith(
        name: 'Daily walking',
        fields: [
          TrackingField(
            id: 'distance-m',
            label: 'Distance',
            kind: FieldKind.number,
            scope: FieldScope.log,
            unit: 'm',
          ),
        ],
      ),
      expected: 0,
    );
    final detail = await tracking.loadDetail(draft.taskId.value);
    expect(detail.setup.type.name, 'Daily walking');
    expect(detail.logs.single.type.name, 'Walking');
    expect(detail.logs.single.type.fields.single.unit, 'km');
    expect(detail.logs.single.values['distance-km'], 2);
    final old = detail.logs.single;
    await tracking.saveLog(
      ActivityLog(
        id: old.id,
        taskId: old.taskId,
        recordedAt: old.recordedAt,
        type: old.type,
        values: {field.id: 3},
        revision: old.revision,
      ),
      taskRevision: 0,
      expected: old.revision,
      now: now,
    );
    expect(
      (await tracking.loadDetail(draft.taskId.value))
          .logs
          .single
          .values[field.id],
      3,
    );
    await tracking.saveLog(
      ActivityLog(
        id: 'new-distance-log',
        taskId: draft.taskId.value,
        recordedAt: now,
        type: detail.setup.type,
        values: {'distance-m': 1000},
      ),
      taskRevision: 0,
      now: now,
    );
    final fresh = await tracking.loadDetail(draft.taskId.value);
    expect(
      trackingMetrics(fresh.setup, fresh.logs).map((m) => m.unit).toSet(),
      {'km', 'm'},
    );
  });
  test(
    'durable singleton timer restores elapsed time and detects stale updates',
    () async {
      final study = (await tracking.loadTypes()).firstWhere(
        (t) => t.icon == 'study',
      );
      final draft = TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Study',
        tracking: TrackingSetup(type: study),
      );
      await SaveTask(tasks, newId: newId, clock: () => now).execute(draft);
      await tracking.saveTimer(
        TrackingTimer(
          taskId: draft.taskId.value,
          fieldId: 'duration',
          startedAt: now,
        ),
      );
      final timer = (await TrackingRepository(
        TrackingDatabase(path),
      ).loadDetail(draft.taskId.value)).timer!;
      expect(timer.elapsed(now.add(const Duration(minutes: 5))), 300);
      await expectLater(
        tracking.saveTimer(timer),
        throwsA(isA<TrackingFailure>()),
      );
      await tracking.clearTimer(timer.revision);
      expect((await tracking.loadDetail(draft.taskId.value)).timer, isNull);
      await tracking.saveTimer(
        TrackingTimer(
          taskId: draft.taskId.value,
          fieldId: 'duration',
          startedAt: now,
        ),
      );
      await expectLater(
        tracking.clearTimer(timer.revision),
        throwsA(isA<TrackingFailure>()),
      );
      expect((await tracking.loadDetail(draft.taskId.value)).timer, isNotNull);
    },
  );
}
