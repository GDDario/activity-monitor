import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/dependencies/people_dependencies.dart';
import 'package:app/app/dependencies/people_repository_dependencies.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/app/dependencies/task_dependencies.dart';

import 'helpers/home_fixture.dart';

import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';
import 'package:app/ui/people/views/people_view.dart';

import 'helpers/fake_people_repository.dart';

Future<void> showPeople(
  WidgetTester tester,
  PeopleViewModel model, {
  Locale locale = const Locale('en', 'US'),
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peopleViewModelProvider.overrideWith((ref) async => model),
        taskChangesProvider.overrideWith((ref) => const Stream.empty()),
        peopleChangesProvider.overrideWith((ref) => const Stream.empty()),
        peopleRepositoryProvider.overrideWith((ref) async => model.repository),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ActivityTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const PeopleView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class HistoryPeople extends FakePeopleRepository {
  HistoryPeople(super.snapshot);
  @override
  Future<PeopleResult<PersonActivityPage>> loadPersonActivities(
    String id, {
    int page = 0,
    bool ascending = false,
  }) async {
    final entries = [
      for (var i = 0; i < 21; i++)
        homeTask('row-$i', title: 'History activity $i'),
    ];
    if (ascending) {
      return PeopleResult.success(
        PersonActivityPage(
          entries: entries.take(20).toList(),
          total: 21,
          page: 0,
        ),
      );
    }
    return PeopleResult.success(
      PersonActivityPage(
        entries: entries.skip(page * 20).take(20).toList(),
        total: 21,
        page: page,
      ),
    );
  }
}

void main() {
  testWidgets('directory search shows real people and global overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakePeopleRepository(
      PeopleSnapshot(
        people: [
          Person(id: 'a', name: 'Ana', role: 'Designer'),
          Person(id: 'b', name: 'Sam'),
        ],
        solo: 1,
        shared: 1,
        activeShared: 1,
      ),
    );
    final model = PeopleViewModel(repo);
    addTearDown(model.dispose);
    addTearDown(repo.dispose);
    await model.load();
    await showPeople(tester, model);
    expect(find.text('Collaborators'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('people-search')), 'ana');
    await tester.pump();
    expect(find.text('Sam'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('50% / 50%'), findsOneWidget);
  });
  testWidgets(
    'keyboard traversal reveals the final horizontal category filter',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakePeopleRepository(
        PeopleSnapshot(
          people: [Person(id: 'a', name: 'Ana')],
        ),
      );
      final model = PeopleViewModel(repo);
      addTearDown(model.dispose);
      addTearDown(repo.dispose);
      await model.load();
      await showPeople(tester, model);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('people-filter-all')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      Focus.of(tester.element(find.text('Creative'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Family'))).hasFocus, true);
      final rect = tester.getRect(
        find.byKey(const ValueKey('people-filter-family')),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    },
  );
  testWidgets(
    'create and edit person retain categories and canceled drafts save nothing',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakePeopleRepository(PeopleSnapshot());
      final model = PeopleViewModel(repo);
      addTearDown(model.dispose);
      addTearDown(repo.dispose);
      await model.load();
      await showPeople(tester, model);
      await tester.tap(find.text('New Person'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
        'Robin Ward',
      );
      await tester.enterText(
        find.byKey(const ValueKey('person-role')),
        'Creative partner',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Creative').last);
      await tester.tap(find.text('Save person'));
      await tester.pumpAndSettle();
      expect(find.text('Robin Ward'), findsOneWidget);
      expect(repo.snapshot.people.single.categories, {PersonCategory.creative});
      await tester.tap(find.text('Robin Ward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Person'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
        'Robin W.',
      );
      await tester.tap(find.text('Save person'));
      await tester.pumpAndSettle();
      expect(repo.snapshot.people.single.name, 'Robin W.');
      expect(find.text('Robin W.'), findsWidgets);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Person'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
        'Unsaved',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(repo.snapshot.people.length, 1);
    },
  );
  testWidgets('person history pages and sort reset through real controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = HistoryPeople(
      PeopleSnapshot(
        people: [Person(id: 'a', name: 'Ana')],
      ),
    );
    final model = PeopleViewModel(repo);
    addTearDown(model.dispose);
    addTearDown(repo.dispose);
    await model.load();
    await showPeople(tester, model);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.text('1–20 of 21'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Next'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('21–21 of 21'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Oldest first'),
      -500,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();
    expect(find.text('1–20 of 21'), findsOneWidget);
  });
  for (final locale in [const Locale('en', 'US'), const Locale('pt', 'BR')]) {
    testWidgets(
      'compact doubled text supports empty and unavailable ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakePeopleRepository(PeopleSnapshot());
        final model = PeopleViewModel(repo);
        addTearDown(model.dispose);
        addTearDown(repo.dispose);
        await model.load();
        await showPeople(tester, model, locale: locale, scale: 2);
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
        repo.failure = PeopleFailure.storageUnavailable;
        await model.load();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(locale.languageCode == 'pt' ? 'Tentar novamente' : 'Retry'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(locale.languageCode == 'pt' ? 'Tentar novamente' : 'Retry'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
