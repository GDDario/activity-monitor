import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recurring edit exposes separate occurrence window override', (
    tester,
  ) async {
    var id = 0;
    final taskId = TaskId('task');
    final draft = TaskDraft(
      taskId: taskId,
      occurrenceId: OccurrenceId('occ'),
      date: LocalDate(2024, 1, 1),
      cadence: TaskCadence.daily,
      recurrenceEnabled: true,
      expected: ExpectedRevisions(
        taskId: taskId,
        taskRevision: 0,
        occurrenceRevision: 0,
      ),
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
      find.text('Time window for this occurrence'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Time window for this occurrence'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('changing a new task date updates its schedule start', (
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
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskEditorSheet(model: model)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Scheduled date'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Scheduled date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(model.state.draft.startDate, LocalDate(2024, 1, 2));
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('recurring edits expose shared schedule start date', (
    tester,
  ) async {
    var id = 0;
    final taskId = TaskId('task');
    final draft = TaskDraft(
      taskId: taskId,
      occurrenceId: OccurrenceId('occ'),
      date: LocalDate(2024, 1, 1),
      cadence: TaskCadence.daily,
      recurrenceEnabled: true,
      expected: ExpectedRevisions(
        taskId: taskId,
        taskRevision: 0,
        occurrenceRevision: 0,
      ),
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
      find.text('Shared schedule defaults'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Shared schedule defaults'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('disabling window clears its validation error', (tester) async {
    var id = 0;
    final draft = TaskDraft.newTask(
      date: LocalDate(2024, 1, 1),
      newId: () => '${id++}',
    ).copyWith(timeWindow: TimeWindow(540, 600));
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
    model.setInputError('timeWindow', 'invalid');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Specific time window'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Specific time window'));
    await tester.pump();
    expect(model.state.fieldErrors.containsKey('timeWindow'), isFalse);
    expect(model.state.draft.timeWindow, isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
