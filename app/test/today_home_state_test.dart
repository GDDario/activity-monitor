import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';

import 'helpers/home_fixture.dart';

void main() {
  const emma = TaskParticipant('emma', 'Emma');
  test('companion scope survives failure and falls back only after successful absence', () async {
    var fail = false, missing = false;
    var calls = 0;
    final model = TodayViewModel(
      clock: () => DateTime(2026, 11, 17, 10),
      load: (_) async {
        calls++;
        return fail
            ? TaskError(TaskFailure(TaskFailureCode.storageUnavailable))
            : TaskSuccess([
                homeTask('task', participants: missing ? [] : [emma]),
              ]);
      },
    );
    addTearDown(model.dispose);
    await model.load();
    model.setScope(const DailyTaskScope.companion('emma'));
    expect(calls, 1);
    expect(model.state.overview!.scope, const DailyTaskScope.companion('emma'));
    fail = true;
    await model.load();
    expect(model.state.scope, const DailyTaskScope.companion('emma'));
    expect(model.state.overview, isNull);
    fail = false;
    missing = true;
    await model.load();
    expect(model.state.scope, const DailyTaskScope.all());
  });
  testWidgets(
    'minute timer and same-day resume reproject without database reads',
    (tester) async {
      var now = DateTime(2026, 11, 17, 10, 0, 30), calls = 0;
      final model = TodayViewModel(
        clock: () => now,
        load: (_) async {
          calls++;
          return TaskSuccess([
            homeTask('now', minute: 600),
            homeTask('later', minute: 620),
          ]);
        },
      );
      await model.load();
      expect(model.state.overview!.progress.next!.task.id.value, 'now');
      now = DateTime(2026, 11, 17, 10, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(model.state.overview!.progress.next!.task.id.value, 'later');
      model.setResumed(false);
      final snapshot = model.state.now;
      now = DateTime(2026, 11, 17, 18);
      await tester.pump(const Duration(minutes: 1));
      expect(model.state.now, snapshot);
      model.setResumed(true);
      expect(model.state.now.hour, 18);
      expect(model.state.overview!.progress.next, isNull);
      expect(calls, 1);
      model.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 1);
    },
  );
  for (final lateHistory in [false, true]) {
    test(
      'old-day ${lateHistory ? 'streak' : 'aggregate'} result triggers current day without publishing old data',
      () async {
        var now = DateTime(2026, 11, 17, 23, 59);
        var calls = 0;
        final old = Completer<TaskResult<List<TaskAggregate>>>();
        final history = Completer<TaskResult<Map<TaskId, int>>>();
        final started = Completer<void>();
        final model = TodayViewModel(
          clock: () => now,
          load: (range) {
            calls++;
            if (calls == 1 && !lateHistory) return old.future;
            return Future.value(
              TaskSuccess([homeTask('day-$calls', date: range.start)]),
            );
          },
          loadStreaks: (ids, date) {
            if (lateHistory && date == homeDay) {
              started.complete();
              return history.future;
            }
            return Future.value(const TaskSuccess({}));
          },
        );
        addTearDown(model.dispose);
        final seen = <String>[];
        model.addListener(() {
          for (final entry in model.visible) {
            seen.add(entry.task.id.value);
          }
        });
        final pending = model.load();
        if (lateHistory) await started.future;
        now = DateTime(2026, 11, 18);
        if (lateHistory) {
          history.complete(const TaskSuccess({}));
        } else {
          old.complete(TaskSuccess([homeTask('old')]));
        }
        await pending;
        expect(calls, 2);
        expect(seen, isNot(contains('old')));
        expect(model.state.overview!.day, homeDay.addDays(1));
        expect(model.visible.single.task.id.value, 'day-2');
      },
    );
  }
}
