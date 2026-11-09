import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/task_database_operations.dart';

/// Isolate requests contain only a path and serializable persistence values.
class TaskDatabase {
  const TaskDatabase({required this.path});
  final String path;
  Future<List<Map<String, Object?>>> loadVisible({
    String? from,
    String? through,
  }) async => _rows(
    await request({'operation': 'range', 'from': from, 'through': through}),
  );
  Future<Map<String, Object?>> request(Map<String, Object?> request) =>
      compute(_taskDatabaseWorker, {'path': path, ...request});
  List<Map<String, Object?>> _rows(Map<String, Object?> result) {
    if (result['failure'] != null) throw const TaskStorageException();
    return (result['rows'] as List)
        .map((r) => Map<String, Object?>.from(r as Map))
        .toList();
  }
}

class TaskStorageException implements Exception {
  const TaskStorageException();
}

Map<String, Object?> _taskDatabaseWorker(Map<String, Object?> request) {
  Database? db;
  try {
    db = sqlite3.open(request['path'] as String, mode: OpenMode.readWrite);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA busy_timeout = 5000');
    final op = request['operation'];
    if (op == 'save') return commitTaskSave(db, request);
    if (op == 'ensure') return insertTaskOccurrences(db, request);
    if (op == 'change' || op == 'restore') {
      return commitTaskOccurrence(db, request, restore: op == 'restore');
    }
    final rows = switch (op) {
      'range' => readTaskAggregates(
        db,
        from: request['from'] as String?,
        through: request['through'] as String?,
      ),
      'aggregate' => readTaskAggregates(
        db,
        taskId: request['taskId'] as String?,
        occurrenceId: request['occurrenceId'] as String?,
        includeDeleted: true,
      ),
      'schedules' => readTaskSchedules(
        db,
        request['from'] as String,
        request['through'] as String,
      ),
      'future' => readFutureTaskOccurrences(
        db,
        request['taskId'] as String,
        request['after'] as String,
      ),
      'streaks' => readTaskStreakHistory(
        db,
        (request['taskIds'] as List).cast<String>(),
        request['through'] as String,
      ),
      _ => throw const TaskStorageException(),
    };
    return {'rows': rows};
  } on TaskDatabaseConflict catch (failure) {
    return {'failure': failure.code};
  } catch (_) {
    return {'failure': 'storageUnavailable'};
  } finally {
    db?.close();
  }
}
