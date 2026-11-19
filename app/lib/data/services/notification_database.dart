import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

abstract class NotificationStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);
  Future<Map<String, int>> allocate(List<String> occurrenceIds);
}

class NotificationDatabase implements NotificationStore {
  const NotificationDatabase({required this.path});
  final String path;
  Future<Map<String, Object?>> _request(String op, {Object? value}) =>
      compute(_worker, {'path': path, 'op': op, 'value': value});
  @override
  Future<bool> readEnabled() async =>
      (await _request('read'))['enabled'] as bool;
  @override
  Future<void> writeEnabled(bool enabled) async {
    await _request('save', value: enabled);
  }

  @override
  Future<Map<String, int>> allocate(List<String> occurrenceIds) async =>
      Map<String, int>.from(
        (await _request('ids', value: occurrenceIds))['ids'] as Map,
      );
}

Map<String, Object?> _worker(Map<String, Object?> r) {
  Database? db;
  try {
    db = sqlite3.open(r['path'] as String, mode: OpenMode.readWrite);
    db.execute('PRAGMA busy_timeout=5000');
    if (r['op'] == 'read') {
      return {
        'enabled':
            db
                .select(
                  'SELECT enabled FROM notification_settings WHERE slot=1',
                )
                .single['enabled'] ==
            1,
      };
    }
    db.execute('BEGIN IMMEDIATE');
    final ids = <String, int>{};
    if (r['op'] == 'save') {
      db.execute('UPDATE notification_settings SET enabled=? WHERE slot=1', [
        r['value'] == true ? 1 : 0,
      ]);
    } else if (r['op'] == 'ids') {
      for (final key in r['value'] as List) {
        db.execute(
          'INSERT INTO notification_ids(occurrence_id) VALUES(?) ON CONFLICT(occurrence_id) DO NOTHING',
          [key],
        );
        ids[key as String] =
            db.select('SELECT id FROM notification_ids WHERE occurrence_id=?', [
                  key,
                ]).single['id']
                as int;
      }
    } else {
      throw StateError('Unknown notification operation');
    }
    db.execute('COMMIT');
    return {'ids': ids};
  } catch (_) {
    if (db != null && !db.autocommit) db.execute('ROLLBACK');
    throw StateError('Notification storage unavailable');
  } finally {
    db?.close();
  }
}
