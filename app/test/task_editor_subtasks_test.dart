import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('checklist supports dragging to reorder', (tester) async {
    var id = 0;
    final draft =
        TaskDraft.newTask(
          date: LocalDate(2024, 1, 1),
          newId: () => '${id++}',
        ).copyWith(
          subtasks: [
            DraftSubtask(id: SubtaskId('a'), title: 'First'),
            DraftSubtask(id: SubtaskId('b'), title: 'Second'),
          ],
        );
    final model = TaskEditorViewModel(
      draft: draft,
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskEditorSheet(model: model)),
      ),
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.drag_handle).first,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    expect(model.state.draft.subtasks.first.title, 'Second');
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('empty subtask displays validation guidance', (tester) async {
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: validateTaskDraft,
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskEditorSheet(model: model)),
      ),
    );
    model.addSubtask();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Check the highlighted fields.'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Check the highlighted fields.'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('checklist fits narrow layouts with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var id = 0;
    final draft =
        TaskDraft.newTask(
          date: LocalDate(2024, 1, 1),
          newId: () => '${id++}',
        ).copyWith(
          subtasks: [DraftSubtask(id: SubtaskId('a'), title: 'First')],
        );
    final model = TaskEditorViewModel(
      draft: draft,
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: TaskEditorSheet(model: model)),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.drag_handle),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
