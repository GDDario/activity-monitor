import 'package:app/ui/core/theme/activity_theme.dart';
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
  for (final largeText in [false, true]) {
    testWidgets(
      'successful deletion offers readable undo, large text $largeText',
      (tester) async {
        tester.view.physicalSize = largeText
            ? const Size(320, 800)
            : const Size(800, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
            theme: ActivityTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(body: TaskUndoBanner(model: actions)),
          ),
        );
        await actions.perform(TaskAction.delete, aggregate);
        await tester.pump();
        expect(find.text('Task deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        final label = tester.widget<RichText>(
          find.descendant(
            of: find.widgetWithText(TextButton, 'Undo'),
            matching: find.byType(RichText),
          ),
        );
        final foreground = label.text.style!.color!.computeLuminance();
        final background = const Color(0xff2e312f).computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        if (largeText) {
          final message = tester.getRect(find.text('Task deleted'));
          final action = tester.getRect(
            find.widgetWithText(TextButton, 'Undo'),
          );
          expect(message.width, greaterThanOrEqualTo(256));
          expect(action.top, greaterThanOrEqualTo(message.bottom));
        }
        actions.dispose();
      },
    );
  }
}
