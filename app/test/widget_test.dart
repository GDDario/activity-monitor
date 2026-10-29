import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:app/app/activity_monitor_app.dart';

void main() {
  testWidgets('shows the daily activity overview', (WidgetTester tester) async {
    await tester.pumpWidget(const ActivityMonitorApp());

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Morning focus'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('uses a navigation rail in a wide window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ActivityMonitorApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses high-contrast colors for the selected filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ActivityMonitorApp());

    final selectedFilter = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'All activities'),
    );

    expect(selectedFilter.selectedColor, isNull);
    expect(selectedFilter.labelStyle?.color, const Color(0xFF191C1A));
  });
}
