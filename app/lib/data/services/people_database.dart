import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/task_database_operations.dart';

class PeopleDatabase {
  const PeopleDatabase({required this.path});
  final String path;
  Future<Map<String, Object?>> request(Map<String, Object?> request) =>
      compute(_worker, {'path': path, ...request});
}

List<Map<String, Object?>> _rows(ResultSet rows) =>
    rows.map((r) => Map<String, Object?>.from(r)).toList();
Map<String, Object?> _worker(Map<String, Object?> r) {
  Database? db;
  try {
    db = sqlite3.open(r['path'] as String, mode: OpenMode.readWrite);
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA busy_timeout=5000');
    db.execute(r['operation'] == 'save' ? 'BEGIN IMMEDIATE' : 'BEGIN');
    final result = switch (r['operation']) {
      'save' => _save(db, r),
      'history' => _history(db, r),
      'snapshot' => _snapshot(db, r),
      _ => throw StateError('Unknown people operation'),
    };
    db.execute('COMMIT');
    return result;
  } catch (_) {
    if (db != null && !db.autocommit) db.execute('ROLLBACK');
    return {'failure': 'storageUnavailable'};
  } finally {
    db?.close();
  }
}

Map<String, Object?> _save(Database db, Map<String, Object?> r) {
  final id = r['id'] as String;
  final existing = db.select(
    'SELECT revision FROM calendar_participants WHERE id=?',
    [id],
  );
  final expected = r['expected'];
  if (expected == null && existing.isNotEmpty) {
    return {'failure': 'identityConflict'};
  }
  if (expected != null && existing.isEmpty) return {'failure': 'notFound'};
  if (expected != null && existing.single['revision'] != expected) {
    return {'failure': 'staleRevision'};
  }
  final revision = expected == null ? 0 : (expected as int) + 1;
  if (expected == null) {
    db.execute(
      'INSERT INTO calendar_participants(id,name,role,revision) VALUES (?,?,?,?)',
      [id, r['name'], r['role'], revision],
    );
  } else {
    db.execute(
      'UPDATE calendar_participants SET name=?,role=?,revision=? WHERE id=?',
      [r['name'], r['role'], revision, id],
    );
  }
  db.execute('DELETE FROM person_categories WHERE participant_id=?', [id]);
  for (final c in r['categories'] as List) {
    db.execute('INSERT INTO person_categories VALUES (?,?)', [id, c]);
  }
  return {'revision': revision};
}

Map<String, Object?> _snapshot(Database db, Map<String, Object?> r) {
  final today = r['today'] as String, since = r['since'] as String;
  final people = _rows(db.select('SELECT * FROM calendar_participants'));
  final categories = _rows(db.select('SELECT * FROM person_categories'));
  final stats = _rows(
    db.select(
      '''SELECT tp.participant_id,
    SUM(CASE WHEN o.effective_date=? AND o.completed=0 THEN 1 ELSE 0 END) AS active,
    SUM(CASE WHEN o.effective_date BETWEEN ? AND ? AND o.completed=1 THEN 1 ELSE 0 END) AS recent
    FROM task_participants tp JOIN task_occurrences o ON o.task_id=tp.task_id
    WHERE o.deleted_at_utc IS NULL GROUP BY tp.participant_id''',
      [today, since, today],
    ),
  );
  // Window ranking returns one real last completed occurrence per person.
  final last = _rows(
    db.select(
      '''SELECT participant_id,title,effective_date FROM (
    SELECT tp.participant_id,t.title,o.effective_date,
      ROW_NUMBER() OVER (PARTITION BY tp.participant_id ORDER BY o.effective_date DESC,o.start_minute IS NULL,o.start_minute DESC,t.title COLLATE NOCASE,o.id) AS rank
    FROM task_participants tp JOIN tasks t ON t.id=tp.task_id JOIN task_occurrences o ON o.task_id=t.id
    WHERE o.deleted_at_utc IS NULL AND o.completed=1 AND o.effective_date<=?) WHERE rank=1''',
      [today],
    ),
  );
  final totals = db
      .select(
        '''SELECT
    COALESCE(SUM(CASE WHEN EXISTS(SELECT 1 FROM task_participants tp WHERE tp.task_id=o.task_id) THEN 1 ELSE 0 END),0) AS shared,
    COALESCE(SUM(CASE WHEN NOT EXISTS(SELECT 1 FROM task_participants tp WHERE tp.task_id=o.task_id) THEN 1 ELSE 0 END),0) AS solo,
    COALESCE(SUM(CASE WHEN o.completed=0 AND EXISTS(SELECT 1 FROM task_participants tp WHERE tp.task_id=o.task_id) THEN 1 ELSE 0 END),0) AS active
    FROM task_occurrences o WHERE o.deleted_at_utc IS NULL AND o.effective_date=?''',
        [today],
      )
      .single;
  return {
    'people': people,
    'categories': categories,
    'stats': stats,
    'last': last,
    'shared': totals['shared'],
    'solo': totals['solo'],
    'active': totals['active'],
  };
}

Map<String, Object?> _history(Database db, Map<String, Object?> r) {
  final id = r['id'] as String;
  if (db.select('SELECT id FROM calendar_participants WHERE id=?', [
    id,
  ]).isEmpty) {
    return {'failure': 'notFound'};
  }
  const from =
      'FROM task_occurrences o JOIN tasks t ON t.id=o.task_id JOIN task_participants tp ON tp.task_id=t.id WHERE tp.participant_id=? AND o.deleted_at_utc IS NULL';
  final total =
      db.select('SELECT COUNT(*) AS n $from', [id]).single['n'] as int;
  final maxPage = total == 0 ? 0 : (total - 1) ~/ 20;
  final page = (r['page'] as int).clamp(0, maxPage);
  final order = r['ascending'] == true ? 'ASC' : 'DESC';
  final ids = db
      .select(
        'SELECT o.id $from ORDER BY o.effective_date $order,o.start_minute IS NULL,o.start_minute $order,t.title COLLATE NOCASE,o.id LIMIT 20 OFFSET ?',
        [id, page * 20],
      )
      .map((e) => e['id'] as String)
      .toList();
  final graphs = readTaskAggregates(
    db,
    selectedOccurrenceIds: ids,
    manageTransaction: false,
  );
  final byId = {for (final g in graphs) (g['occurrence'] as Map)['id']: g};
  return {
    'total': total,
    'page': page,
    'rows': [for (final id in ids) byId[id]!],
  };
}
