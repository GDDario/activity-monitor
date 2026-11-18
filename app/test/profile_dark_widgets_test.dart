import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';

import 'helpers/home_fixture.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/ui/dashboard/widgets/home_summary.dart';

void main() {
  testWidgets('saved task cards use dark semantic surfaces rather than white', (
    tester,
  ) async {
    final actions = TaskActionsViewModel(
      commands: {},
      undo: (_) async => throw StateError('unused'),
    );
    addTearDown(actions.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.dark(),
        home: Scaffold(
          body: TaskCard(
            aggregate: homeTask('task'),
            actions: actions,
            onEdit: () {},
          ),
        ),
      ),
    );
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, const ActivityPalette(dark: true).surface);
  });
  testWidgets('dark progress ring distinguishes completion from its track', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.dark(),
        home: Scaffold(
          body: HomeSummary(
            progress: const DailyProgress(
              total: 4,
              completed: 2,
              collaborative: 1,
              next: null,
            ),
          ),
        ),
      ),
    );
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    final a = ring.color!.computeLuminance(),
        b = ring.backgroundColor!.computeLuminance();
    expect(
      ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('large priority labels stay on one line within each choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: homeDay,
        newId: () => 'id',
      ).copyWith(title: 'Readable priorities'),
      newId: () => 'id',
      validate: validateTaskDraft,
      save: (_) async =>
          TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: TaskEditorSheet(model: model)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Medium'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Medium'));
    expect(
      paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 6),
          )
          .length,
      1,
    );
  });
}
