import 'package:app/domain/models/daily_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/dashboard/home_localizations.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';
import 'package:app/ui/dashboard/views/dashboard_view.dart';
import 'package:app/ui/tasks/task_localizations.dart';

import 'helpers/home_fixture.dart';

Future<void> showHome(
  WidgetTester tester,
  TodayViewModel model, {
  Locale locale = const Locale('en', 'US'),
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayViewModelProvider.overrideWith((ref) {
          ref.onDispose(model.dispose);
          return model;
        }),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
        localizationsDelegates: const [
          HomeLocalizationsDelegate(),
          TaskLocalizationsDelegate(),
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ActivityTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const DashboardView(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'Home composes real rhythm and grouped agenda, filters to a companion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = [
        for (var i = 0; i < 7; i++)
          homeTask(
            'Task $i',
            minute: i == 6 ? null : 600 + i * 60,
            completed: i < 4,
            notes: i == 6 ? 'A quiet intention' : '',
            participants: i < 2 ? [const TaskParticipant('emma', 'Emma')] : [],
          ),
      ];
      final model = TodayViewModel(
        clock: () => DateTime(2026, 11, 17, 10),
        load: (_) async => TaskSuccess(entries),
      );
      await model.load();
      await showHome(tester, model);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('4 of 7 completed'), findsOneWidget);
      expect(find.text('57%'), findsOneWidget);
      expect(find.text('2 collaborative'), findsOneWidget);
      expect(find.text('Morning Focus'), findsOneWidget);
      expect(find.text('Afternoon & Evening'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Emma'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 completed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Afternoon & Evening'), findsNothing);
      expect(find.textContaining('Alex'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Solo'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5 completed'), findsOneWidget);
    },
  );
  testWidgets(
    'compact reference filter strip scrolls and keyboard reveals the last companion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = TodayViewModel(
        clock: () => DateTime(2026, 11, 17, 10),
        load: (_) async => TaskSuccess([
          homeTask(
            'shared',
            participants: [
              for (var i = 0; i < 8; i++)
                TaskParticipant('person-$i', 'Person $i'),
            ],
          ),
        ]),
      );
      await model.load();
      await showHome(tester, model);
      final first = find.widgetWithText(FilterChip, 'All activities');
      final last = find.widgetWithText(FilterChip, 'Person 7');
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
      var reached = false;
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final chip = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FilterChip>();
        if (chip?.label is Text && (chip!.label as Text).data == 'Person 7') {
          reached = true;
          break;
        }
      }
      expect(reached, isTrue);
      expect(tester.getRect(last).right, lessThanOrEqualTo(374));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(model.state.scope.companionId, 'person-7');
      final selectedFocus = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<FilterChip>();
      expect((selectedFocus?.label as Text?)?.data, 'Person 7');
      await tester.pumpWidget(const SizedBox());
      final restored = TodayViewModel(
        clock: () => DateTime(2026, 11, 17, 10),
        load: (_) async => TaskSuccess([
          homeTask(
            'shared',
            participants: [
              for (var i = 0; i < 8; i++)
                TaskParticipant('person-$i', 'Person $i'),
            ],
          ),
        ]),
      );
      await restored.load();
      restored.setScope(const DailyTaskScope.companion('person-7'));
      await showHome(tester, restored);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).right, lessThanOrEqualTo(374));
      expect(tester.getRect(last).left, greaterThanOrEqualTo(16));
    },
  );
  testWidgets('empty scope has a reset action and honest zero progress', (
    tester,
  ) async {
    final model = TodayViewModel(
      clock: () => DateTime(2026, 11, 17, 10),
      load: (_) async => TaskSuccess([homeTask('Solo task')]),
    );
    await model.load();
    await showHome(tester, model);
    await tester.tap(find.widgetWithText(FilterChip, 'Shared'));
    await tester.pumpAndSettle();
    expect(find.text('No tasks match this filter.'), findsOneWidget);
    expect(find.text('0 of 0 completed'), findsOneWidget);
    await tester.ensureVisible(find.text('Show all activities'));
    await tester.tap(find.text('Show all activities'));
    await tester.pumpAndSettle();
    expect(find.text('Solo task'), findsOneWidget);
    expect(find.text('0 of 1 completed'), findsOneWidget);
  });
  testWidgets(
    'loading and unavailable never show stale summary and creation is disabled',
    (tester) async {
      final model = TodayViewModel(
        clock: () => DateTime(2026, 11, 17, 10),
        load: (_) async =>
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
      );
      await showHome(tester, model);
      expect(find.text('0 of 0 completed'), findsNothing);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await model.load();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.text('Morning Focus'), findsNothing);
    },
  );
  for (final locale in const [Locale('en', 'US'), Locale('pt', 'BR')]) {
    testWidgets(
      'compact doubled-text Home has labeled 48px actions in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final model = TodayViewModel(
            clock: () => DateTime(2026, 11, 17, 18),
            load: (_) async => TaskSuccess([
              homeTask(
                'A long thoughtful activity',
                notes: 'Optional saved context',
                minute: 1100,
              ),
            ]),
          );
          await model.load();
          await showHome(tester, model, locale: locale, scale: 2);
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale.languageCode == 'pt' ? 'Boa noite' : 'Good evening',
            ),
            findsOneWidget,
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await tester.scrollUntilVisible(
            find.text('A long thoughtful activity'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
