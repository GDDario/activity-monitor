import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/use_cases/check_task_overlap.dart';

import 'helpers/task_action_fixture.dart';

void main() {
  late TaskActionFixture fixture;
  late List<LocalDateRange> ensured;
  setUp(() {
    fixture = TaskActionFixture();
    ensured = [];
  });
  tearDown(() => fixture.repository.dispose());
  TaskDraft draft() =>
      TaskDraft.fromAggregate(fixture.repository.aggregate(fixture.occurrence));
  CheckTaskOverlap check() => CheckTaskOverlap(
    fixture.repository,
    ensure: (range) async {
      ensured.add(range);
      return fixture.repository.loadRange(range);
    },
  );
  void competitor(
    TimeWindow? window, {
    bool completed = false,
    bool deleted = false,
  }) {
    fixture.repository.occurrences[fixture.otherId] = fixture
        .repository
        .occurrences[fixture.otherId]!
        .copyWith(
          effectiveDate: fixture.date,
          timeWindow: window,
          completed: completed,
          deletedAtUtc: deleted ? DateTime.utc(2026, 12, 31) : null,
        );
  }

  test('adjacent windows do not overlap and the selected occurrence excludes itself', () async {
    competitor(TimeWindow(960, 1020));
    expect((await check().execute(draft())).value, isFalse);
    expect(ensured.single, LocalDateRange(fixture.date, fixture.date));
    expect(fixture.repository.mutationAttempts, 0);
  });
  test(
    'true overlap warns without becoming a save validation failure',
    () async {
      competitor(TimeWindow(930, 990));
      final result = await check().execute(draft());
      expect(result.isSuccess, isTrue);
      expect(result.value, isTrue);
      expect(fixture.repository.mutationAttempts, 0);
    },
  );
  for (final kind in ['untimed', 'completed', 'deleted', 'different date']) {
    test('ignores $kind competing occurrence', () async {
      competitor(
        kind == 'untimed' ? null : TimeWindow(930, 990),
        completed: kind == 'completed',
        deleted: kind == 'deleted',
      );
      if (kind == 'different date') {
        fixture.repository.occurrences[fixture.otherId] = fixture
            .repository
            .occurrences[fixture.otherId]!
            .copyWith(effectiveDate: fixture.date.addDays(1));
      }
      expect((await check().execute(draft())).value, isFalse);
    });
  }
  test('materializes the selected effective date before comparing newly generated competitors', () async {
    final checker = CheckTaskOverlap(
      fixture.repository,
      ensure: (range) async {
        ensured.add(range);
        competitor(TimeWindow(930, 990));
        return fixture.repository.loadRange(range);
      },
    );
    expect((await checker.execute(draft())).value, isTrue);
    expect(ensured.single.start, fixture.date);
    expect(ensured.single.end, fixture.date);
  });
  test(
    'checks the selected occurrence override rather than the recurring default',
    () async {
      competitor(TimeWindow(60, 120));
      expect(
        (await check().execute(
          draft().copyWith(
            hasOccurrenceOverride: true,
            occurrenceTimeWindow: TimeWindow(90, 150),
          ),
        )).value,
        isTrue,
      );
      expect(
        (await check().execute(
          draft().copyWith(
            hasOccurrenceOverride: true,
            occurrenceTimeWindow: null,
          ),
        )).value,
        isFalse,
      );
    },
  );
  test('completed current occurrence reserves no conflicting window', () async {
    fixture.repository.occurrences[fixture.id] = fixture.occurrence.copyWith(
      completed: true,
    );
    competitor(TimeWindow(930, 990));
    expect((await check().execute(draft())).value, isFalse);
  });
  test('unavailable advisory data stays unavailable rather than claiming no conflict', () async {
    final checker = CheckTaskOverlap(
      fixture.repository,
      ensure: (range) async =>
          TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
    );
    final result = await checker.execute(draft());
    expect(result.failure!.code, TaskFailureCode.storageUnavailable);
    expect(result.value, isNull);
    expect(fixture.repository.mutationAttempts, 0);
  });
  test('new weekly advisory checks the actual first selected weekday after the lower-bound start', () async {
    final first = fixture.date.addDays(3);
    fixture.repository.occurrences[fixture.otherId] = fixture
        .repository
        .occurrences[fixture.otherId]!
        .copyWith(effectiveDate: first, timeWindow: TimeWindow(930, 990));
    var next = 0;
    final weekly =
        TaskDraft.newTask(
          date: fixture.date,
          newId: () => 'new-${next++}',
        ).copyWith(
          title: 'Weekly',
          cadence: TaskCadence.weekly,
          recurrenceEnabled: true,
          weeklyDays: WeeklyDays(64),
          timeWindow: TimeWindow(900, 960),
        );
    expect((await check().execute(weekly)).value, isTrue);
    expect(ensured.single, LocalDateRange(first, first));
  });
}
