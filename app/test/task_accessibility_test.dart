import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';

import 'helpers/task_action_fixture.dart';

TaskEditorViewModel _editor() {
  var next = 0;
  return TaskEditorViewModel(
    draft: TaskDraft.newTask(
      date: LocalDate(2026, 11, 7),
      newId: () => 'editor-${next++}',
    ),
    newId: () => 'editor-${next++}',
    validate: (_) => {},
    save: (_) async => throw StateError('unused'),
  );
}

void main() {
  testWidgets(
    'Escape closes a clean editor and returns keyboard focus to its launcher',
    (tester) async {
      final model = _editor();
      final launcher = FocusNode(debugLabel: 'editor launcher');
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  focusNode: launcher,
                  onPressed: () => TaskEditorSheet.show(context, model),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        launcher.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorSheet), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorSheet), findsNothing);
        expect(launcher.hasFocus, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        launcher.dispose();
      }
    },
  );
  testWidgets(
    'Tab traversal stays within the editor instead of reaching its background launcher',
    (tester) async {
      final model = _editor();
      final launcher = FocusNode(debugLabel: 'background launcher');
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  focusNode: launcher,
                  onPressed: () => TaskEditorSheet.show(context, model),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .requestFocus();
        await tester.pump();
        for (var index = 0; index < 25; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            launcher.hasFocus,
            isFalse,
            reason: 'Tab $index must remain inside the modal',
          );
          final focusedContext = FocusManager.instance.primaryFocus?.context;
          expect(
            focusedContext?.findAncestorWidgetOfExactType<TaskEditorSheet>(),
            isNotNull,
            reason: 'Tab $index must focus an editor descendant',
          );
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        launcher.dispose();
      }
    },
  );
  testWidgets(
    'narrow cards with doubled text retain labels and 48-pixel explicit action targets without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = TaskActionFixture();
      final original = fixture.repository.aggregate(fixture.occurrence);
      final aggregate = TaskAggregate(
        task: Task(
          id: original.task.id,
          title: TaskTitle('A longer task title that wraps naturally'),
          schedule: original.task.schedule,
          tags: original.task.tags,
          subtasks: original.task.subtasks,
          participants: original.task.participants,
        ),
        occurrence: original.occurrence,
      );
      final actions = TaskActionsViewModel(
        commands: {},
        undo: (_) async => throw StateError('unused'),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskCard(
                    aggregate: aggregate,
                    actions: actions,
                    onEdit: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text('A longer task title that wraps naturally'),
          findsOneWidget,
        );
        expect(find.byTooltip('Mark done'), findsOneWidget);
        expect(find.byTooltip('Task actions'), findsOneWidget);
        final checkbox = tester.getSize(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == 'Mark done',
          ),
        );
        final menu = tester.getSize(find.byType(PopupMenuButton<String>));
        expect(checkbox.width, greaterThanOrEqualTo(48));
        expect(checkbox.height, greaterThanOrEqualTo(48));
        expect(menu.width, greaterThanOrEqualTo(48));
        expect(menu.height, greaterThanOrEqualTo(48));
      } finally {
        await tester.pumpWidget(const SizedBox());
        actions.dispose();
        await fixture.repository.dispose();
      }
    },
  );
}
