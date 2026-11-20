import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/database_migration.dart';
import 'package:app/data/services/tracking_codec.dart';
import 'package:app/domain/models/task_tracking.dart';

class Migration0008AddTaskTracking extends DatabaseMigration {
  const Migration0008AddTaskTracking()
    : super(8, _apply, name: '0008_add_task_tracking');
  static void _apply(Database db) {
    db.execute('''CREATE TABLE task_types (
      id TEXT PRIMARY KEY NOT NULL,
      normalized_name TEXT NOT NULL UNIQUE CHECK(length(normalized_name) BETWEEN 1 AND 64),
      builtin INTEGER NOT NULL CHECK(builtin IN (0,1)),
      revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),
      hidden INTEGER NOT NULL DEFAULT 0 CHECK(hidden IN (0,1)),
      notice INTEGER NOT NULL DEFAULT 0 CHECK(notice IN (0,1)),
      definition TEXT NOT NULL CHECK(json_valid(definition))
    )''');
    installBuiltinTaskTypes(db, builtinTaskTypes(), initial: true);
    db.execute(
      "ALTER TABLE tasks ADD COLUMN tracking_setup TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(tracking_setup))",
    );
    db.execute('''CREATE TABLE task_activity_logs (
      id TEXT PRIMARY KEY NOT NULL,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      occurrence_id TEXT REFERENCES task_occurrences(id) ON DELETE SET NULL,
      recorded_at TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK(revision>=0),
      payload TEXT NOT NULL CHECK(json_valid(payload))
    )''');
    db.execute(
      'CREATE INDEX task_activity_logs_by_task ON task_activity_logs(task_id,recorded_at,id)',
    );
    db.execute('''CREATE TABLE task_tracking_timer (
      singleton INTEGER PRIMARY KEY CHECK(singleton=1),
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      revision INTEGER NOT NULL CHECK(revision>=0),
      payload TEXT NOT NULL CHECK(json_valid(payload))
    )''');
  }
}

/// Called by catalog migrations; existing definitions/preferences are retained.
void installBuiltinTaskTypes(
  Database db,
  List<TaskType> types, {
  bool initial = false,
}) {
  for (final type in types) {
    if (!type.builtin) throw ArgumentError('Expected built-in type');
    db.execute(
      'INSERT INTO task_types(id,normalized_name,builtin,definition,notice) VALUES (?,?,1,?,?) ON CONFLICT(id) DO NOTHING',
      [
        type.id,
        type.name.toLowerCase(),
        jsonEncode(encodeTaskType(type)),
        initial ? 0 : 1,
      ],
    );
  }
}
