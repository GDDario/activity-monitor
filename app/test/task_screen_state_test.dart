import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';

TaskAggregate _task(
  String id,
  LocalDate date, {
  bool completed = false,
  bool shared = false,
}) {
  final taskId = TaskId(id);
  return TaskAggregate(
    task: Task(
      id: taskId,
      title: TaskTitle(id),
      schedule: TaskSchedule(
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
        startDate: date,
        streakEnabled: true,
      ),
      participants: shared ? [const TaskParticipant('person', 'Alex')] : [],
    ),
    occurrence: TaskOccurrence(
      id: OccurrenceId(id),
      taskId: taskId,
      scheduledDate: date,
      effectiveDate: date,
      completed: completed,
    ),
  );
}

CalendarData _calendarData(String id, DateTime date) => CalendarData(
  [
    CalendarEntry(
      id: id,
      title: id,
      date: date,
      cadence: CalendarCadence.weekly,
      participantIds: const ['person'],
    ),
  ],
  const [CalendarParticipant('person', 'Alex')],
);

void main() {
  final date = LocalDate(2026, 12, 31);
  for (final oldFails in [false, true]) {
    test(
      'Today ignores an older ${oldFails ? 'failed' : 'successful'} range after a newer local-day load',
      () async {
        var now = DateTime(2026, 12, 31, 12);
        final first = Completer<TaskResult<List<TaskAggregate>>>();
        final second = Completer<TaskResult<List<TaskAggregate>>>();
        final ranges = <LocalDateRange>[];
        final model = TodayViewModel(
          clock: () => now,
          load: (range) {
            ranges.add(range);
            return ranges.length == 1 ? first.future : second.future;
          },
        );
        addTearDown(model.dispose);
        final older = model.load();
        now = DateTime(2027, 1, 1, 12);
        final newer = model.load();
        model.setFilter(TodayFilter.shared);
        second.complete(
          TaskSuccess([_task('newer', date.addDays(1), shared: true)]),
        );
        await newer;
        first.complete(
          oldFails
              ? TaskError(TaskFailure(TaskFailureCode.storageUnavailable))
              : TaskSuccess([_task('older', date)]),
        );
        await older;
        expect(ranges, [
          LocalDateRange(date, date),
          LocalDateRange(date.addDays(1), date.addDays(1)),
        ]);
        expect(model.visible.single.task.id.value, 'newer');
        expect(model.state.filter, TodayFilter.shared);
        expect(model.state.failure, isNull);
        expect(model.pendingCount, 1);
      },
    );
  }
  test('Today rejects stale streak responses after the newer range and history are committed', () async {
    final oldHistory = Completer<TaskResult<Map<TaskId, int>>>();
    final newHistory = Completer<TaskResult<Map<TaskId, int>>>();
    final oldStarted = Completer<void>();
    final newStarted = Completer<void>();
    var calls = 0;
    final model = TodayViewModel(
      clock: () => DateTime(2026, 12, 31),
      load: (_) async =>
          TaskSuccess([_task(++calls == 1 ? 'older' : 'newer', date)]),
      loadStreaks: (ids, day) {
        if (ids.single.value == 'older') {
          oldStarted.complete();
          return oldHistory.future;
        }
        newStarted.complete();
        return newHistory.future;
      },
    );
    addTearDown(model.dispose);
    final older = model.load();
    await oldStarted.future;
    final newer = model.load();
    await newStarted.future;
    newHistory.complete(TaskSuccess({TaskId('newer'): 3}));
    await newer;
    oldHistory.complete(TaskSuccess({TaskId('older'): 99}));
    await older;
    expect(model.visible.single.task.id.value, 'newer');
    expect(model.state.streaks, {TaskId('newer'): 3});
  });
  test('Today range failure clears old cards and counts while remaining distinguishable from a valid empty day', () async {
    var fail = false;
    var empty = false;
    final model = TodayViewModel(
      clock: () => DateTime(2026, 12, 31),
      load: (_) async => fail
          ? TaskError(TaskFailure(TaskFailureCode.storageUnavailable))
          : TaskSuccess(
              empty
                  ? []
                  : [
                      _task('solo', date),
                      _task('shared', date, completed: true, shared: true),
                    ],
            ),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(model.pendingCount, 1);
    expect(model.doneCount, 1);
    fail = true;
    await model.load();
    expect(model.state.failure!.code, TaskFailureCode.storageUnavailable);
    expect(model.state.isLoading, isFalse);
    expect(model.visible, isEmpty);
    expect(model.pendingCount, 0);
    expect(model.doneCount, 0);
    fail = false;
    empty = true;
    await model.load();
    expect(model.state.failure, isNull);
    expect(model.visible, isEmpty);
  });
  test('a thrown Today streak loader becomes unavailable rather than leaving a loading state or fabricated zero streak', () async {
    final model = TodayViewModel(
      clock: () => DateTime(2026, 12, 31),
      load: (_) async => TaskSuccess([_task('task', date)]),
      loadStreaks: (ids, day) async =>
          throw StateError('private history detail'),
    );
    addTearDown(model.dispose);
    await expectLater(model.load(), completes);
    expect(model.state.isLoading, isFalse);
    expect(model.state.failure!.code, TaskFailureCode.storageUnavailable);
    expect(model.state.streaks, isEmpty);
    expect(model.visible, isEmpty);
  });
  test(
    'Today typed history unavailability is not presented as zero progress',
    () async {
      final model = TodayViewModel(
        clock: () => DateTime(2026, 12, 31),
        load: (_) async => TaskSuccess([_task('task', date, completed: true)]),
        loadStreaks: (ids, day) async =>
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
      );
      addTearDown(model.dispose);
      await model.load();
      expect(model.state.failure!.code, TaskFailureCode.storageUnavailable);
      expect(model.state.streaks.containsKey(TaskId('task')), isFalse);
      expect(model.visible, isEmpty);
    },
  );
  testWidgets(
    'local midnight refreshes Today while Calendar keeps its explicit selection, mode and filters',
    (tester) async {
      var now = DateTime(2026, 12, 31, 23, 59);
      final ranges = <LocalDateRange>[];
      final calendar = CalendarViewModel(
        now,
        () async => const CalendarData([], []),
      );
      addTearDown(calendar.dispose);
      calendar.selectDate(DateTime(2027, 2, 15));
      calendar.setWeekMode(true);
      calendar.setCadence(CalendarCadence.weekly);
      calendar.toggleParticipant('person');
      final today = TodayViewModel(
        clock: () => now,
        load: (range) async {
          ranges.add(range);
          return TaskSuccess([_task(range.start.toString(), range.start)]);
        },
      );
      try {
        await today.load();
        now = DateTime(2027, 1, 1);
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(ranges, [
          LocalDateRange(date, date),
          LocalDateRange(date.addDays(1), date.addDays(1)),
        ]);
        expect(today.visible.single.occurrence.effectiveDate, date.addDays(1));
        expect(calendar.calendar.selected, DateTime(2027, 2, 15));
        expect(calendar.calendar.weekMode, isTrue);
        expect(calendar.calendar.cadence, CalendarCadence.weekly);
        expect(calendar.calendar.participantId, 'person');
      } finally {
        today.dispose();
      }
    },
  );
  test('resume refresh checks the injected local day and preserves the active Today filter', () async {
    var now = DateTime(2026, 12, 31, 12);
    final refreshed = Completer<void>();
    var calls = 0;
    final model = TodayViewModel(
      clock: () => now,
      load: (range) async {
        calls++;
        return TaskSuccess([_task('day-$calls', range.start, shared: true)]);
      },
    );
    addTearDown(model.dispose);
    model.addListener(() {
      if (calls == 2 && !model.state.isLoading && !refreshed.isCompleted) {
        refreshed.complete();
      }
    });
    await model.load();
    model.setFilter(TodayFilter.shared);
    model.refreshForLocalDay();
    expect(calls, 1);
    now = DateTime(2027, 1, 1, 8);
    model.refreshForLocalDay();
    await refreshed.future;
    expect(calls, 2);
    expect(model.state.filter, TodayFilter.shared);
    expect(model.visible.single.occurrence.effectiveDate, date.addDays(1));
  });
  test('Calendar marks a refresh as loading while keeping its selection and filters', () async {
    final pending = Completer<CalendarData>();
    var calls = 0;
    final model = CalendarViewModel(
      DateTime(2026, 12, 31),
      () => ++calls == 1
          ? Future.value(_calendarData('first', DateTime(2026, 12, 31)))
          : pending.future,
    );
    addTearDown(model.dispose);
    await model.load();
    model.selectDate(DateTime(2027, 1, 4));
    model.setWeekMode(true);
    model.setCadence(CalendarCadence.weekly);
    model.toggleParticipant('person');
    final loading = model.load();
    expect(model.isLoading, isTrue);
    pending.complete(_calendarData('latest', DateTime(2027, 1, 4)));
    await loading;
    expect(model.isLoading, isFalse);
    expect(model.calendar.selected, DateTime(2027, 1, 4));
    expect(model.calendar.weekMode, isTrue);
    expect(model.calendar.cadence, CalendarCadence.weekly);
    expect(model.calendar.participantId, 'person');
    expect(model.calendar.selectedEntries.single.id, 'latest');
  });
  test('Calendar ignores older streak results and retains selection/filter through a newer refresh', () async {
    final oldHistory = Completer<Map<String, int>>();
    final newHistory = Completer<Map<String, int>>();
    final oldStarted = Completer<void>();
    final newStarted = Completer<void>();
    var calls = 0;
    final selected = DateTime(2027, 1, 4);
    final model = CalendarViewModel(
      selected,
      () async => _calendarData(++calls == 1 ? 'old' : 'new', selected),
      loadStreaks: (data) {
        if (data.entries.single.id == 'old') {
          oldStarted.complete();
          return oldHistory.future;
        }
        newStarted.complete();
        return newHistory.future;
      },
    );
    addTearDown(model.dispose);
    model.setCadence(CalendarCadence.weekly);
    model.toggleParticipant('person');
    final first = model.load();
    await oldStarted.future;
    final second = model.load();
    await newStarted.future;
    newHistory.complete({'new': 2});
    await second;
    oldHistory.complete({'old': 42});
    await first;
    expect(model.calendar.selected, selected);
    expect(model.calendar.participantId, 'person');
    expect(model.calendar.selectedEntries.single.id, 'new');
    expect(model.streaks, {'new': 2});
  });
  test('Calendar history failure clears unavailable data without resetting user navigation', () async {
    final selected = DateTime(2027, 1, 4);
    final model = CalendarViewModel(
      selected,
      () async => _calendarData('task', selected),
      loadStreaks: (data) async => throw StateError('private history detail'),
    );
    addTearDown(model.dispose);
    model.setCadence(CalendarCadence.weekly);
    model.toggleParticipant('person');
    await model.load();
    expect(model.hasError, isTrue);
    expect(model.isLoading, isFalse);
    expect(model.calendar.data, isNull);
    expect(model.calendar.selectedEntries, isEmpty);
    expect(model.streaks, isEmpty);
    expect(model.calendar.selected, selected);
    expect(model.calendar.participantId, 'person');
  });
}
