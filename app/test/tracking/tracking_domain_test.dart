import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/use_cases/tracking_metrics.dart';
import 'package:app/domain/value_objects/local_date.dart';

void main() {
  final field = TrackingField(
    id: 'pages',
    label: 'Pages',
    kind: FieldKind.number,
    scope: FieldScope.log,
  );
  final type = TaskType(
    id: 'custom',
    name: 'Reading',
    icon: 'book',
    fields: [field],
  );
  ActivityLog log(String id, int day, Object value) => ActivityLog(
    id: id,
    taskId: 'task',
    recordedAt: DateTime.utc(2026, 11, day),
    type: type,
    values: {'pages': value},
  );

  test('rejects nonfinite numbers, wrong choices and required blank text', () {
    expect(field.validate(double.nan), isNotNull);
    expect(field.validate(double.infinity), isNotNull);
    expect(field.validate(-1.5), isNull);
    final choice = TrackingField(
      id: 'c',
      label: 'Choice',
      kind: FieldKind.choice,
      scope: FieldScope.log,
      choices: ['A', 'B'],
    );
    expect(choice.validate('C'), isNotNull);
    expect(choice.validate('A'), isNull);
    final text = TrackingField(
      id: 't',
      label: 'Text',
      kind: FieldKind.text,
      scope: FieldScope.setup,
      required: true,
    );
    expect(text.validate('  '), isNotNull);
  });
  test('rejects duplicate labels, empty choices and excess fields', () {
    expect(
      () => TaskType(
        id: 'c',
        name: 'Custom',
        icon: 'book',
        fields: [
          field,
          TrackingField(
            id: 'other',
            label: ' pages ',
            kind: FieldKind.text,
            scope: FieldScope.setup,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => TrackingField(
        id: 'c',
        label: 'Choice',
        kind: FieldKind.choice,
        scope: FieldScope.log,
      ),
      throwsArgumentError,
    );
  });
  test('summaries include zero and omit absent values', () {
    final logs = [log('a', 1, 0), log('b', 2, 10), log('c', 3, 20)];
    final series = trackingMetrics(TrackingSetup(type: type), logs).single;
    expect(series.summarize(MetricSummary.total), 30);
    expect(series.summarize(MetricSummary.latest), 20);
    expect(series.summarize(MetricSummary.average), 10);
    expect(series.summarize(MetricSummary.highest), 20);
    expect(
      trackingMetrics(
        TrackingSetup(type: type),
        [],
      ).single.summarize(MetricSummary.total),
      isNull,
    );
  });
  test(
    'book baseline, backdates, rereading and deletions recalculate progress',
    () {
      final book = builtinTaskTypes().firstWhere((t) => t.icon == 'book');
      final setup = TrackingSetup(
        type: book,
        values: {'totalPages': 300, 'startingPage': 40},
      );
      ActivityLog entry(String id, int day, int page, {int reread = 0}) =>
          ActivityLog(
            id: id,
            taskId: 'task',
            recordedAt: DateTime.utc(2026, 11, day),
            type: book,
            values: {'currentPage': page, 'rereadPages': reread},
          );
      final logs = [
        entry('a', 1, 60),
        entry('c', 3, 75),
        entry('b', 2, 65, reread: 10),
      ];
      expect(validateTrackingHistory(setup, logs), isEmpty);
      final metrics = trackingMetrics(setup, logs);
      expect(
        metrics
            .firstWhere((m) => m.id == 'currentPage')
            .summarize(MetricSummary.total),
        35,
      );
      expect(
        metrics
            .firstWhere((m) => m.id == 'rereadPages')
            .summarize(MetricSummary.total),
        10,
      );
      expect(
        trackingMetrics(setup, [logs.first, logs[1]])
            .firstWhere((m) => m.id == 'currentPage')
            .summarize(MetricSummary.total),
        35,
      );
      expect(
        validateTrackingHistory(setup, [...logs, entry('d', 4, 70)]),
        isNotEmpty,
      );
    },
  );
  test('historical book bounds still apply after changing the task type', () {
    final book = builtinTaskTypes().firstWhere((t) => t.icon == 'book');
    final setup = TrackingSetup(
      type: book,
      values: {'totalPages': 100, 'startingPage': 0},
    ).changeType(generalTaskType());
    final bad = ActivityLog(
      id: 'bad',
      taskId: 'task',
      recordedAt: DateTime.utc(2026),
      type: book,
      values: {'currentPage': 120},
    );
    expect(validateTrackingHistory(setup, [bad]), isNotEmpty);
  });
  test('episodes support gaps and count each unit once', () {
    final type = builtinTaskTypes().firstWhere((t) => t.icon == 'tv');
    final logs = [
      ActivityLog(
        id: 'a',
        taskId: 'task',
        recordedAt: DateTime.utc(2026),
        type: type,
        values: {
          'episodes': [
            {'season': 2, 'episode': 3},
          ],
        },
      ),
      ActivityLog(
        id: 'b',
        taskId: 'task',
        recordedAt: DateTime.utc(2026, 2),
        type: type,
        values: {
          'episodes': [
            {'season': 1, 'episode': 1},
            {'season': 2, 'episode': 3},
          ],
        },
      ),
    ];
    expect(
      trackingMetrics(
        TrackingSetup(type: type),
        logs,
      ).firstWhere((m) => m.id == 'episodes').summarize(MetricSummary.total),
      2,
    );
  });
  test('structured values are validated and deeply immutable', () {
    final exercises = TrackingField(
      id: 'e',
      label: 'Sets',
      kind: FieldKind.exercises,
      scope: FieldScope.log,
    );
    expect(
      exercises.validate([
        {'exercise': 'Squat', 'reps': 5, 'weight': 20},
      ]),
      isNull,
    );
    expect(
      exercises.validate([
        {'exercise': 'Squat', 'reps': 0},
      ]),
      isNotNull,
    );
    final values = <String, Object?>{
      'e': [
        {'exercise': 'Squat', 'reps': 5},
      ],
    };
    final log = ActivityLog(
      id: 'a',
      taskId: 'task',
      recordedAt: DateTime.utc(2026),
      type: TaskType(
        id: 'c',
        name: 'Custom',
        icon: 'fitness',
        fields: [exercises],
      ),
      values: values,
    );
    (values['e'] as List).clear();
    expect(log.values['e'], hasLength(1));
    expect(() => (log.values['e'] as List).clear(), throwsUnsupportedError);
  });
  test('pace uses inclusive calendar days and guards overdue dates', () {
    expect(
      suggestedDailyPace(
        remaining: 240,
        today: LocalDate(2026, 11, 1),
        target: LocalDate(2026, 11, 20),
        wholeUnits: true,
      ),
      12,
    );
    expect(
      suggestedDailyPace(
        remaining: 240,
        today: LocalDate(2026, 11, 21),
        target: LocalDate(2026, 11, 20),
      ),
      isNull,
    );
  });
  test(
    'retiring a main metric clears the selection without losing history',
    () {
      final setup = TrackingSetup(type: type, mainMetric: 'pages', target: 100);
      final refreshed = setup.refreshType(
        type.copyWith(fields: [], revision: 1),
      );
      expect(refreshed.mainMetric, isNull);
      expect(refreshed.target, isNull);
      expect(refreshed.history.single.type.fields.single.id, 'pages');
    },
  );
  test('closed intervals exclude recurrence and preserve today on finish', () {
    final setup = TrackingSetup().finish(LocalDate(2026, 11, 1));
    expect(setup.allowsDate(LocalDate(2026, 11, 1)), isTrue);
    expect(setup.allowsDate(LocalDate(2026, 11, 2)), isFalse);
    final reopened = setup.reopen(LocalDate(2026, 11, 5));
    expect(reopened.allowsDate(LocalDate(2026, 11, 4)), isFalse);
    expect(reopened.allowsDate(LocalDate(2026, 11, 5)), isTrue);
  });
}
