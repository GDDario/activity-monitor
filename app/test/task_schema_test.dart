import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';

import 'helpers/task_migration_fixture.dart';

void main() {
  late Database db;
  setUp(() {
    db = sqlite3.openInMemory();
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
      ],
    );
    db.execute('DELETE FROM tasks');
    db.execute('DELETE FROM calendar_participants');
  });
  tearDown(() => db.close());

  void insert(String table, Map<String, Object?> values) => db.execute(
    'INSERT INTO $table (${values.keys.join(', ')}) VALUES (${List.filled(values.length, '?').join(', ')})',
    values.values.toList(),
  );
  Map<String, Object?> task([String id = 'task']) => {
    'id': id,
    'title': 'Task',
    'start_date': '2026-11-07',
  };
  Map<String, Object?> occurrence([
    String id = 'occurrence',
    String owner = 'task',
  ]) => {
    'id': id,
    'task_id': owner,
    'scheduled_date': '2026-11-07',
    'effective_date': '2026-11-07',
  };
  final rejected = throwsA(isA<SqliteException>());

  test('scalar limits accept supplementary characters and reject NUL', () {
    insert('tasks', {
      ...task(),
      'title': List.filled(200, '🧘').join(),
      'notes': List.filled(10000, '🧘').join(),
    });
    for (final value in [
      '',
      ' \t\n\u00a0\u2003 ',
      List.filled(201, '🧘').join(),
      'a\u0000b',
    ]) {
      expect(() => insert('tasks', {...task('bad'), 'title': value}), rejected);
    }
    expect(
      () => insert('tasks', {
        ...task('bad'),
        'notes': List.filled(10001, '🧘').join(),
      }),
      rejected,
    );
    expect(
      () => insert('tasks', {...task('bad'), 'notes': 'a\u0000b'}),
      rejected,
    );
  });

  for (final invalid in <Map<String, Object?>>[
    {'priority': 'urgent'},
    {'cadence': 'custom'},
    {'recurrence_enabled': 2},
    {'cadence': 'one-time', 'recurrence_enabled': 1},
    {'revision': -1},
    {'streak_enabled': 2},
    {'streak_enabled': 1},
    {'day_period': 'night'},
    {'day_period': 'morning'},
    {'cadence': 'weekly', 'day_period': 'morning'},
    {'start_date': '2026-11-07\u0000extra'},
    {'start_date': '2026/11/07'},
    {'start_date': '2026-1a-07'},
    {'rule_effective_date': '2026-11-0a'},
    {'start_minute': 60},
    {'end_minute': 120},
    {'start_minute': -1, 'end_minute': 120},
    {'start_minute': 60, 'end_minute': 60},
    {'start_minute': 60, 'end_minute': 1440},
    {'reminder_minutes_before': 5},
    {'start_minute': 60, 'end_minute': 120, 'reminder_minutes_before': 10},
  ]) {
    test('task rejects invalid relational values $invalid', () {
      expect(() => insert('tasks', {...task(), ...invalid}), rejected);
    });
  }

  test('task allows valid daily schedule and weekly weekday bounds', () {
    insert('tasks', {
      ...task(),
      'cadence': 'daily',
      'recurrence_enabled': 1,
      'streak_enabled': 1,
      'day_period': 'morning',
      'start_minute': 60,
      'end_minute': 120,
      'reminder_minutes_before': 60,
    });
    insert('tasks', {
      ...task('weekly'),
      'cadence': 'weekly',
      'recurrence_enabled': 1,
    });
    insert('task_weekdays', {'task_id': 'weekly', 'weekday': 1});
    insert('task_weekdays', {'task_id': 'weekly', 'weekday': 7});
    for (final day in [0, 8, 1]) {
      expect(
        () => insert('task_weekdays', {'task_id': 'weekly', 'weekday': day}),
        rejected,
      );
    }
  });

  for (final invalid in <Map<String, Object?>>[
    {'scheduled_date': '2026-11-07\u0000extra'},
    {'scheduled_date': 'bad'},
    {'effective_date': '2026-xx-07'},
    {'revision': -1},
    {'completed': 2},
    {'is_schedule_exception': 2},
    {'completed_at_utc': '2026-11-07T12:00:00Z'},
    {'start_minute': 60},
    {'end_minute': 120},
    {'start_minute': 120, 'end_minute': 60},
    {'start_minute': 60, 'end_minute': 1440},
    {'reminder_minutes_before': 0},
    {'start_minute': 60, 'end_minute': 120, 'reminder_minutes_before': 7},
  ]) {
    test('occurrence rejects invalid relational values $invalid', () {
      insert('tasks', task());
      expect(
        () => insert('task_occurrences', {...occurrence(), ...invalid}),
        rejected,
      );
    });
  }

  test(
    'tombstones reserve original dates while moved-in slots remain distinct',
    () {
      insert('tasks', task());
      insert('task_occurrences', {
        ...occurrence(),
        'deleted_at_utc': '2026-11-07T12:00:00Z',
      });
      expect(
        () => insert('task_occurrences', occurrence('duplicate')),
        rejected,
      );
      insert('task_occurrences', {
        ...occurrence('moved'),
        'scheduled_date': '2026-11-06',
      });
      insert('task_occurrences', {
        ...occurrence('done'),
        'scheduled_date': '2026-11-05',
        'completed': 1,
      });
    },
  );

  test(
    'checklist ownership cannot cross tasks and active positions are unique',
    () {
      insert('tasks', task());
      insert('tasks', task('other'));
      insert('task_occurrences', occurrence());
      insert('task_occurrences', occurrence('other-occurrence', 'other'));
      insert('task_subtasks', {
        'id': 'subtask',
        'task_id': 'task',
        'title': 'Child',
        'position': 0,
      });
      insert('task_subtasks', {
        'id': 'other-subtask',
        'task_id': 'other',
        'title': 'Other',
        'position': 0,
      });
      expect(
        () => insert('task_subtasks', {
          'id': 'duplicate',
          'task_id': 'task',
          'title': 'Child',
          'position': 0,
        }),
        rejected,
      );
      insert('task_subtasks', {
        'id': 'inactive',
        'task_id': 'task',
        'title': 'Retained',
        'position': 0,
        'active': 0,
      });
      expect(
        () => db.execute(
          "UPDATE task_subtasks SET active = 1 WHERE id = 'inactive'",
        ),
        rejected,
      );
      insert('task_occurrence_subtasks', {
        'task_id': 'task',
        'occurrence_id': 'occurrence',
        'subtask_id': 'subtask',
      });
      expect(
        () => insert('task_occurrence_subtasks', {
          'task_id': 'task',
          'occurrence_id': 'occurrence',
          'subtask_id': 'other-subtask',
        }),
        rejected,
      );
      expect(
        () => insert('task_occurrence_subtasks', {
          'task_id': 'task',
          'occurrence_id': 'other-occurrence',
          'subtask_id': 'subtask',
        }),
        rejected,
      );
      expect(
        () => db.execute('UPDATE task_occurrence_subtasks SET completed = 2'),
        rejected,
      );
      for (final invalid in <Map<String, Object?>>[
        {'title': '\u2003'},
        {'title': 'a\u0000b'},
        {'title': List.filled(201, '🧘').join()},
        {'position': -1},
        {'active': 2},
      ]) {
        expect(
          () => insert('task_subtasks', {
            'id': 'bad',
            'task_id': 'task',
            'title': 'Child',
            'position': 1,
            ...invalid,
          }),
          rejected,
        );
      }
    },
  );

  test(
    'normalized tags are unique and task cleanup keeps shared tags and people',
    () {
      insert('tasks', task());
      insert('tasks', task('other'));
      insert('tags', {'id': 'tag', 'name': 'Café', 'normalized_name': 'café'});
      insert('tags', {
        'id': 'accent-distinct',
        'name': 'Cafe',
        'normalized_name': 'cafe',
      });
      expect(
        () => insert('tags', {
          'id': 'same',
          'name': 'CAFÉ',
          'normalized_name': 'café',
        }),
        rejected,
      );
      for (final invalid in <Map<String, Object?>>[
        {'name': ''},
        {'name': List.filled(33, '🧘').join()},
        {'normalized_name': '\u2003'},
        {'normalized_name': ' café '},
        {'normalized_name': 'a\u0000b'},
      ]) {
        expect(
          () => insert('tags', {
            'id': 'bad',
            'name': 'Valid',
            'normalized_name': 'valid',
            ...invalid,
          }),
          rejected,
        );
      }
      insert('calendar_participants', {'id': 'person', 'name': 'Alex'});
      for (final owner in ['task', 'other']) {
        insert('task_tags', {'task_id': owner, 'tag_id': 'tag'});
        insert('task_participants', {
          'task_id': owner,
          'participant_id': 'person',
        });
      }
      insert('task_occurrences', occurrence());
      insert('task_subtasks', {
        'id': 'child',
        'task_id': 'task',
        'title': 'Child',
        'position': 0,
      });
      insert('task_occurrence_subtasks', {
        'task_id': 'task',
        'occurrence_id': 'occurrence',
        'subtask_id': 'child',
      });
      db.execute("DELETE FROM tasks WHERE id = 'task'");
      expect(db.select('SELECT * FROM task_occurrences'), isEmpty);
      expect(db.select('SELECT * FROM task_subtasks'), isEmpty);
      expect(db.select('SELECT * FROM task_occurrence_subtasks'), isEmpty);
      expect(db.select('SELECT * FROM task_tags').single['task_id'], 'other');
      expect(
        db.select('SELECT * FROM task_participants').single['task_id'],
        'other',
      );
      expect(db.select("SELECT * FROM tags WHERE id = 'tag'"), hasLength(1));
      expect(
        db.select("SELECT * FROM calendar_participants WHERE id = 'person'"),
        hasLength(1),
      );
    },
  );

  Map<String, Object?> history() => {
    'task_id': 'task',
    'effective_from': '2026-11-01',
    'effective_until': '2026-11-07',
    'start_date': '2026-11-01',
    'cadence': 'weekly',
    'recurrence_enabled': 1,
    'weekday_mask': 65,
  };
  test(
    'history retains half-open schedule snapshots and cascades with owner',
    () {
      insert('tasks', task());
      insert('task_schedule_history', history());
      expect(() => insert('task_schedule_history', history()), rejected);
      db.execute("DELETE FROM tasks WHERE id = 'task'");
      expect(db.select('SELECT * FROM task_schedule_history'), isEmpty);
    },
  );
  for (final invalid in <Map<String, Object?>>[
    {'effective_from': '2026-11-01\u0000extra'},
    {'effective_from': 'bad'},
    {'effective_until': '2026-11-01'},
    {'effective_until': '2026-10-01'},
    {'start_date': 'bad'},
    {'cadence': 'custom'},
    {'recurrence_enabled': 2},
    {'weekday_mask': -1},
    {'weekday_mask': 128},
    {'weekday_mask': 0},
    {'cadence': 'daily'},
    {'recurrence_enabled': 0},
    {'start_minute': 60},
    {'end_minute': 120},
    {'reminder_minutes_before': 5},
    {'start_minute': 60, 'end_minute': 120, 'reminder_minutes_before': 3},
  ]) {
    test('history rejects invalid snapshots $invalid', () {
      insert('tasks', task());
      expect(
        () => insert('task_schedule_history', {...history(), ...invalid}),
        rejected,
      );
    });
  }
  test('range and child indexes have the specified query columns', () {
    List<String> columns(String index) => db
        .select('PRAGMA index_info($index)')
        .map((row) => row['name'] as String)
        .toList();
    expect(columns('task_occurrences_visible'), [
      'effective_date',
      'completed',
      'id',
    ]);
    expect(
      db
          .select(
            "SELECT sql FROM sqlite_master WHERE name = 'task_occurrences_visible'",
          )
          .single['sql'],
      contains('WHERE deleted_at_utc IS NULL'),
    );
    expect(columns('task_participants_participant'), [
      'participant_id',
      'task_id',
    ]);
    expect(columns('task_tags_tag'), ['tag_id', 'task_id']);
    expect(columns('task_occurrence_subtasks_subtask'), [
      'task_id',
      'subtask_id',
    ]);
  });
}
