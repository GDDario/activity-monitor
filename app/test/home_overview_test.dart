import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/build_daily_overview.dart';

import 'helpers/home_fixture.dart';

void main() {
  final now = DateTime(2026, 11, 17, 10);
  const emma = TaskParticipant('emma', 'Emma');
  const liam = TaskParticipant('liam', 'Liam');
  DailyOverview build(
    List<TaskAggregate> entries, {
    DailyTaskScope scope = const DailyTaskScope.all(),
    DateTime? at,
  }) => const BuildDailyOverview().execute(
    entries: entries,
    now: at ?? now,
    scope: scope,
  );

  test('only effective-date nondeleted occurrences contribute', () {
    final result = build([
      homeTask('today'),
      homeTask('completed', completed: true),
      homeTask('deleted', deleted: true),
      homeTask('tomorrow', date: homeDay.addDays(1)),
      homeTask('past', date: homeDay.addDays(-1)),
    ]);
    expect(result.entries.map((e) => e.task.id.value), ['today', 'completed']);
    expect(result.progress.total, 2);
    expect(() => result.entries.clear(), throwsUnsupportedError);
  });
  test('scope is exclusive and companions deduplicate by identity', () {
    final entries = [
      homeTask('solo'),
      homeTask('both', participants: [emma, liam]),
      homeTask('emma', participants: [emma]),
    ];
    final all = build(entries);
    expect(all.companions.map((p) => p.id), ['emma', 'liam']);
    expect(all.progress.collaborative, 2);
    expect(
      build(
        entries,
        scope: const DailyTaskScope.solo(),
      ).entries.single.task.id.value,
      'solo',
    );
    expect(
      build(entries, scope: const DailyTaskScope.shared()).entries.length,
      2,
    );
    final person = build(
      entries,
      scope: const DailyTaskScope.companion('liam'),
    );
    expect(person.entries.single.task.id.value, 'both');
    expect(person.companions.length, 2);
    expect(person.scope, const DailyTaskScope.companion('liam'));
  });
  test('missing companion falls back to All, not empty fabricated data', () {
    final result = build([
      homeTask('solo'),
    ], scope: const DailyTaskScope.companion('gone'));
    expect(result.scope, const DailyTaskScope.all());
    expect(result.progress.total, 1);
  });
  test('summary computes rounded progress and counts each occurrence once', () {
    final entries = [
      for (var i = 0; i < 7; i++)
        homeTask(
          '$i',
          completed: i < 4,
          participants: i < 2 ? [emma, liam] : [],
        ),
    ];
    final p = build(entries).progress;
    expect(p.total, 7);
    expect(p.completed, 4);
    expect(p.pending, 3);
    expect(p.percentage, 57);
    expect(p.fraction, closeTo(4 / 7, .0001));
    expect(p.collaborative, 2);
  });
  test('zero and all-completed sets have defined percentages and no Next', () {
    expect(build([]).progress.percentage, 0);
    expect(build([]).progress.fraction, 0);
    final done = build([homeTask('done', completed: true, minute: 700)])
        .progress;
    expect(done.percentage, 100);
    expect(done.pending, 0);
    expect(done.next, isNull);
  });
  test(
    'noon boundary and specific windows take precedence over daily preferences',
    () {
      final result = build([
        homeTask('before', minute: 719),
        homeTask('noon', minute: 720),
        homeTask('preferred', period: DayPeriod.morning),
        homeTask('evening', period: DayPeriod.evening),
        homeTask('override', minute: 800, period: DayPeriod.morning),
        homeTask('untimed'),
      ]);
      expect(result.sections.map((s) => s.period), DailyAgendaPeriod.values);
      expect(result.sections[0].entries.map((e) => e.task.id.value), [
        'before',
        'preferred',
      ]);
      expect(result.sections[1].entries.map((e) => e.task.id.value), [
        'noon',
        'override',
        'evening',
      ]);
      expect(result.sections[2].entries.single.task.id.value, 'untimed');
      expect(result.sections.expand((s) => s.entries).length, 6);
    },
  );
  test(
    'each section preserves pending time title and occurrence identity ties',
    () {
      final result = build([
        homeTask('done', minute: 500, completed: true),
        homeTask('z', minute: 650, title: 'Same'),
        homeTask('a', minute: 650, title: 'Same'),
        homeTask('first', minute: 600),
        homeTask('untimed', period: DayPeriod.morning),
      ]);
      expect(result.sections.single.entries.map((e) => e.task.id.value), [
        'first',
        'a',
        'z',
        'untimed',
        'done',
      ]);
    },
  );
  test('Next excludes earlier completed and untimed while retaining agenda entries', () {
    final entries = [
      homeTask('past', minute: 599),
      homeTask('done', minute: 600, completed: true),
      homeTask('untimed'),
      homeTask('now', minute: 600),
      homeTask('future', minute: 620),
    ];
    expect(build(entries).progress.next!.task.id.value, 'now');
    expect(
      build(
        entries,
        at: now.add(const Duration(minutes: 1)),
      ).progress.next!.task.id.value,
      'future',
    );
    expect(
      build(entries, at: now.add(const Duration(hours: 1))).progress.next,
      isNull,
    );
    expect(build(entries).entries.length, 5);
  });
  test('Next follows selected scope and stable equal-time ties', () {
    final entries = [
      homeTask('z', title: 'Same', minute: 620),
      homeTask('a', title: 'Same', minute: 620),
      homeTask('shared', minute: 650, participants: [emma]),
    ];
    expect(build(entries).progress.next!.task.id.value, 'a');
    expect(
      build(
        entries,
        scope: const DailyTaskScope.shared(),
      ).progress.next!.task.id.value,
      'shared',
    );
  });
}
