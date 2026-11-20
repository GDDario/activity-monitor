import 'dart:math' as math;

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/value_objects/local_date.dart';

class MetricPoint {
  const MetricPoint(this.at, this.value);
  final DateTime at;
  final double value;
}

class TrackingMetric {
  TrackingMetric({
    required this.id,
    required this.label,
    required this.unit,
    required this.summary,
    required List<MetricPoint> points,
    this.additive = true,
    this.builtin = false,
    this.whole = false,
    this.target,
  }) : points = List.unmodifiable(points);
  final String id, label, unit;
  final MetricSummary summary;
  final List<MetricPoint> points;
  final bool additive, whole, builtin;
  final double? target;
  double? summarize(MetricSummary mode) {
    if (points.isEmpty) return null;
    return switch (mode) {
      MetricSummary.latest => points.last.value,
      MetricSummary.highest => points.map((p) => p.value).reduce(math.max),
      MetricSummary.total => points.fold(0.0, (sum, p) => sum! + p.value),
      MetricSummary.average =>
        points.fold(0.0, (sum, p) => sum + p.value) / points.length,
    };
  }
}

List<ActivityLog> orderedTrackingLogs(List<ActivityLog> logs) =>
    [...logs]..sort((a, b) {
      final d = a.recordedAt.compareTo(b.recordedAt);
      return d == 0 ? a.id.compareTo(b.id) : d;
    });

Map<String, String> validateTrackingHistory(
  TrackingSetup setup,
  List<ActivityLog> logs,
) {
  final errors = <String, String>{
    ...setup.type.validateValues(setup.values, FieldScope.setup),
  };
  final historical = <String, TrackingSetup>{
    for (final item in [...setup.history, setup]) item.type.id: item,
  };
  for (final snapshot in historical.values) {
    if (snapshot.type.icon == 'book' && snapshot.type.builtin) {
      final total = snapshot.values['totalPages'];
      final baseline = snapshot.values['startingPage'];
      num page = baseline is num && baseline.isFinite ? baseline : 0;
      if (total is num && (total <= 0 || page > total)) {
        errors['totalPages'] = 'invalid';
      }
      for (final log in orderedTrackingLogs(
        logs,
      ).where((l) => l.type.id == snapshot.type.id)) {
        final next = log.values['currentPage'];
        if (next is num) {
          if (next < page || total is num && next > total) {
            errors['currentPage'] = 'invalidSequence';
          }
          page = next;
        }
      }
    }
    final total = snapshot.values['totalUnits'];
    if (total is num) {
      for (final metric in trackingMetrics(
        snapshot,
        logs.where((l) => l.type.id == snapshot.type.id).toList(),
      ).where((m) => m.id == 'episodes' || m.id == 'units')) {
        if ((metric.summarize(MetricSummary.total) ?? 0) > total) {
          errors['totalUnits'] = 'invalid';
        }
      }
    }
  }
  return errors;
}

List<TrackingMetric> trackingMetrics(
  TrackingSetup setup,
  List<ActivityLog> logs,
) {
  final ordered = orderedTrackingLogs(logs);
  final definitions = <String, TrackingField>{};
  final points = <String, List<MetricPoint>>{};
  final labels = <String, String>{};
  final builtins = <String, bool>{};
  var currentBuiltin = false;
  final units = <String, String>{};
  final seenUnits = <String, Set<String>>{};
  final pageByType = <String, num>{};
  final setups = [...setup.history, setup];
  for (final s in setups) {
    final baseline = s.values['startingPage'];
    pageByType[s.type.id] = baseline is num && baseline.isFinite ? baseline : 0;
  }
  void add(
    TrackingField f,
    DateTime at,
    num value, {
    String? suffix,
    String? label,
    String? unit,
  }) {
    // Field identities are never reused for incompatible kinds/units.
    final id = suffix == null ? f.id : '${f.id}:$suffix';
    definitions[id] = f;
    builtins[id] = currentBuiltin;
    labels[id] = label ?? f.label;
    units[id] = unit ?? f.unit;
    (points[id] ??= []).add(MetricPoint(at, value.toDouble()));
  }

  for (final f in setup.type.fields.where(
    (f) =>
        f.numeric && f.scope == FieldScope.log ||
        f.kind == FieldKind.episodes && f.scope == FieldScope.log,
  )) {
    definitions[f.id] = f;
    builtins[f.id] = setup.type.builtin;
  }
  for (final log in ordered) {
    currentBuiltin = log.type.builtin;
    for (final f in log.type.fields.where((f) => f.scope == FieldScope.log)) {
      final v = log.values[f.id];
      if (f.numeric && v is num) {
        if (log.type.builtin &&
            log.type.icon == 'book' &&
            f.id == 'currentPage') {
          final before = pageByType[log.type.id] ?? 0;
          add(
            f,
            log.recordedAt,
            math.max(0, v - before),
            label: 'Pages read',
            unit: 'pages',
          );
          pageByType[log.type.id] = v;
        } else {
          add(f, log.recordedAt, v);
        }
      } else if (f.kind == FieldKind.episodes && v is List) {
        final seen = seenUnits.putIfAbsent(f.id, () => {});
        var count = 0;
        for (final item in v.cast<Map>()) {
          if (seen.add('${item['season'] ?? 1}:${item['episode']}')) count++;
        }
        add(f, log.recordedAt, count);
      } else if (f.kind == FieldKind.exercises && v is List) {
        for (final item in v.cast<Map>()) {
          final name = (item['exercise'] as String).trim();
          add(
            f,
            log.recordedAt,
            item['reps'] as num,
            suffix: '$name:reps',
            label: '$name · repetitions',
          );
          if (item['weight'] is num) {
            add(
              f,
              log.recordedAt,
              item['weight'] as num,
              suffix: '$name:${item['unit'] ?? 'kg'}:weight',
              label: '$name · weight',
              unit: item['unit'] as String? ?? 'kg',
            );
          }
        }
      } else if (f.kind == FieldKind.checklist && v is List) {
        add(
          f,
          log.recordedAt,
          v.cast<Map>().where((m) => m['done'] == true).length,
        );
      }
    }
  }
  return [
    for (final e in definitions.entries)
      TrackingMetric(
        id: e.key,
        builtin: builtins[e.key] ?? false,
        label: labels[e.key] ?? e.value.label,
        unit: units[e.key] ?? e.value.unit,
        summary: e.key.endsWith(':weight')
            ? MetricSummary.highest
            : e.value.summary,
        points: points[e.key] ?? [],
        additive:
            e.value.summary == MetricSummary.total &&
            !e.key.endsWith(':weight'),
        whole:
            e.value.whole ||
            e.value.kind == FieldKind.episodes ||
            e.value.kind == FieldKind.checklist,
        target: e.value.target,
      ),
  ];
}

double? suggestedDailyPace({
  required double remaining,
  required LocalDate today,
  required LocalDate target,
  bool wholeUnits = false,
}) {
  final days =
      DateTime.utc(
        target.year,
        target.month,
        target.day,
      ).difference(DateTime.utc(today.year, today.month, today.day)).inDays +
      1;
  if (days <= 0) return null;
  final pace = math.max(0, remaining) / days;
  return wholeUnits ? pace.ceilToDouble() : pace;
}

class TrackingProgress {
  const TrackingProgress({
    required this.done,
    required this.total,
    required this.remaining,
    this.pace,
    required this.whole,
    required this.overdue,
  });
  final double done, total, remaining;
  final double? pace;
  final bool whole, overdue;
  double get fraction => (done / total).clamp(0, 1);
}

TrackingProgress? trackingProgress(
  TrackingSetup setup,
  List<ActivityLog> logs,
  LocalDate today,
) {
  final builtin = setup.type.builtin;
  final id =
      setup.mainMetric ??
      (builtin && setup.type.icon == 'book'
          ? 'currentPage'
          : builtin && setup.type.icon == 'tv'
          ? 'episodes'
          : builtin && setup.type.icon == 'comic'
          ? 'units'
          : null);
  if (id == null) return null;
  final metric = trackingMetrics(
    setup,
    logs,
  ).where((m) => m.id == id).firstOrNull;
  if (metric == null) return null;
  final total =
      setup.target ??
      metric.target ??
      (id == 'currentPage'
          ? (setup.values['totalPages'] as num?)?.toDouble()
          : id == 'episodes' || id == 'units'
          ? (setup.values['totalUnits'] as num?)?.toDouble()
          : null);
  if (total == null || total <= 0) return null;
  final done =
      (metric.summarize(metric.summary) ?? 0) +
      (id == 'currentPage' && builtin
          ? (setup.values['startingPage'] as num? ?? 0)
          : 0);
  final remaining = math.max(0.0, total - done);
  final target = setup.finishDate;
  return TrackingProgress(
    done: done,
    total: total,
    remaining: remaining,
    whole: metric.whole,
    overdue: target != null && target.compareTo(today) < 0,
    pace: target == null || !metric.additive
        ? null
        : suggestedDailyPace(
            remaining: remaining,
            today: today,
            target: target,
            wholeUnits: metric.whole,
          ),
  );
}
