import 'package:flutter/foundation.dart';

import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/use_cases/tracking_metrics.dart';
import 'package:app/domain/value_objects/local_date.dart';

class TrackingViewModel extends ChangeNotifier {
  TrackingViewModel(
    this.repository, {
    required this.newId,
    required this.clock,
  });
  final TrackingRepository repository;
  final String Function() newId;
  final DateTime Function() clock;
  TrackingDetail? detail;
  List<TaskType> types = [];
  List<({String id, String title})> finished = [];
  bool busy = false, _disposed = false;
  String? failure;
  List<TrackingMetric> get metrics =>
      detail == null ? [] : trackingMetrics(detail!.setup, detail!.logs);
  double? summaryFor(TrackingMetric metric, MetricSummary summary) =>
      metric.summarize(summary);
  TrackingProgress? get progress {
    final n = clock().toLocal();
    return detail == null
        ? null
        : trackingProgress(
            detail!.setup,
            detail!.logs,
            LocalDate(n.year, n.month, n.day),
          );
  }

  double timerSeconds() => detail?.timer?.elapsed(clock()) ?? 0;
  Future<bool> run(Future<void> Function() work) async {
    if (busy || _disposed) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      await work();
      if (_disposed) return true;
      busy = false;
      notifyListeners();
      return true;
    } on TrackingFailure catch (e) {
      failure = e.code;
    } catch (_) {
      failure = 'storageUnavailable';
    }
    if (_disposed) return false;
    busy = false;
    notifyListeners();
    return false;
  }

  Future<void> loadTypes() async {
    await run(() async {
      types = await repository.loadTypes();
    });
  }

  Future<void> load(String id) async {
    await run(() async {
      detail = await repository.loadDetail(id);
    });
  }

  Future<void> loadFinished() async {
    await run(() async {
      finished = await repository.loadFinished();
    });
  }

  Future<void> visibility(TaskType t) async {
    await run(() async {
      await repository.setVisibility(t.id, !t.hidden, t.revision);
      types = await repository.loadTypes();
    });
  }

  Future<void> dismiss(TaskType t) async {
    await run(() async {
      await repository.dismissNotice(t.id, t.revision);
      types = await repository.loadTypes();
    });
  }

  Future<void> saveType(TaskType type, int? expected) async {
    await repository.saveType(type, expected: expected);
  }

  Future<void> saveLog(
    ActivityLog log, {
    int? expected,
    int? timerRevision,
  }) async {
    await repository.saveLog(
      log,
      taskRevision: detail!.revision,
      expected: expected,
      timerRevision: timerRevision,
      now: clock(),
    );
  }

  Future<void> deleteLog(ActivityLog log) async {
    await run(() async {
      await repository.deleteLog(log, detail!.revision);
      detail = await repository.loadDetail(log.taskId);
    });
  }

  Future<void> lifecycle() async {
    await run(() async {
      final d = detail!, n = clock().toLocal();
      await repository.lifecycle(
        d.id,
        d.revision,
        !d.setup.finished,
        LocalDate(n.year, n.month, n.day).toString(),
      );
      detail = await repository.loadDetail(d.id);
    });
  }

  Future<void> startTimer(String fieldId) async {
    await run(() async {
      await repository.saveTimer(
        TrackingTimer(
          taskId: detail!.id,
          fieldId: fieldId,
          startedAt: clock().toUtc(),
        ),
      );
      detail = await repository.loadDetail(detail!.id);
    });
  }

  Future<void> stopTimer() async {
    await run(() async {
      final t = detail!.timer!;
      await repository.saveTimer(
        TrackingTimer(
          taskId: t.taskId,
          fieldId: t.fieldId,
          startedAt: t.startedAt,
          stoppedSeconds: t.elapsed(clock()),
        ),
        expected: t.revision,
      );
      detail = await repository.loadDetail(detail!.id);
    });
  }

  Future<void> discardTimer() async {
    await run(() async {
      await repository.clearTimer(detail!.timer!.revision);
      detail = await repository.loadDetail(detail!.id);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class TypeEditorModel extends ChangeNotifier {
  TypeEditorModel({required this.newId, this.original})
    : id = original?.id ?? newId(),
      name = original?.name ?? '',
      group = original?.group ?? '',
      icon = original?.icon ?? 'task',
      fields = [...?original?.fields];
  final String Function() newId;
  final TaskType? original;
  final String id;
  String name, group, icon;
  List<TrackingField> fields;
  bool busy = false, dirty = false, _disposed = false;
  String? failure;
  void change({String? name, String? group, String? icon}) {
    if (busy) return;
    this.name = name ?? this.name;
    this.group = group ?? this.group;
    this.icon = icon ?? this.icon;
    dirty = true;
    failure = null;
    notifyListeners();
  }

  void setField(TrackingField field, int? index) {
    if (busy) return;
    if (index == null) {
      fields = [...fields, field];
    } else {
      fields = [...fields]..[index] = field;
    }
    dirty = true;
    notifyListeners();
  }

  void remove(int index) {
    if (busy) return;
    fields = [...fields]..removeAt(index);
    dirty = true;
    notifyListeners();
  }

  void move(int from, int to) {
    if (busy || to < 0 || to >= fields.length) return;
    final next = [...fields], field = fields[from];
    next.removeAt(from);
    next.insert(to, field);
    fields = next;
    dirty = true;
    notifyListeners();
  }

  Future<bool> save(Future<void> Function(TaskType, int?) save) async {
    if (busy) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final type = TaskType(
        id: id,
        name: name,
        icon: icon,
        group: group,
        fields: fields,
        revision: original?.revision ?? 0,
      );
      await save(type, original?.revision);
      if (_disposed) return true;
      busy = false;
      dirty = false;
      notifyListeners();
      return true;
    } on ArgumentError {
      failure = 'validation';
    } on TrackingFailure catch (e) {
      failure = e.code;
    } catch (_) {
      failure = 'storageUnavailable';
    }
    if (_disposed) return false;
    busy = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
