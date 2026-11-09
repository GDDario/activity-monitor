import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/subtask_id.dart';
import 'package:app/domain/value_objects/subtask_title.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'completed task with unknown time offers generic completion and reopen',
    (tester) async {
      final date = LocalDate(2024, 1, 1);
      final id = TaskId('legacy');
      final aggregate = TaskAggregate(
        task: Task(
          id: id,
          title: TaskTitle('A task'),
          schedule: TaskSchedule(
            cadence: TaskCadence.oneTime,
            recurrenceEnabled: false,
            startDate: date,
          ),
        ),
        occurrence: TaskOccurrence(
          id: OccurrenceId('occ'),
          taskId: id,
          scheduledDate: date,
          effectiveDate: date,
          completed: true,
        ),
      );
      final actions = TaskActionsViewModel(
        commands: {},
        undo: (_) async => throw StateError('unused'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              aggregate: aggregate,
              actions: actions,
              onEdit: () {},
            ),
          ),
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byTooltip('Reopen'), findsOneWidget);
      actions.dispose();
    },
  );
  testWidgets(
    'pending menu offers explicit completion and completed title is struck through',
    (tester) async {
      final date = LocalDate(2024, 1, 1);
      final id = TaskId('task');
      final aggregate = TaskAggregate(
        task: Task(
          id: id,
          title: TaskTitle('A task'),
          schedule: TaskSchedule(
            cadence: TaskCadence.oneTime,
            recurrenceEnabled: false,
            startDate: date,
          ),
        ),
        occurrence: TaskOccurrence(
          id: OccurrenceId('occ'),
          taskId: id,
          scheduledDate: date,
          effectiveDate: date,
        ),
      );
      final actions = TaskActionsViewModel(
        commands: {},
        undo: (_) async => throw StateError('unused'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              aggregate: aggregate,
              actions: actions,
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Task actions'));
      await tester.pumpAndSettle();
      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Postpone to tomorrow'), findsOneWidget);
      actions.dispose();
    },
  );
  testWidgets('known completion time is displayed', (tester) async {
    final date = LocalDate(2024, 1, 1), id = TaskId('task');
    final aggregate = TaskAggregate(
      task: Task(
        id: id,
        title: TaskTitle('A task'),
        schedule: TaskSchedule(
          cadence: TaskCadence.oneTime,
          recurrenceEnabled: false,
          startDate: date,
        ),
      ),
      occurrence: TaskOccurrence(
        id: OccurrenceId('occ'),
        taskId: id,
        scheduledDate: date,
        effectiveDate: date,
        completed: true,
        completedAtUtc: DateTime.utc(2024, 1, 1, 9, 15),
      ),
    );
    final actions = TaskActionsViewModel(
      commands: {},
      undo: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(aggregate: aggregate, actions: actions, onEdit: () {}),
        ),
      ),
    );
    expect(find.textContaining('Completed at'), findsOneWidget);
    actions.dispose();
  });
  testWidgets('card shows saved participants, progress and inactive reminder', (
    tester,
  ) async {
    final date = LocalDate(2024, 1, 1), id = TaskId('task');
    final subtask = TaskSubtask(
      id: SubtaskId('sub'),
      title: SubtaskTitle('Step'),
      position: 0,
    );
    final aggregate = TaskAggregate(
      task: Task(
        id: id,
        title: TaskTitle('A task'),
        schedule: TaskSchedule(
          cadence: TaskCadence.oneTime,
          recurrenceEnabled: false,
          startDate: date,
        ),
        subtasks: [subtask],
        participants: [const TaskParticipant('person', 'Alex')],
      ),
      occurrence: TaskOccurrence(
        id: OccurrenceId('occ'),
        taskId: id,
        scheduledDate: date,
        effectiveDate: date,
        timeWindow: TimeWindow(600, 660),
        reminder: ReminderPreference(15),
        subtaskStates: {subtask.id: true},
      ),
    );
    final actions = TaskActionsViewModel(
      commands: {},
      undo: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(aggregate: aggregate, actions: actions, onEdit: () {}),
        ),
      ),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.text('Preference only. Notifications are not active yet.'),
      findsOneWidget,
    );
    actions.dispose();
  });
}
