import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';
import 'package:app/ui/dashboard/views/dashboard_view.dart';
import 'package:app/ui/core/theme/activity_colors.dart';

void main() {
  testWidgets('empty Today has no sample tasks or invented progress', (
    tester,
  ) async {
    final model = TodayViewModel(
      clock: () => DateTime(2026, 11, 7),
      load: (_) async => const TaskSuccess([]),
    );
    await model.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayViewModelProvider.overrideWith((ref) {
            ref.onDispose(model.dispose);
            return model;
          }),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No tasks for this day. Create a task to begin.'),
      findsOneWidget,
    );
    expect(find.text('Read a chapter'), findsNothing);
    expect(find.text('4 of 7 completed'), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'Create task'),
      findsOneWidget,
    );
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.selectedColor, ActivityColors.primary);
      expect(chip.backgroundColor, ActivityColors.surfaceMuted);
      expect(
        chip.labelStyle?.color,
        chip.selected ? Colors.white : ActivityColors.mutedInk,
      );
      expect(chip.showCheckmark, false);
    }
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();
    final solo = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Solo'),
    );
    expect(solo.selected, true);
    expect(solo.labelStyle?.color, Colors.white);
  });
}
