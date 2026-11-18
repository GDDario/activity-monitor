import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

class ProfileDatabase {
  const ProfileDatabase({required this.path});
  final String path;
  Future<Map<String, Object?>> request(Map<String, Object?> request) =>
      compute(_worker, {'path': path, ...request});
}

Map<String, Object?> _worker(Map<String, Object?> r) {
  Database? db;
  try {
    db = sqlite3.open(r['path'] as String, mode: OpenMode.readWrite);
    db.execute('PRAGMA busy_timeout=5000');
    db.execute('PRAGMA foreign_keys=ON');
    if (r['operation'] == 'load') {
      final rows = db.select('SELECT * FROM local_profile WHERE slot=1');
      return {
        'profile': rows.isEmpty ? null : Map<String, Object?>.from(rows.single),
      };
    }
    if (r['operation'] != 'save') throw StateError('Unknown profile operation');
    db.execute('BEGIN IMMEDIATE');
    final rows = db.select(
      'SELECT id,revision FROM local_profile WHERE slot=1',
    );
    final expected = r['expected'];
    String? failure;
    if (expected == null && rows.isNotEmpty) {
      failure = 'identityConflict';
    } else if (expected != null && rows.isEmpty) {
      failure = 'notFound';
    } else if (expected != null &&
        (rows.single['id'] != r['id'] || rows.single['revision'] != expected)) {
      failure = 'staleRevision';
    }
    if (failure != null) {
      db.execute('ROLLBACK');
      return {'failure': failure};
    }
    final revision = expected == null ? 0 : (expected as int) + 1;
    db.execute(
      'INSERT INTO local_profile(slot,id,display_name,appearance,language,avatar_png,revision) VALUES(1,?,?,?,?,?,?) ON CONFLICT(slot) DO UPDATE SET display_name=excluded.display_name,appearance=excluded.appearance,language=excluded.language,avatar_png=excluded.avatar_png,revision=excluded.revision',
      [
        r['id'],
        r['name'],
        r['appearance'],
        r['language'],
        r['avatar'],
        revision,
      ],
    );
    final saved = Map<String, Object?>.from(
      db.select('SELECT * FROM local_profile WHERE slot=1').single,
    );
    db.execute('COMMIT');
    return {'profile': saved};
  } catch (_) {
    if (db != null && !db.autocommit) {
      db.execute('ROLLBACK');
    }
    return {'failure': 'storageUnavailable'};
  } finally {
    db?.close();
  }
}
