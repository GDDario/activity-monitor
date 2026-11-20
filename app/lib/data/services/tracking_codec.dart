import 'dart:convert';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/value_objects/local_date.dart';

Map<String, Object?> trackingMap(Object? v) =>
    Map<String, Object?>.from(v as Map);
Map<String, Object?> encodeTrackingField(TrackingField f) => {
  'id': f.id,
  'label': f.label,
  'kind': f.kind.name,
  'scope': f.scope.name,
  'required': f.required,
  'unit': f.unit,
  'summary': f.summary.name,
  'target': f.target,
  'choices': f.choices,
  'template': f.template,
  'sourceId': f.sourceId,
  'whole': f.whole,
  'minimum': f.minimum,
};
TrackingField decodeTrackingField(Object? value) {
  final m = trackingMap(value);
  return TrackingField(
    id: m['id'] as String,
    label: m['label'] as String,
    kind: FieldKind.values.byName(m['kind'] as String),
    scope: FieldScope.values.byName(m['scope'] as String),
    required: m['required'] == true,
    unit: m['unit'] as String? ?? '',
    summary: MetricSummary.values.byName(m['summary'] as String? ?? 'total'),
    target: (m['target'] as num?)?.toDouble(),
    choices: (m['choices'] as List? ?? []).cast<String>(),
    template: (m['template'] as List? ?? []),
    sourceId: m['sourceId'] as String?,
    whole: m['whole'] == true,
    minimum: (m['minimum'] as num?)?.toDouble(),
  );
}

Map<String, Object?> encodeTaskType(TaskType t) => {
  'id': t.id,
  'name': t.name,
  'icon': t.icon,
  'group': t.group,
  'builtin': t.builtin,
  'revision': t.revision,
  'hidden': t.hidden,
  'notice': t.notice,
  'fields': t.fields.map(encodeTrackingField).toList(),
};
TaskType decodeTaskType(Object? value) {
  final m = trackingMap(value);
  return TaskType(
    id: m['id'] as String,
    name: m['name'] as String,
    icon: m['icon'] as String,
    group: m['group'] as String?,
    builtin: m['builtin'] == true,
    revision: m['revision'] as int? ?? 0,
    hidden: m['hidden'] == true,
    notice: m['notice'] == true,
    fields: (m['fields'] as List? ?? []).map(decodeTrackingField).toList(),
  );
}

Map<String, Object?> encodeTrackingSetup(TrackingSetup s) => {
  'type': encodeTaskType(s.type),
  'values': s.values,
  'mainMetric': s.mainMetric,
  'target': s.target,
  'finishDate': s.finishDate?.toString(),
  'closures': [
    for (final c in s.closures)
      {'from': c.from.toString(), 'until': c.until?.toString()},
  ],
  'history': s.history.map(encodeTrackingSetup).toList(),
};
TrackingSetup decodeTrackingSetup(Object? value) {
  if (value == null || value == '{}') return TrackingSetup();
  final m = trackingMap(value is String ? jsonDecode(value) : value);
  if (m.isEmpty) return TrackingSetup();
  return TrackingSetup(
    type: decodeTaskType(m['type']),
    values: trackingMap(m['values']),
    mainMetric: m['mainMetric'] as String?,
    target: (m['target'] as num?)?.toDouble(),
    finishDate: m['finishDate'] == null
        ? null
        : LocalDate.parse(m['finishDate'] as String),
    closures: [
      for (final v in m['closures'] as List? ?? [])
        TrackingClosure(
          LocalDate.parse(v['from'] as String),
          v['until'] == null ? null : LocalDate.parse(v['until'] as String),
        ),
    ],
    history: (m['history'] as List? ?? []).map(decodeTrackingSetup).toList(),
  );
}

Map<String, Object?> encodeActivityLog(ActivityLog l) => {
  'id': l.id,
  'taskId': l.taskId,
  'occurrenceId': l.occurrenceId,
  'recordedAt': l.recordedAt.toIso8601String(),
  'type': encodeTaskType(l.type),
  'values': l.values,
  'revision': l.revision,
};
ActivityLog decodeActivityLog(Object? value) {
  final m = trackingMap(value);
  return ActivityLog(
    id: m['id'] as String,
    taskId: m['taskId'] as String,
    occurrenceId: m['occurrenceId'] as String?,
    recordedAt: DateTime.parse(m['recordedAt'] as String),
    type: decodeTaskType(m['type']),
    values: trackingMap(m['values']),
    revision: m['revision'] as int? ?? 0,
  );
}

Map<String, Object?> encodeTrackingTimer(TrackingTimer t) => {
  'taskId': t.taskId,
  'fieldId': t.fieldId,
  'startedAt': t.startedAt.toUtc().toIso8601String(),
  'stoppedSeconds': t.stoppedSeconds,
  'revision': t.revision,
};
TrackingTimer decodeTrackingTimer(Object? value) {
  final m = trackingMap(value);
  return TrackingTimer(
    taskId: m['taskId'] as String,
    fieldId: m['fieldId'] as String,
    startedAt: DateTime.parse(m['startedAt'] as String),
    stoppedSeconds: (m['stoppedSeconds'] as num?)?.toDouble(),
    revision: m['revision'] as int? ?? 0,
  );
}
