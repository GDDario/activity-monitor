import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/tracking_codec.dart';
import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/use_cases/tracking_metrics.dart';
import 'package:app/domain/value_objects/local_date.dart';

class TrackingDatabase {
  const TrackingDatabase(this.path);
  final String path;
  Future<Map<String, Object?>> request(Map<String, Object?> request) =>
      compute(_worker, {'path': path, ...request});
}

class TrackingStorageConflict implements Exception {
  const TrackingStorageConflict(this.code, [this.fields = const {}]);
  final String code;
  final Map<String, String> fields;
}

TaskType readTrackingType(Database db, String id) {
  final rows = db.select('SELECT * FROM task_types WHERE id=?', [id]);
  if (rows.isEmpty) throw const TrackingStorageConflict('notFound');
  final r = rows.single;
  return decodeTaskType(jsonDecode(r['definition'] as String)).copyWith(
    revision: r['revision'] as int,
    hidden: r['hidden'] == 1,
    notice: r['notice'] == 1,
  );
}

void validateTrackingSetupForSave(
  Database db,
  TrackingSetup setup, {
  String? taskId,
}) {
  final type = readTrackingType(db, setup.type.id);
  if (type.revision != setup.type.revision) {
    throw const TrackingStorageConflict('staleRevision');
  }
  if (jsonEncode(encodeTaskType(type.copyWith(hidden: false, notice: false))) !=
      jsonEncode(
        encodeTaskType(setup.type.copyWith(hidden: false, notice: false)),
      )) {
    throw const TrackingStorageConflict('validation');
  }
  final errors = validateTrackingHistory(setup, _readLogs(db, taskId));
  // Task saves run this validation inside the same write transaction.
  if (errors.isNotEmpty) throw TrackingStorageConflict('validation', errors);
}

List<ActivityLog> _readLogs(Database db, String? taskId) => taskId == null
    ? []
    : db
          .select(
            'SELECT payload FROM task_activity_logs WHERE task_id=? ORDER BY recorded_at,id',
            [taskId],
          )
          .map((r) => decodeActivityLog(jsonDecode(r['payload'] as String)))
          .toList();
Map<String, Object?> _task(Database db, String id, int? expected) {
  final rows = db.select(
    'SELECT id,title,revision,tracking_setup FROM tasks WHERE id=?',
    [id],
  );
  if (rows.isEmpty) throw const TrackingStorageConflict('notFound');
  final row = Map<String, Object?>.from(rows.single);
  if (expected != null && row['revision'] != expected) {
    throw const TrackingStorageConflict('staleRevision');
  }
  return row;
}

Map<String, Object?> _worker(Map<String, Object?> request) {
  Database? db;
  try {
    db = sqlite3.open(request['path'] as String, mode: OpenMode.readWrite);
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA busy_timeout=5000');
    db.execute('BEGIN IMMEDIATE');
    final result = trackingOperation(db, request);
    db.execute('COMMIT');
    return result;
  } on TrackingStorageConflict catch (e) {
    if (db != null) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
    }
    return {'failure': e.code, 'fields': e.fields};
  } on ArgumentError {
    if (db != null) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
    }
    return {'failure': 'validation'};
  } on SqliteException catch (e) {
    if (db != null) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
    }
    return {
      'failure': e.resultCode == 19 ? 'validation' : 'storageUnavailable',
    };
  } catch (_) {
    if (db != null) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
    }
    return {'failure': 'storageUnavailable'};
  } finally {
    db?.close();
  }
}

Map<String, Object?> trackingOperation(Database db, Map<String, Object?> r) {
  final op = r['operation'];
  if (op == 'types') {
    return {
      'types': [
        for (final row in db.select(
          'SELECT id FROM task_types ORDER BY builtin DESC,normalized_name',
        ))
          encodeTaskType(readTrackingType(db, row['id'] as String)),
      ],
    };
  }
  if (op == 'saveType') {
    var type = decodeTaskType(r['type']);
    if (type.builtin) throw const TrackingStorageConflict('validation');
    final oldRows = db.select('SELECT id FROM task_types WHERE id=?', [
      type.id,
    ]);
    if (oldRows.isEmpty) {
      if (r['expected'] != null) {
        throw const TrackingStorageConflict('notFound');
      }
      type = type.copyWith(revision: 0);
      db.execute(
        'INSERT INTO task_types(id,normalized_name,builtin,definition) VALUES (?,?,0,?)',
        [type.id, type.name.toLowerCase(), jsonEncode(encodeTaskType(type))],
      );
    } else {
      final old = readTrackingType(db, type.id);
      if (old.builtin) throw const TrackingStorageConflict('validation');
      if (r['expected'] != old.revision) {
        throw const TrackingStorageConflict('staleRevision');
      }
      for (final field in type.fields) {
        final prior = old.fields.where((f) => f.id == field.id).firstOrNull;
        if (prior != null &&
            (prior.kind != field.kind ||
                prior.unit != field.unit ||
                prior.scope != field.scope)) {
          throw const TrackingStorageConflict('validation');
        }
      }
      type = type.copyWith(revision: old.revision + 1);
      db.execute(
        'UPDATE task_types SET normalized_name=?,definition=?,revision=? WHERE id=?',
        [
          type.name.toLowerCase(),
          jsonEncode(encodeTaskType(type)),
          type.revision,
          type.id,
        ],
      );
    }
    return {};
  }
  if (op == 'visibility' || op == 'notice') {
    final type = readTrackingType(db, r['id'] as String);
    if (type.revision != r['expected']) {
      throw const TrackingStorageConflict('staleRevision');
    }
    if (op == 'visibility' &&
        type.id == generalTaskType().id &&
        r['hidden'] == true) {
      throw const TrackingStorageConflict('validation');
    }
    db.execute(
      op == 'visibility'
          ? 'UPDATE task_types SET hidden=?,revision=revision+1 WHERE id=?'
          : 'UPDATE task_types SET notice=?,revision=revision+1 WHERE id=?',
      [
        op == 'notice'
            ? 0
            : r['hidden'] == true
            ? 1
            : 0,
        type.id,
      ],
    );
    return {};
  }
  if (op == 'detail') {
    final t = _task(db, r['taskId'] as String, null);
    var setup = decodeTrackingSetup(t['tracking_setup']);
    final latest = readTrackingType(db, setup.type.id);
    if (latest.revision != setup.type.revision) {
      setup = setup.refreshType(latest);
    }
    final timers = db.select(
      r"SELECT payload FROM task_tracking_timer WHERE COALESCE(json_extract(payload,'$.cleared'),0)=0",
    );
    return {
      'title': t['title'],
      'revision': t['revision'],
      'setup': encodeTrackingSetup(setup),
      'logs': _readLogs(db, t['id'] as String).map(encodeActivityLog).toList(),
      'timer': timers.isEmpty
          ? null
          : jsonDecode(timers.single['payload'] as String),
    };
  }
  if (op == 'finished') {
    return {
      'tasks': [
        for (final row in db.select(
          'SELECT id,title,tracking_setup FROM tasks ORDER BY title,id',
        ))
          if (decodeTrackingSetup(row['tracking_setup']).finished)
            {'id': row['id'], 'title': row['title']},
      ],
    };
  }
  if (op == 'saveLog' || op == 'deleteLog') {
    final log = op == 'saveLog' ? decodeActivityLog(r['log']) : null;
    final taskId = log?.taskId ?? r['taskId'] as String;
    final t = _task(db, taskId, r['taskRevision'] as int);
    final setup = decodeTrackingSetup(t['tracking_setup']);
    final id = log?.id ?? r['id'] as String;
    final rows = db.select(
      'SELECT task_id,revision,payload FROM task_activity_logs WHERE id=?',
      [id],
    );
    if (rows.isEmpty && r['expected'] != null ||
        rows.isNotEmpty &&
            (rows.single['task_id'] != taskId ||
                rows.single['revision'] != r['expected'])) {
      throw const TrackingStorageConflict('staleRevision');
    }
    final all = _readLogs(db, taskId).where((l) => l.id != id).toList();
    if (log != null) {
      if (log.recordedAt.isAfter(DateTime.parse(r['now'] as String))) {
        throw const TrackingStorageConflict('validation', {
          'recordedAt': 'invalid',
        });
      }
      final type = rows.isEmpty
          ? readTrackingType(db, setup.type.id)
          : decodeActivityLog(jsonDecode(rows.single['payload'] as String))
                .type;
      if (jsonEncode(
            encodeTaskType(type.copyWith(hidden: false, notice: false)),
          ) !=
          jsonEncode(
            encodeTaskType(log.type.copyWith(hidden: false, notice: false)),
          )) {
        throw const TrackingStorageConflict('staleRevision');
      }
      if (log.occurrenceId != null &&
          db.select(
            'SELECT id FROM task_occurrences WHERE id=? AND task_id=?',
            [log.occurrenceId, taskId],
          ).isEmpty) {
        throw const TrackingStorageConflict('validation');
      }
      all.add(log);
    }
    final errors = validateTrackingHistory(setup, all);
    // New schema requirements apply on setup save; they do not prevent log corrections.
    errors.removeWhere(
      (key, _) => setup.type.fields.any(
        (f) =>
            f.scope == FieldScope.setup &&
            f.id == key &&
            !setup.values.containsKey(key),
      ),
    );
    if (errors.isNotEmpty) throw TrackingStorageConflict('validation', errors);
    if (log != null) {
      final saved = ActivityLog(
        id: log.id,
        taskId: taskId,
        recordedAt: log.recordedAt,
        type: log.type,
        values: log.values,
        occurrenceId: log.occurrenceId,
        revision: rows.isEmpty ? 0 : (rows.single['revision'] as int) + 1,
      );
      db.execute(
        'INSERT INTO task_activity_logs(id,task_id,occurrence_id,recorded_at,revision,payload) VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET recorded_at=excluded.recorded_at,revision=excluded.revision,payload=excluded.payload',
        [
          id,
          taskId,
          saved.occurrenceId,
          saved.recordedAt.toIso8601String(),
          saved.revision,
          jsonEncode(encodeActivityLog(saved)),
        ],
      );
      if (r['timerRevision'] != null) {
        final timer = db.select(
          'SELECT task_id,revision FROM task_tracking_timer',
        );
        if (timer.isEmpty ||
            timer.single['task_id'] != taskId ||
            timer.single['revision'] != r['timerRevision']) {
          throw const TrackingStorageConflict('staleRevision');
        }
        _clearTimer(db);
      }
    } else {
      if (rows.isEmpty) throw const TrackingStorageConflict('notFound');
      db.execute('DELETE FROM task_activity_logs WHERE id=?', [id]);
    }
    return {};
  }
  if (op == 'lifecycle') {
    final t = _task(db, r['taskId'] as String, r['expected'] as int);
    final setup = decodeTrackingSetup(t['tracking_setup']);
    final today = LocalDate.parse(r['today'] as String);
    final next = r['finish'] == true
        ? setup.finish(today)
        : setup.reopen(today);
    db.execute(
      'UPDATE tasks SET tracking_setup=?,revision=revision+1 WHERE id=?',
      [jsonEncode(encodeTrackingSetup(next)), t['id']],
    );
    if (r['finish'] == true) {
      db.execute(
        'DELETE FROM task_occurrences WHERE task_id=? AND scheduled_date>? AND completed=0 AND deleted_at_utc IS NULL AND is_schedule_exception=0',
        [t['id'], today.toString()],
      );
    }
    return {};
  }
  if (op == 'timer' || op == 'clearTimer') {
    final rows = db.select(
      'SELECT task_id,revision,payload FROM task_tracking_timer',
    );
    final active =
        rows.isNotEmpty &&
        (jsonDecode(rows.single['payload'] as String) as Map)['cleared'] !=
            true;
    if (!active && r['expected'] != null ||
        active && rows.single['revision'] != r['expected']) {
      throw const TrackingStorageConflict('staleRevision');
    }
    if (op == 'clearTimer') {
      _clearTimer(db);
      return {};
    }
    final timer = decodeTrackingTimer(r['timer']);
    if (active && rows.single['task_id'] != timer.taskId) {
      throw const TrackingStorageConflict('staleRevision');
    }
    final task = _task(db, timer.taskId, null);
    final type = readTrackingType(
      db,
      decodeTrackingSetup(task['tracking_setup']).type.id,
    );
    if (!type.fields.any(
          (f) =>
              f.id == timer.fieldId &&
              f.kind == FieldKind.duration &&
              f.scope == FieldScope.log,
        ) ||
        timer.stoppedSeconds != null &&
            (!timer.stoppedSeconds!.isFinite || timer.stoppedSeconds! < 0)) {
      throw const TrackingStorageConflict('validation');
    }
    final next = TrackingTimer(
      taskId: timer.taskId,
      fieldId: timer.fieldId,
      startedAt: timer.startedAt,
      stoppedSeconds: timer.stoppedSeconds,
      revision: rows.isEmpty ? 0 : (rows.single['revision'] as int) + 1,
    );
    db.execute(
      'INSERT INTO task_tracking_timer(singleton,task_id,revision,payload) VALUES (1,?,?,?) ON CONFLICT(singleton) DO UPDATE SET task_id=excluded.task_id,revision=excluded.revision,payload=excluded.payload',
      [next.taskId, next.revision, jsonEncode(encodeTrackingTimer(next))],
    );
    return {};
  }
  throw const TrackingStorageConflict('storageUnavailable');
}

// Keep an inactive row so an older command cannot match a newly started timer.
void _clearTimer(Database db) {
  db.execute(
    "UPDATE task_tracking_timer SET payload='{\"cleared\":true}',revision=revision+1 WHERE singleton=1",
  );
}
