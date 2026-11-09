import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/task_row_mapper.dart' as domain_mapping;
import 'package:app/domain/value_objects/local_date.dart';

typedef TaskRow = Map<String, Object?>;

List<TaskRow> _rows(ResultSet rows) =>
    rows.map((r) => Map<String, Object?>.from(r)).toList();
String _placeholders(int length) => List.filled(length, '?').join(',');

/// Returns one consistent, batched graph. No database handles leave this call.
List<TaskRow> readTaskAggregates(
  Database db, {
  String? from,
  String? through,
  String? taskId,
  String? occurrenceId,
  String? scheduledAfter,
  bool includeDeleted = false,
}) {
  db.execute('BEGIN');
  try {
    final clauses = <String>[];
    final args = <Object?>[];
    if (!includeDeleted) clauses.add('deleted_at_utc IS NULL');
    if (from != null) {
      clauses.add('effective_date >= ?');
      args.add(from);
    }
    if (through != null) {
      clauses.add('effective_date <= ?');
      args.add(through);
    }
    if (taskId != null) {
      clauses.add('task_id = ?');
      args.add(taskId);
    }
    if (occurrenceId != null) {
      clauses.add('id = ?');
      args.add(occurrenceId);
    }
    if (scheduledAfter != null) {
      clauses.add('scheduled_date > ?');
      args.add(scheduledAfter);
    }
    final occurrences = _rows(
      db.select(
        'SELECT * FROM task_occurrences ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} ORDER BY completed, start_minute IS NULL, start_minute, id',
        args,
      ),
    );
    final ids = occurrences.map((o) => o['task_id'] as String).toSet().toList();
    if (ids.isEmpty) {
      db.execute('COMMIT');
      return [];
    }
    final tasks = _readTaskGraphs(db, ids);
    final occurrenceIds = occurrences.map((o) => o['id'] as String).toList();
    final states = _rows(
      db.select(
        'SELECT * FROM task_occurrence_subtasks WHERE occurrence_id IN (${_placeholders(occurrenceIds.length)})',
        occurrenceIds,
      ),
    );
    final result = occurrences
        .map(
          (o) => <String, Object?>{
            ...tasks[o['task_id']]!,
            'occurrence': o,
            'states': states
                .where((s) => s['occurrence_id'] == o['id'])
                .toList(),
          },
        )
        .toList();
    db.execute('COMMIT');
    return result;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

Map<String, TaskRow> _readTaskGraphs(Database db, List<String>? ids) {
  final filter = ids == null
      ? ''
      : ' WHERE task_id IN (${_placeholders(ids.length)})';
  final args = ids ?? <String>[];
  final tasks = _rows(
    db.select(
      'SELECT * FROM tasks ${ids == null ? '' : 'WHERE id IN (${_placeholders(ids.length)})'}',
      args,
    ),
  );
  final weekdays = _rows(db.select('SELECT * FROM task_weekdays$filter', args));
  final subtasks = _rows(
    db.select('SELECT * FROM task_subtasks$filter ORDER BY position,id', args),
  );
  final history = _rows(
    db.select(
      'SELECT * FROM task_schedule_history$filter ORDER BY effective_from',
      args,
    ),
  );
  final tags = _rows(
    db.select(
      'SELECT tt.task_id,t.* FROM task_tags tt JOIN tags t ON t.id=tt.tag_id${ids == null ? '' : ' WHERE tt.task_id IN (${_placeholders(ids.length)})'} ORDER BY t.normalized_name',
      args,
    ),
  );
  final participants = _rows(
    db.select(
      'SELECT tp.task_id,p.* FROM task_participants tp JOIN calendar_participants p ON p.id=tp.participant_id${ids == null ? '' : ' WHERE tp.task_id IN (${_placeholders(ids.length)})'} ORDER BY p.name,p.id',
      args,
    ),
  );
  return {
    for (final t in tasks)
      t['id'] as String: {
        'task': t,
        'weekdays': weekdays.where((r) => r['task_id'] == t['id']).toList(),
        'subtasks': subtasks.where((r) => r['task_id'] == t['id']).toList(),
        'history': history.where((r) => r['task_id'] == t['id']).toList(),
        'tags': tags.where((r) => r['task_id'] == t['id']).toList(),
        'participants': participants
            .where((r) => r['task_id'] == t['id'])
            .toList(),
      },
  };
}

List<TaskRow> readTaskSchedules(Database db, String from, String through) {
  db.execute('BEGIN');
  try {
    final ids = db
        .select(
          '''SELECT id FROM tasks
      WHERE recurrence_enabled=1 AND start_date<=? AND COALESCE(rule_effective_date,start_date)<=?
      UNION SELECT task_id FROM task_schedule_history
      WHERE recurrence_enabled=1 AND start_date<=? AND effective_from<=? AND effective_until>?
      ORDER BY 1''',
          [through, through, through, through, from],
        )
        .map((r) => r['id'] as String)
        .toList();
    final result = ids.isEmpty
        ? <TaskRow>[]
        : _readTaskGraphs(db, ids).values.toList();
    db.execute('COMMIT');
    return result;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

List<TaskRow> readFutureTaskOccurrences(
  Database db,
  String taskId,
  String after,
) {
  return readTaskAggregates(
    db,
    taskId: taskId,
    scheduledAfter: after,
    includeDeleted: true,
  );
}

List<TaskRow> readTaskStreakHistory(
  Database db,
  List<String> ids,
  String through,
) {
  if (ids.isEmpty) return [];
  db.execute('BEGIN');
  try {
    final graphs = _readTaskGraphs(db, ids);
    final occurrences = _rows(
      db.select(
        'SELECT * FROM task_occurrences WHERE task_id IN (${_placeholders(ids.length)}) AND scheduled_date <= ? ORDER BY scheduled_date',
        [...ids, through],
      ),
    );
    final result = [
      for (final e in graphs.entries)
        <String, Object?>{
          ...e.value,
          'occurrences': occurrences
              .where((o) => o['task_id'] == e.key)
              .toList(),
        },
    ];
    db.execute('COMMIT');
    return result;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

class TaskDatabaseConflict implements Exception {
  const TaskDatabaseConflict(this.code);
  final String code;
}

void _insert(Database db, String table, TaskRow row) {
  db.execute(
    'INSERT INTO $table (${row.keys.join(',')}) VALUES (${_placeholders(row.length)})',
    row.values.toList(),
  );
}

void _update(
  Database db,
  String table,
  TaskRow row,
  String where,
  List<Object?> parameters,
) {
  db.execute(
    'UPDATE $table SET ${row.keys.map((k) => '$k = ?').join(',')} WHERE $where',
    [...row.values, ...parameters],
  );
  if (db.updatedRows != 1) throw const TaskDatabaseConflict('staleRevision');
}

TaskRow _expected(Map request) =>
    Map<String, Object?>.from(request['expected'] as Map);
TaskRow _checkExpected(
  Database db,
  TaskRow expected,
  String occurrenceId, {
  bool allowDeleted = false,
}) {
  final rows = db.select(
    'SELECT o.*,t.revision AS task_revision FROM task_occurrences o JOIN tasks t ON t.id=o.task_id WHERE o.id=? AND o.task_id=?',
    [occurrenceId, expected['taskId']],
  );
  if (rows.isEmpty) throw const TaskDatabaseConflict('notFound');
  final row = Map<String, Object?>.from(rows.single);
  if (!allowDeleted && row['deleted_at_utc'] != null) {
    throw const TaskDatabaseConflict('deleted');
  }
  if (row['task_revision'] != expected['taskRevision'] ||
      row['revision'] != expected['occurrenceRevision']) {
    throw const TaskDatabaseConflict('staleRevision');
  }
  return row;
}

TaskRow _occurrenceGraph(Database db, String id) {
  final o = Map<String, Object?>.from(
    db.select('SELECT * FROM task_occurrences WHERE id=?', [id]).single,
  );
  return {
    ..._readTaskGraphs(db, [o['task_id'] as String]).values.single,
    'occurrence': o,
    'states': _rows(
      db.select(
        'SELECT * FROM task_occurrence_subtasks WHERE occurrence_id=?',
        [id],
      ),
    ),
  };
}

Set<String> _dates(Database db, String taskId) => db
    .select(
      'SELECT scheduled_date,effective_date FROM task_occurrences WHERE task_id=?',
      [taskId],
    )
    .expand(
      (r) => [r['scheduled_date'] as String, r['effective_date'] as String],
    )
    .toSet();
void _writeStates(
  Database db,
  String taskId,
  String occurrenceId,
  List states,
) {
  for (final item in states) {
    final state = Map<String, Object?>.from(item as Map);
    db.execute(
      'INSERT INTO task_occurrence_subtasks(task_id,occurrence_id,subtask_id,completed) VALUES (?,?,?,?) ON CONFLICT(occurrence_id,subtask_id) DO UPDATE SET completed=excluded.completed',
      [taskId, occurrenceId, state['subtask_id'], state['completed']],
    );
  }
}

void _writeOccurrence(
  Database db,
  TaskRow occurrence,
  List states, {
  bool create = false,
}) {
  if (create) {
    _insert(db, 'task_occurrences', occurrence);
  } else {
    final fields = Map<String, Object?>.from(occurrence)
      ..remove('id')
      ..remove('task_id')
      ..remove('scheduled_date');
    _update(db, 'task_occurrences', fields, 'id=? AND task_id=?', [
      occurrence['id'],
      occurrence['task_id'],
    ]);
  }
  _writeStates(
    db,
    occurrence['task_id'] as String,
    occurrence['id'] as String,
    states,
  );
}

Map<String, Object?> commitTaskSave(Database db, Map<String, Object?> request) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final task = Map<String, Object?>.from(request['task'] as Map);
    final occurrence = Map<String, Object?>.from(request['occurrence'] as Map);
    final taskId = task['id'] as String;
    final occurrenceId = occurrence['id'] as String;
    final expected = request['expected'];
    final create = expected == null;
    final dates = <String>{};
    if (create) {
      if (db.select('SELECT id FROM tasks WHERE id=?', [taskId]).isNotEmpty ||
          db.select('SELECT id FROM task_occurrences WHERE id=?', [
            occurrenceId,
          ]).isNotEmpty) {
        throw const TaskDatabaseConflict('staleRevision');
      }
      _insert(db, 'tasks', task);
    } else {
      _checkExpected(db, _expected(request), occurrenceId);
      dates.addAll(_dates(db, taskId));
      final fields = Map<String, Object?>.from(task)..remove('id');
      _update(db, 'tasks', fields, 'id=? AND revision=?', [
        taskId,
        _expected(request)['taskRevision'],
      ]);
    }
    final tags = request['tags'] as List;
    final subtasks = request['subtasks'] as List;
    if (tags.length > 10 ||
        subtasks.where((s) => (s as Map)['active'] == 1).length > 50) {
      throw const TaskDatabaseConflict('validation');
    }
    db.execute('DELETE FROM task_weekdays WHERE task_id=?', [taskId]);
    for (final day in request['weekdays'] as List) {
      db.execute('INSERT INTO task_weekdays(task_id,weekday) VALUES (?,?)', [
        taskId,
        day,
      ]);
    }
    if (task['cadence'] == 'weekly' &&
        task['recurrence_enabled'] == 1 &&
        (request['weekdays'] as List).isEmpty) {
      throw const TaskDatabaseConflict('validation');
    }
    db.execute('DELETE FROM task_schedule_history WHERE task_id=?', [taskId]);
    for (final history in request['history'] as List) {
      _insert(
        db,
        'task_schedule_history',
        Map<String, Object?>.from(history as Map),
      );
    }
    db.execute('DELETE FROM task_tags WHERE task_id=?', [taskId]);
    for (final tag in tags) {
      final t = Map<String, Object?>.from(tag as Map);
      db.execute(
        'INSERT INTO tags(id,name,normalized_name) VALUES (?,?,?) ON CONFLICT(normalized_name) DO NOTHING',
        [t['id'], t['name'], t['normalized_name']],
      );
      final canonicalId = db.select(
        'SELECT id FROM tags WHERE normalized_name=?',
        [t['normalized_name']],
      ).single['id'];
      db.execute('INSERT INTO task_tags(task_id,tag_id) VALUES (?,?)', [
        taskId,
        canonicalId,
      ]);
    }
    // Release active-position uniqueness before applying a new ordered checklist.
    db.execute('UPDATE task_subtasks SET active=0 WHERE task_id=?', [taskId]);
    for (final item in subtasks) {
      final sub = Map<String, Object?>.from(item as Map);
      final owner = db.select('SELECT task_id FROM task_subtasks WHERE id=?', [
        sub['id'],
      ]);
      if (owner.isNotEmpty && owner.single['task_id'] != taskId) {
        throw const TaskDatabaseConflict('validation');
      }
      db.execute(
        'INSERT INTO task_subtasks(id,task_id,title,position,active) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,position=excluded.position,active=excluded.active',
        [sub['id'], taskId, sub['title'], sub['position'], sub['active']],
      );
    }
    _writeOccurrence(db, occurrence, request['states'] as List, create: create);
    for (final id in request['removed'] as List) {
      final deleted = db.select(
        'SELECT id FROM task_occurrences WHERE id=? AND task_id=? AND scheduled_date>? AND completed=0 AND deleted_at_utc IS NULL AND is_schedule_exception=0',
        [id, taskId, request['today']],
      );
      if (deleted.isEmpty) throw const TaskDatabaseConflict('staleRevision');
      db.execute('DELETE FROM task_occurrences WHERE id=? AND task_id=?', [
        id,
        taskId,
      ]);
    }
    for (final item in request['reconciled'] as List) {
      final o = Map<String, Object?>.from(item as Map);
      final current = db.select(
        'SELECT revision FROM task_occurrences WHERE id=? AND task_id=? AND scheduled_date>? AND completed=0 AND deleted_at_utc IS NULL AND is_schedule_exception=0',
        [o['id'], taskId, request['today']],
      );
      if (current.isEmpty ||
          current.single['revision'] != (o['revision'] as int) - 1) {
        throw const TaskDatabaseConflict('staleRevision');
      }
      _writeOccurrence(db, o, const []);
    }
    for (final item in request['generated'] as List) {
      final o = Map<String, Object?>.from(item as Map);
      if (o['task_id'] != taskId) {
        throw const TaskDatabaseConflict('validation');
      }
      db.execute(
        'INSERT INTO task_occurrences (${o.keys.join(',')}) VALUES (${_placeholders(o.length)}) ON CONFLICT(task_id,scheduled_date) DO NOTHING',
        o.values.toList(),
      );
    }
    dates.addAll(_dates(db, taskId));
    final graph = _occurrenceGraph(db, occurrenceId);
    // Validate the response before committing: a hydration failure is a failed write.
    domain_mapping.taskAggregateFromRow(graph);
    for (final date in dates) {
      LocalDate.parse(date);
    }
    db.execute('COMMIT');
    return {'aggregate': graph, 'dates': dates.toList(), 'changed': true};
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

Map<String, Object?> insertTaskOccurrences(
  Database db,
  Map<String, Object?> request,
) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final expected = Map<String, Object?>.from(request['taskRevisions'] as Map);
    for (final entry in expected.entries) {
      final rows = db.select('SELECT revision FROM tasks WHERE id=?', [
        entry.key,
      ]);
      if (rows.isEmpty || rows.single['revision'] != entry.value) {
        throw const TaskDatabaseConflict('staleRevision');
      }
    }
    final dates = <String>{};
    final tasks = <String>{};
    for (final item in request['candidates'] as List) {
      final o = Map<String, Object?>.from(item as Map);
      db.execute(
        'INSERT INTO task_occurrences (${o.keys.join(',')}) VALUES (${_placeholders(o.length)}) ON CONFLICT(task_id,scheduled_date) DO NOTHING',
        o.values.toList(),
      );
      if (db.updatedRows == 1) {
        dates.add(o['effective_date'] as String);
        tasks.add(o['task_id'] as String);
      }
    }
    for (final date in dates) {
      LocalDate.parse(date);
    }
    db.execute('COMMIT');
    return {
      'changed': dates.isNotEmpty,
      'dates': dates.toList(),
      'taskIds': tasks.toList(),
    };
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

Map<String, Object?> commitTaskOccurrence(
  Database db,
  Map<String, Object?> request, {
  bool restore = false,
}) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final o = Map<String, Object?>.from(request['occurrence'] as Map);
    final e = _expected(request);
    final current = _checkExpected(
      db,
      e,
      o['id'] as String,
      allowDeleted: restore,
    );
    if (o['task_id'] != current['task_id'] ||
        o['scheduled_date'] != current['scheduled_date'] ||
        o['revision'] != (current['revision'] as int) + 1) {
      throw const TaskDatabaseConflict('staleRevision');
    }
    _writeOccurrence(db, o, request['states'] as List);
    final dates = {
      current['effective_date'] as String,
      o['effective_date'] as String,
      o['scheduled_date'] as String,
    };
    for (final date in dates) {
      LocalDate.parse(date);
    }
    db.execute('COMMIT');
    return {'changed': true, 'dates': dates.toList()};
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
