import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/database_migration.dart';

/// Converts the legacy agenda without changing identities or inventing provenance.
class Migration0004CreateTaskTables extends DatabaseMigration {
  const Migration0004CreateTaskTables()
    : super(4, _apply, name: '0004_create_task_tables');

  // SQLite's default trim only removes ASCII spaces. Match Dart String.trim.
  static const _whitespace =
      'char(9,10,11,12,13,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,65279)';

  static String _text(String name, int maximum, {bool blank = false}) =>
      'instr($name, char(0)) = 0 AND length($name) <= $maximum'
      '${blank ? '' : ' AND length(trim($name, $_whitespace)) > 0'}';

  static String _date(String name) =>
      "instr($name, char(0)) = 0 AND length($name) = 10 AND $name GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "
      "AND substr($name, 6, 2) BETWEEN '01' AND '12' AND substr($name, 9, 2) BETWEEN '01' AND '31'";

  static const _window = '''
    CHECK ((start_minute IS NULL AND end_minute IS NULL) OR
      (start_minute IS NOT NULL AND end_minute IS NOT NULL AND
       typeof(start_minute) = 'integer' AND typeof(end_minute) = 'integer' AND
       start_minute >= 0 AND start_minute < end_minute AND end_minute < 1440)),
    CHECK (reminder_minutes_before IS NULL OR
      (start_minute IS NOT NULL AND end_minute IS NOT NULL AND
       reminder_minutes_before IN (0, 5, 15, 30, 60)))
  ''';
  static const _cadence = "cadence IN ('one-time', 'daily', 'weekly')";

  static void _apply(Database db) {
    db.execute('''CREATE TABLE tasks (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL CHECK (${_text('title', 200)}),
      notes TEXT CHECK (notes IS NULL OR (${_text('notes', 10000, blank: true)})),
      priority TEXT NOT NULL DEFAULT 'low' CHECK (priority IN ('low', 'medium', 'high')),
      cadence TEXT NOT NULL DEFAULT 'one-time' CHECK ($_cadence),
      recurrence_enabled INTEGER NOT NULL DEFAULT 0 CHECK (recurrence_enabled IN (0, 1)),
      start_date TEXT NOT NULL CHECK (${_date('start_date')}),
      rule_effective_date TEXT CHECK (rule_effective_date IS NULL OR (${_date('rule_effective_date')})),
      start_minute INTEGER, end_minute INTEGER, reminder_minutes_before INTEGER,
      streak_enabled INTEGER NOT NULL DEFAULT 0 CHECK (streak_enabled IN (0, 1)),
      day_period TEXT CHECK (day_period IS NULL OR day_period IN ('morning', 'afternoon', 'evening')),
      revision INTEGER NOT NULL DEFAULT 0 CHECK (typeof(revision) = 'integer' AND revision >= 0),
      created_at_utc TEXT, updated_at_utc TEXT,
      CHECK (cadence <> 'one-time' OR recurrence_enabled = 0),
      CHECK (streak_enabled = 0 OR (cadence = 'daily' AND recurrence_enabled = 1)),
      CHECK (day_period IS NULL OR cadence = 'daily'),
      $_window
    )''');
    db.execute('''CREATE TABLE task_weekdays (
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      weekday INTEGER NOT NULL CHECK (typeof(weekday) = 'integer' AND weekday BETWEEN 1 AND 7),
      PRIMARY KEY (task_id, weekday)
    )''');
    db.execute('''CREATE TABLE task_occurrences (
      id TEXT PRIMARY KEY NOT NULL,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      scheduled_date TEXT NOT NULL CHECK (${_date('scheduled_date')}),
      effective_date TEXT NOT NULL CHECK (${_date('effective_date')}),
      start_minute INTEGER, end_minute INTEGER, reminder_minutes_before INTEGER,
      completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
      completed_at_utc TEXT, deleted_at_utc TEXT,
      is_schedule_exception INTEGER NOT NULL DEFAULT 0 CHECK (is_schedule_exception IN (0, 1)),
      revision INTEGER NOT NULL DEFAULT 0 CHECK (typeof(revision) = 'integer' AND revision >= 0),
      UNIQUE (task_id, scheduled_date), UNIQUE (task_id, id),
      CHECK (completed = 1 OR completed_at_utc IS NULL),
      $_window
    )''');
    db.execute('''CREATE TABLE task_subtasks (
      id TEXT PRIMARY KEY NOT NULL,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK (${_text('title', 200)}),
      position INTEGER NOT NULL CHECK (typeof(position) = 'integer' AND position >= 0),
      active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
      UNIQUE (task_id, id)
    )''');
    db.execute('''CREATE TABLE task_occurrence_subtasks (
      task_id TEXT NOT NULL,
      occurrence_id TEXT NOT NULL, subtask_id TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
      PRIMARY KEY (occurrence_id, subtask_id),
      FOREIGN KEY (task_id, occurrence_id) REFERENCES task_occurrences(task_id, id) ON DELETE CASCADE,
      FOREIGN KEY (task_id, subtask_id) REFERENCES task_subtasks(task_id, id) ON DELETE CASCADE
    )''');
    db.execute('''CREATE TABLE tags (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL CHECK (${_text('name', 32)}),
      normalized_name TEXT NOT NULL UNIQUE CHECK (${_text('normalized_name', 32)} AND normalized_name = trim(normalized_name, $_whitespace))
    )''');
    db.execute('''CREATE TABLE task_tags (
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      PRIMARY KEY (task_id, tag_id)
    )''');
    db.execute('''CREATE TABLE task_participants (
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      participant_id TEXT NOT NULL REFERENCES calendar_participants(id) ON DELETE CASCADE,
      PRIMARY KEY (task_id, participant_id)
    )''');
    db.execute('''CREATE TABLE task_schedule_history (
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      effective_from TEXT NOT NULL CHECK (${_date('effective_from')}),
      effective_until TEXT NOT NULL CHECK (${_date('effective_until')}),
      start_date TEXT NOT NULL CHECK (${_date('start_date')}),
      cadence TEXT NOT NULL CHECK ($_cadence),
      recurrence_enabled INTEGER NOT NULL CHECK (recurrence_enabled IN (0, 1)),
      weekday_mask INTEGER NOT NULL CHECK (typeof(weekday_mask) = 'integer' AND weekday_mask BETWEEN 0 AND 127),
      start_minute INTEGER, end_minute INTEGER, reminder_minutes_before INTEGER,
      PRIMARY KEY (task_id, effective_from),
      CHECK (effective_until > effective_from),
      CHECK (cadence <> 'one-time' OR recurrence_enabled = 0),
      CHECK ((cadence = 'weekly' AND recurrence_enabled = 1 AND weekday_mask > 0) OR
             ((cadence <> 'weekly' OR recurrence_enabled = 0) AND weekday_mask = 0)),
      $_window
    )''');
    db.execute(
      'CREATE UNIQUE INDEX task_subtasks_active_position ON task_subtasks(task_id, position) WHERE active = 1',
    );
    db.execute(
      'CREATE INDEX task_occurrences_visible ON task_occurrences(effective_date, completed, id) WHERE deleted_at_utc IS NULL',
    );
    db.execute(
      'CREATE INDEX task_participants_participant ON task_participants(participant_id, task_id)',
    );
    db.execute('CREATE INDEX task_tags_tag ON task_tags(tag_id, task_id)');
    db.execute(
      'CREATE INDEX task_occurrence_subtasks_subtask ON task_occurrence_subtasks(task_id, subtask_id)',
    );

    // Legacy text is validated, never normalized: byte preservation is required.
    for (final row in db.select(
      'SELECT id, title, date FROM calendar_entries',
    )) {
      final id = row['id'] as String;
      final title = row['title'] as String;
      final date = row['date'] as String;
      if (id.isEmpty ||
          id.contains('\u0000') ||
          title.trim().isEmpty ||
          title.runes.length > 200 ||
          title.contains('\u0000') ||
          !_validDate(date)) {
        throw StateError('Legacy calendar data cannot be migrated safely');
      }
    }
    db.execute('''INSERT INTO tasks (id, title, cadence, start_date)
      SELECT id, title, cadence, date FROM calendar_entries''');
    db.execute('''INSERT INTO task_occurrences (id, task_id, scheduled_date, effective_date, completed)
      SELECT id, id, date, date, completed FROM calendar_entries''');
    db.execute('''INSERT INTO task_participants (task_id, participant_id)
      SELECT entry_id, participant_id FROM calendar_entry_participants''');

    _verifyEquivalent(
      db,
      'SELECT id, title, cadence, date FROM calendar_entries',
      'SELECT id, title, cadence, start_date FROM tasks',
    );
    _verifyEquivalent(
      db,
      'SELECT id, id, date, date, completed FROM calendar_entries',
      'SELECT id, task_id, scheduled_date, effective_date, completed FROM task_occurrences',
    );
    _verifyEquivalent(
      db,
      'SELECT entry_id, participant_id FROM calendar_entry_participants',
      'SELECT task_id, participant_id FROM task_participants',
    );
    if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Task migration foreign-key integrity check failed');
    }
    db.execute('DROP TABLE calendar_entry_participants');
    db.execute('DROP TABLE calendar_entries');
  }

  static void _verifyEquivalent(Database db, String before, String after) {
    final countBefore = db
        .select('SELECT count(*) AS total FROM ($before)')
        .single['total'];
    final countAfter = db
        .select('SELECT count(*) AS total FROM ($after)')
        .single['total'];
    if (countBefore != countAfter ||
        db.select('$before EXCEPT $after').isNotEmpty ||
        db.select('$after EXCEPT $before').isNotEmpty) {
      throw StateError('Task migration preservation check failed');
    }
  }

  static bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final date = DateTime.utc(year, month, day);
    return year >= 1 &&
        date.year == year &&
        date.month == month &&
        date.day == day;
  }
}
