import 'package:app/domain/value_objects/local_date.dart';

enum FieldKind {
  text,
  number,
  date,
  checkbox,
  choice,
  exercises,
  episodes,
  checklist,
  duration,
}

enum FieldScope { setup, log }

enum MetricSummary { total, latest, average, highest }

Object? freezeTrackingValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, freezeTrackingValue(v))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezeTrackingValue));
  }
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  throw ArgumentError('Unsupported field value');
}

Map<String, Object?> trackingValues(Map<String, Object?> values) =>
    freezeTrackingValue(values) as Map<String, Object?>;

class TrackingField {
  TrackingField({
    required this.id,
    required String label,
    required this.kind,
    required this.scope,
    this.required = false,
    this.unit = '',
    this.summary = MetricSummary.total,
    this.target,
    List<String> choices = const [],
    List<Object?> template = const [],
    this.sourceId,
    this.whole = false,
    this.minimum,
  }) : label = label.trim(),
       choices = List.unmodifiable(choices.map((v) => v.trim())),
       template = freezeTrackingValue(template) as List<Object?> {
    if (id.isEmpty ||
        this.label.isEmpty ||
        this.label.length > 64 ||
        unit.length > 32 ||
        target != null && (!target!.isFinite || target! <= 0) ||
        minimum != null && !minimum!.isFinite) {
      throw ArgumentError('Invalid field');
    }
    if (kind == FieldKind.choice &&
        (this.choices.isEmpty ||
            this.choices.length > 50 ||
            this.choices.any((c) => c.isEmpty || c.length > 100) ||
            this.choices.map((c) => c.toLowerCase()).toSet().length !=
                this.choices.length)) {
      throw ArgumentError('Invalid choices');
    }
    if (this.template.isNotEmpty && validate(this.template) != null) {
      throw ArgumentError('Invalid template');
    }
  }
  final String id, label, unit;
  final FieldKind kind;
  final FieldScope scope;
  final bool required, whole;
  final double? target, minimum;
  final MetricSummary summary;
  final List<String> choices;
  final List<Object?> template;
  final String? sourceId;
  bool get numeric => kind == FieldKind.number || kind == FieldKind.duration;
  String? validate(Object? value) {
    if (value == null ||
        value is String && value.trim().isEmpty ||
        value is List && value.isEmpty) {
      return required ? 'required' : null;
    }
    switch (kind) {
      case FieldKind.text:
        return value is String && value.length <= 10000 ? null : 'invalid';
      case FieldKind.number:
      case FieldKind.duration:
        return value is num &&
                value.isFinite &&
                (!whole || value == value.roundToDouble()) &&
                (minimum == null || value >= minimum!) &&
                (kind != FieldKind.duration || value >= 0)
            ? null
            : 'invalid';
      case FieldKind.date:
        if (value is! String) return 'invalid';
        try {
          LocalDate.parse(value);
          return null;
        } on ArgumentError {
          return 'invalid';
        } on FormatException {
          return 'invalid';
        }
      case FieldKind.checkbox:
        return value is bool ? null : 'invalid';
      case FieldKind.choice:
        return value is String && choices.contains(value) ? null : 'invalid';
      case FieldKind.exercises:
      case FieldKind.episodes:
      case FieldKind.checklist:
        if (value is! List || value.length > 500) return 'invalid';
        for (final item in value) {
          if (item is! Map) return 'invalid';
          switch (kind) {
            case FieldKind.exercises:
              if (!_name(item['exercise']) ||
                  !_positiveInteger(item['reps']) ||
                  item['weight'] != null && !_nonnegative(item['weight']) ||
                  item['unit'] != null &&
                      (item['unit'] is! String ||
                          (item['unit'] as String).length > 32)) {
                return 'invalid';
              }
            case FieldKind.episodes:
              if (!_positiveInteger(item['episode']) ||
                  item['season'] != null && !_positiveInteger(item['season'])) {
                return 'invalid';
              }
            case FieldKind.checklist:
              if (!_name(item['title']) || item['done'] is! bool) {
                return 'invalid';
              }
            default:
              break;
          }
        }
        return null;
    }
  }
}

bool _name(Object? v) => v is String && v.trim().isNotEmpty && v.length <= 200;
bool _nonnegative(Object? v) => v is num && v.isFinite && v >= 0;
bool _positiveInteger(Object? v) =>
    v is num && v.isFinite && v > 0 && v == v.roundToDouble();

const trackingIcons = [
  'task',
  'book',
  'comic',
  'fitness',
  'study',
  'work',
  'tv',
  'cleaning',
  'music',
  'walk',
  'craft',
];

class TaskType {
  TaskType({
    required this.id,
    required String name,
    required this.icon,
    String? group,
    this.builtin = false,
    this.revision = 0,
    this.hidden = false,
    this.notice = false,
    List<TrackingField> fields = const [],
  }) : name = name.trim(),
       group = group?.trim().isEmpty == true ? null : group?.trim(),
       fields = List.unmodifiable(fields) {
    if (id.isEmpty ||
        this.name.isEmpty ||
        this.name.length > 64 ||
        !trackingIcons.contains(icon) ||
        revision < 0 ||
        (this.group?.length ?? 0) > 64 ||
        fields.length > 30 ||
        fields.map((f) => f.id).toSet().length != fields.length ||
        fields.map((f) => f.label.toLowerCase()).toSet().length !=
            fields.length) {
      throw ArgumentError('Invalid task type');
    }
  }
  final String id, name, icon;
  final String? group;
  final bool builtin, hidden, notice;
  final int revision;
  final List<TrackingField> fields;
  Map<String, String> validateValues(
    Map<String, Object?> values,
    FieldScope scope,
  ) {
    final errors = <String, String>{};
    final allowed = fields.where((f) => f.scope == scope).toList();
    for (final f in allowed) {
      final error = f.validate(values[f.id]);
      if (error != null) errors[f.id] = error;
    }
    for (final key in values.keys) {
      if (!allowed.any((f) => f.id == key)) errors[key] = 'invalid';
    }
    return errors;
  }

  TaskType copyWith({
    String? name,
    String? icon,
    String? group,
    List<TrackingField>? fields,
    int? revision,
    bool? hidden,
    bool? notice,
  }) => TaskType(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    group: group ?? this.group,
    fields: fields ?? this.fields,
    builtin: builtin,
    revision: revision ?? this.revision,
    hidden: hidden ?? this.hidden,
    notice: notice ?? this.notice,
  );
}

class TrackingClosure {
  const TrackingClosure(this.from, this.until);
  final LocalDate from;
  final LocalDate? until;
  bool contains(LocalDate date) =>
      date.compareTo(from) >= 0 &&
      (until == null || date.compareTo(until!) < 0);
}

class TrackingSetup {
  TrackingSetup({
    TaskType? type,
    Map<String, Object?> values = const {},
    this.mainMetric,
    this.target,
    this.finishDate,
    List<TrackingClosure> closures = const [],
    List<TrackingSetup> history = const [],
  }) : type = type ?? generalTaskType(),
       values = trackingValues(values),
       closures = List.unmodifiable(closures),
       history = List.unmodifiable(history) {
    if (target != null && (!target!.isFinite || target! <= 0)) {
      throw ArgumentError('Invalid target');
    }
  }
  final TaskType type;
  final Map<String, Object?> values;
  final String? mainMetric;
  final double? target;
  final LocalDate? finishDate;
  final List<TrackingClosure> closures;
  final List<TrackingSetup> history;
  bool get finished => closures.any((c) => c.until == null);
  bool allowsDate(LocalDate date) => !closures.any((c) => c.contains(date));
  TrackingSetup copyWith({
    TaskType? type,
    Map<String, Object?>? values,
    String? mainMetric,
    double? target,
    LocalDate? finishDate,
    bool clearTarget = false,
    bool clearDate = false,
    List<TrackingClosure>? closures,
    List<TrackingSetup>? history,
  }) => TrackingSetup(
    type: type ?? this.type,
    values: values ?? this.values,
    mainMetric: clearTarget ? null : mainMetric ?? this.mainMetric,
    target: clearTarget ? null : target ?? this.target,
    finishDate: clearDate ? null : finishDate ?? this.finishDate,
    closures: closures ?? this.closures,
    history: history ?? this.history,
  );
  TrackingSetup refreshType(TaskType latest) {
    if (latest.id != type.id) return changeType(latest);
    if (latest.revision == type.revision) return this;
    final keepMain = latest.fields.any(
      (f) =>
          f.id == mainMetric &&
          f.scope == FieldScope.log &&
          (f.numeric ||
              f.kind == FieldKind.episodes ||
              f.kind == FieldKind.checklist),
    );
    return TrackingSetup(
      type: latest,
      values: {
        for (final f in latest.fields.where((f) => f.scope == FieldScope.setup))
          if (values.containsKey(f.id)) f.id: values[f.id],
      },
      mainMetric: keepMain ? mainMetric : null,
      target: keepMain ? target : null,
      finishDate: finishDate,
      closures: closures,
      history: [
        ...history,
        TrackingSetup(type: type, values: values),
      ],
    );
  }

  TrackingSetup changeType(TaskType next) => next.id == type.id
      ? copyWith(type: next)
      : TrackingSetup(
          type: next,
          closures: closures,
          history: [
            ...history,
            TrackingSetup(type: type, values: values),
          ],
        );
  TrackingSetup finish(LocalDate today) => finished
      ? this
      : copyWith(
          closures: [...closures, TrackingClosure(today.addDays(1), null)],
        );
  TrackingSetup reopen(LocalDate today) => copyWith(
    closures: [
      for (final c in closures)
        if (c.until != null)
          c
        else if (today.compareTo(c.from) > 0)
          TrackingClosure(c.from, today),
    ],
  );
}

class ActivityLog {
  ActivityLog({
    required this.id,
    required this.taskId,
    required DateTime recordedAt,
    required this.type,
    Map<String, Object?> values = const {},
    this.revision = 0,
    this.occurrenceId,
  }) : recordedAt = recordedAt.toUtc(),
       values = trackingValues(values) {
    if (id.isEmpty ||
        taskId.isEmpty ||
        revision < 0 ||
        type.validateValues(values, FieldScope.log).isNotEmpty) {
      throw ArgumentError('Invalid activity log');
    }
  }
  final String id, taskId;
  final String? occurrenceId;
  final DateTime recordedAt;
  final TaskType type;
  final Map<String, Object?> values;
  final int revision;
}

class TrackingTimer {
  TrackingTimer({
    required this.taskId,
    required this.fieldId,
    required DateTime startedAt,
    this.stoppedSeconds,
    this.revision = 0,
  }) : startedAt = startedAt.toUtc() {
    if (taskId.isEmpty ||
        fieldId.isEmpty ||
        revision < 0 ||
        stoppedSeconds != null &&
            (!stoppedSeconds!.isFinite || stoppedSeconds! < 0)) {
      throw ArgumentError('Invalid timer');
    }
  }
  final String taskId, fieldId;
  final DateTime startedAt;
  final double? stoppedSeconds;
  final int revision;
  double elapsed(DateTime now) =>
      stoppedSeconds ??
      (now.difference(startedAt).inMilliseconds / 1000).clamp(
        0,
        double.maxFinite,
      );
}

TaskType generalTaskType() => TaskType(
  id: '01900000-0000-7000-8000-000000000000',
  name: 'General',
  icon: 'task',
  builtin: true,
);
List<TaskType> builtinTaskTypes() {
  TrackingField number(
    String id,
    String label,
    FieldScope scope, {
    bool required = false,
  }) => TrackingField(
    id: id,
    label: label,
    kind: FieldKind.number,
    scope: scope,
    whole: true,
    minimum: 0,
    required: required,
  );
  final duration = TrackingField(
    id: 'duration',
    label: 'Duration',
    kind: FieldKind.duration,
    scope: FieldScope.log,
    unit: 'seconds',
  );
  final notes = TrackingField(
    id: 'sessionNotes',
    label: 'Session notes',
    kind: FieldKind.text,
    scope: FieldScope.log,
  );
  TaskType type(
    int n,
    String name,
    String icon,
    List<TrackingField> fields, {
    String? group,
  }) => TaskType(
    id: '01900000-0000-7000-8000-${n.toString().padLeft(12, '0')}',
    name: name,
    icon: icon,
    group: group,
    builtin: true,
    fields: fields,
  );
  List<TrackingField> workout() => [
    TrackingField(
      id: 'routine',
      label: 'Routine',
      kind: FieldKind.exercises,
      scope: FieldScope.setup,
    ),
    TrackingField(
      id: 'sets',
      label: 'Exercise sets',
      kind: FieldKind.exercises,
      scope: FieldScope.log,
      sourceId: 'routine',
    ),
    duration,
    notes,
  ];
  return [
    generalTaskType(),
    type(1, 'Book', 'book', [
      number('totalPages', 'Total pages', FieldScope.setup, required: true),
      number('startingPage', 'Starting page', FieldScope.setup),
      number('currentPage', 'Current page', FieldScope.log, required: true),
      number('rereadPages', 'Reread pages', FieldScope.log),
      duration,
      notes,
    ], group: 'Read'),
    type(2, 'Comic', 'comic', [
      TrackingField(
        id: 'comicUnit',
        label: 'Tracking unit',
        kind: FieldKind.choice,
        scope: FieldScope.setup,
        choices: ['Issues', 'Volumes'],
        required: true,
      ),
      number('totalUnits', 'Total units', FieldScope.setup),
      TrackingField(
        id: 'units',
        label: 'Completed units',
        kind: FieldKind.episodes,
        scope: FieldScope.log,
      ),
      duration,
      notes,
    ], group: 'Read'),
    type(3, 'Gym', 'fitness', workout(), group: 'Exercise'),
    type(4, 'Calisthenics', 'fitness', workout(), group: 'Exercise'),
    type(5, 'Study', 'study', [duration, notes]),
    type(6, 'Work', 'work', [duration, notes]),
    type(7, 'Watching series', 'tv', [
      number('totalUnits', 'Total episodes', FieldScope.setup),
      TrackingField(
        id: 'episodes',
        label: 'Watched episodes',
        kind: FieldKind.episodes,
        scope: FieldScope.log,
      ),
      duration,
      notes,
    ]),
    type(8, 'Cleaning', 'cleaning', [
      TrackingField(
        id: 'cleaningPlan',
        label: 'Cleaning items',
        kind: FieldKind.checklist,
        scope: FieldScope.setup,
      ),
      TrackingField(
        id: 'checklist',
        label: 'Completed items',
        kind: FieldKind.checklist,
        scope: FieldScope.log,
        sourceId: 'cleaningPlan',
      ),
      duration,
      notes,
    ]),
  ];
}

Map<String, Object?> initialLogValues(TrackingSetup setup) => {
  for (final f in setup.type.fields.where((f) => f.scope == FieldScope.log))
    if (f.sourceId != null && setup.values[f.sourceId] is List)
      f.id: f.kind == FieldKind.checklist
          ? [
              for (final v in setup.values[f.sourceId] as List)
                {...v as Map, 'done': false},
            ]
          : setup.values[f.sourceId]
    else if (f.template.isNotEmpty)
      f.id: f.kind == FieldKind.checklist
          ? [
              for (final v in f.template) {...v as Map, 'done': false},
            ]
          : f.template,
};

bool trackingValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (k) => b.containsKey(k) && trackingValueEquals(a[k], b[k]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        a.indexed.every((e) => trackingValueEquals(e.$2, b[e.$1]));
  }
  return a == b;
}

bool sameTrackingSetup(TrackingSetup a, TrackingSetup b) =>
    a.type.id == b.type.id &&
    a.type.revision == b.type.revision &&
    trackingValueEquals(a.values, b.values) &&
    a.mainMetric == b.mainMetric &&
    a.target == b.target &&
    a.finishDate == b.finishDate &&
    a.closures.length == b.closures.length &&
    a.closures.indexed.every(
      (e) =>
          e.$2.from == b.closures[e.$1].from &&
          e.$2.until == b.closures[e.$1].until,
    ) &&
    a.history.length == b.history.length &&
    a.history.indexed.every((e) => sameTrackingSetup(e.$2, b.history[e.$1]));
