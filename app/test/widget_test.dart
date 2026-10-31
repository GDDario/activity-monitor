import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'package:app/app/activity_monitor_app.dart';

void main() {
  testWidgets('shows the daily activity overview', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Morning focus'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(find.byType(Scaffold))),
      const Locale('en', 'US'),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, contains(const Locale('pt', 'BR')));
    expect(find.byType(ToastificationWrapper), findsOneWidget);
  });

  testWidgets('uses a navigation rail in a wide window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('opens the People base screen from primary navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    expect(find.text('People'), findsWidgets);
    expect(find.text('Your shared rhythms will appear here.'), findsOneWidget);
  });

  testWidgets('uses the shared title area on the Calendar base screen', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.byTooltip('Open notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile initials AM'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('opens the Profile base screen from primary navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile preferences will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('opens Profile when the user avatar is tapped', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    await tester.tap(find.bySemanticsLabel('Profile initials AM'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile preferences will appear here.'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('uses Today content insets on base destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final content = tester.widget<ListView>(find.byType(ListView));
    expect(content.padding, const EdgeInsets.fromLTRB(16, 24, 16, 112));
  });

  testWidgets('uses high-contrast colors for the selected filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ActivityMonitorApp()));

    final selectedFilter = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'All activities'),
    );

    expect(selectedFilter.selectedColor, isNull);
    expect(selectedFilter.labelStyle?.color, const Color(0xFF191C1A));
  });
}
