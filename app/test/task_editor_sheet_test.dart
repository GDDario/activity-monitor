import 'dart:async';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dirty editor prompts before discarding', (tester) async {
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Changed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('back cannot dismiss during save', (tester) async {
    var id = 0;
    final saving = Completer<TaskResult<TaskSaveResult>>();
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) => saving.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task').last);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Saving your task…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('dirty backdrop requests discard confirmation', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Discard your unsaved changes?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('dirty sheet drag asks before discarding', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.drag(
      find.byKey(const ValueKey('editorDragHandle')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard your unsaved changes?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('editor footer remains above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final footer = tester.getRect(
      find.widgetWithText(FilledButton, 'Create task'),
    );
    expect(footer.bottom, lessThanOrEqualTo(500));
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('save validation focuses the first invalid field', (
    tester,
  ) async {
    var id = 0;
    var invalid = false;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => invalid ? {'title': 'invalid'} : {},
      save: (_) async {
        invalid = true;
        return TaskError(TaskFailure(TaskFailureCode.validation));
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditorSheet.show(context, model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('failed existing load shows unavailable and locks editing', (
    tester,
  ) async {
    var id = 0;
    final model = TaskEditorViewModel(
      draft: TaskDraft.newTask(
        date: LocalDate(2024, 1, 1),
        newId: () => '${id++}',
      ),
      newId: () => '${id++}',
      validate: (_) => {},
      save: (_) async => throw StateError('unused'),
      load: (_, _) async => TaskError(TaskFailure(TaskFailureCode.notFound)),
    );
    await model.loadExisting(TaskId('missing'), OccurrenceId('missing'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskEditorSheet(model: model)),
      ),
    );
    expect(find.text('This task is no longer available.'), findsOneWidget);
    expect(
      tester
          .widget<AbsorbPointer>(
            find
                .descendant(
                  of: find.byType(TaskEditorSheet),
                  matching: find.byType(AbsorbPointer),
                )
                .first,
          )
          .absorbing,
      isTrue,
    );
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, false);
    }
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
