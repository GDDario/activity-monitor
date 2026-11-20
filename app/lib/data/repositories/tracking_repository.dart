import 'dart:async';

import 'package:app/data/services/tracking_codec.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/domain/models/task_tracking.dart';

class TrackingFailure implements Exception {
  const TrackingFailure(this.code, [this.fields = const {}]);
  final String code;
  final Map<String, String> fields;
}

class TrackingDetail {
  const TrackingDetail({
    required this.id,
    required this.title,
    required this.revision,
    required this.setup,
    required this.logs,
    this.timer,
  });
  final String id, title;
  final int revision;
  final TrackingSetup setup;
  final List<ActivityLog> logs;
  final TrackingTimer? timer;
}

class TrackingRepository {
  TrackingRepository(this.database);
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;
  Future<void> dispose() => _changes.close();
  final TrackingDatabase database;
  Future<Map<String, Object?>> _request(
    String op, [
    Map<String, Object?> data = const {},
  ]) async {
    final result = await database.request({'operation': op, ...data});
    if (result['failure'] case final String code) {
      throw TrackingFailure(
        code,
        result['fields'] == null
            ? const {}
            : Map<String, String>.from(result['fields'] as Map),
      );
    }
    if (!['types', 'detail', 'finished'].contains(op) && !_changes.isClosed) {
      _changes.add(data['taskId'] as String? ?? '');
    }
    return result;
  }

  Future<List<TaskType>> loadTypes() async =>
      ((await _request('types'))['types'] as List).map(decodeTaskType).toList();
  Future<void> saveType(TaskType type, {int? expected}) async {
    await _request('saveType', {
      'type': encodeTaskType(type),
      'expected': expected,
    });
  }

  Future<void> setVisibility(String id, bool hidden, int expected) async {
    await _request('visibility', {
      'id': id,
      'hidden': hidden,
      'expected': expected,
    });
  }

  Future<void> dismissNotice(String id, int expected) async {
    await _request('notice', {'id': id, 'expected': expected});
  }

  Future<TrackingDetail> loadDetail(String id) async {
    final r = await _request('detail', {'taskId': id});
    return TrackingDetail(
      id: id,
      title: r['title'] as String,
      revision: r['revision'] as int,
      setup: decodeTrackingSetup(r['setup']),
      logs: (r['logs'] as List).map(decodeActivityLog).toList(),
      timer: r['timer'] == null ? null : decodeTrackingTimer(r['timer']),
    );
  }

  Future<List<({String id, String title})>> loadFinished() async => [
    for (final row in (await _request('finished'))['tasks'] as List)
      (id: row['id'] as String, title: row['title'] as String),
  ];
  Future<void> saveLog(
    ActivityLog log, {
    required int taskRevision,
    int? expected,
    int? timerRevision,
    required DateTime now,
  }) async {
    await _request('saveLog', {
      'log': encodeActivityLog(log),
      'taskRevision': taskRevision,
      'expected': expected,
      'timerRevision': timerRevision,
      'now': now.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteLog(ActivityLog log, int taskRevision) async {
    await _request('deleteLog', {
      'taskId': log.taskId,
      'id': log.id,
      'expected': log.revision,
      'taskRevision': taskRevision,
    });
  }

  Future<void> lifecycle(
    String taskId,
    int expected,
    bool finish,
    String today,
  ) async {
    await _request('lifecycle', {
      'taskId': taskId,
      'expected': expected,
      'finish': finish,
      'today': today,
    });
  }

  Future<void> saveTimer(TrackingTimer timer, {int? expected}) async {
    await _request('timer', {
      'timer': encodeTrackingTimer(timer),
      'expected': expected,
    });
  }

  Future<void> clearTimer(int expected) async {
    await _request('clearTimer', {'expected': expected});
  }
}
