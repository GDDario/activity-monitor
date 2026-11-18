import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/widgets/task_undo_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('successful deletion offers undo', (tester) async {
    final date = LocalDate(2024, 1, 1),
        id = TaskId('task'),
        occurrenceId = OccurrenceId('occ');
    final occurrence = TaskOccurrence(
      id: occurrenceId,
      taskId: id,
      scheduledDate: date,
      effectiveDate: date,
    );
    final aggregate = TaskAggregate(
      task: Task(
        id: id,
        title: TaskTitle('A'),
        schedule: TaskSchedule(
          cadence: TaskCadence.oneTime,
          recurrenceEnabled: false,
          startDate: date,
        ),
      ),
      occurrence: occurrence,
    );
    final snapshot = TaskUndoSnapshot(
      before: occurrence,
      expected: aggregate.expected,
    );
    final actions = TaskActionsViewModel(
      commands: {
        TaskAction.delete: (_, _) async => TaskSuccess(
          TaskMutationReceipt(
            taskId: id,
            occurrenceId: occurrenceId,
            taskRevision: 0,
            occurrenceRevision: 1,
            affectedDates: {date},
            undo: snapshot,
          ),
        ),
      },
      undo: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskUndoBanner(model: actions)),
      ),
    );
    await actions.perform(TaskAction.delete, aggregate);
    await tester.pump();
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    actions.dispose();
  });
}
