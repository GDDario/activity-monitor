import 'dart:async';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/widgets/swipe_task_card.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('release at 89 does not commit and 90 commits once', (
    tester,
  ) async {
    final date = LocalDate(2024, 1, 1), id = TaskId('task');
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
      occurrence: TaskOccurrence(
        id: OccurrenceId('occ'),
        taskId: id,
        scheduledDate: date,
        effectiveDate: date,
      ),
    );
    var calls = 0;
    final actions = TaskActionsViewModel(
      commands: {
        TaskAction.complete: (_, _) async {
          calls++;
          return TaskSuccess(
            TaskMutationReceipt(
              taskId: id,
              occurrenceId: OccurrenceId('occ'),
              taskRevision: 0,
              occurrenceRevision: 1,
              affectedDates: {date},
            ),
          );
        },
      },
      undo: (_) async => throw StateError('unused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwipeTaskCard(
              aggregate: aggregate,
              actions: actions,
              child: const SizedBox(width: 250, height: 100),
            ),
          ),
        ),
      ),
    );
    var gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipeTaskCard)),
    );
    await gesture.moveBy(const Offset(89, 0));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(calls, 0);
    gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipeTaskCard)),
    );
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(calls, 1);
    actions.dispose();
  });
  testWidgets(
    'left release at negative 89 reveals Delete without committing and negative 90 commits once',
    (tester) async {
      final fixture = _GestureFixture();
      try {
        await fixture.mount(tester);
        for (final distance in [-89.0, -90.0]) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(SwipeTaskCard)),
          );
          await gesture.moveBy(Offset(distance, 0));
          await tester.pump();
          expect(find.text('Delete'), findsOneWidget);
          expect(fixture.calls, isEmpty);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(
            fixture.calls,
            distance == -89 ? isEmpty : [TaskAction.delete],
          );
        }
      } finally {
        await fixture.close(tester);
      }
    },
  );
  testWidgets(
    'cancelling a threshold-crossing drag restores the card without a command',
    (tester) async {
      final fixture = _GestureFixture();
      try {
        await fixture.mount(tester);
        final resting = tester.getTopLeft(find.byKey(_foreground));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SwipeTaskCard)),
        );
        await gesture.moveBy(const Offset(120, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(_foreground)).dx,
          greaterThan(resting.dx),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(fixture.calls, isEmpty);
        expect(tester.getTopLeft(find.byKey(_foreground)), resting);
      } finally {
        await fixture.close(tester);
      }
    },
  );
  testWidgets(
    'vertical dragging scrolls the agenda without triggering a horizontal action',
    (tester) async {
      final fixture = _GestureFixture();
      final scroll = ScrollController();
      try {
        await fixture.mount(
          tester,
          body: ListView(
            controller: scroll,
            children: [
              SizedBox(height: 150, child: Center(child: fixture.swipe())),
              const SizedBox(height: 1500),
            ],
          ),
        );
        await tester.drag(find.byType(SwipeTaskCard), const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(fixture.calls, isEmpty);
      } finally {
        await fixture.close(tester);
        scroll.dispose();
      }
    },
  );
  testWidgets('right swipe on a completed occurrence is a no-op', (
    tester,
  ) async {
    final fixture = _GestureFixture(completed: true);
    try {
      await fixture.mount(tester);
      final resting = tester.getTopLeft(find.byKey(_foreground));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeTaskCard)),
      );
      await gesture.moveBy(const Offset(120, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.calls, isEmpty);
      expect(tester.getTopLeft(find.byKey(_foreground)), resting);
      expect(fixture.aggregate.occurrence.completed, isTrue);
    } finally {
      await fixture.close(tester);
    }
  });
  testWidgets(
    'checkbox and menu taps dispatch only their explicit actions without a swipe',
    (tester) async {
      final fixture = _GestureFixture();
      var edits = 0;
      try {
        await fixture.mount(
          tester,
          body: Center(
            child: SizedBox(
              width: 360,
              child: TaskCard(
                aggregate: fixture.aggregate,
                actions: fixture.actions,
                onEdit: () => edits++,
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Mark done'));
        await tester.pumpAndSettle();
        expect(fixture.calls, [TaskAction.complete]);
        await tester.tap(find.byTooltip('Task actions'));
        await tester.pumpAndSettle();
        expect(fixture.calls, [TaskAction.complete]);
        await tester.tap(find.text('Edit task'));
        await tester.pumpAndSettle();
        expect(edits, 1);
        expect(fixture.calls, [TaskAction.complete]);
        await tester.tap(find.byTooltip('Task actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(fixture.calls, [TaskAction.complete, TaskAction.delete]);
      } finally {
        await fixture.close(tester);
      }
    },
  );
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'storage failure leaves the same resting card with reduced motion $reducedMotion',
      (tester) async {
        final fixture = _GestureFixture(
          command: (_) async =>
              TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
        );
        try {
          await fixture.mount(tester, reducedMotion: reducedMotion);
          final resting = tester.getTopLeft(find.byKey(_foreground));
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(SwipeTaskCard)),
          );
          await gesture.moveBy(const Offset(-100, 0));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(fixture.calls, [TaskAction.delete]);
          expect(
            fixture.actions.failure!.code,
            TaskFailureCode.storageUnavailable,
          );
          expect(find.byKey(_foreground), findsOneWidget);
          expect(tester.getTopLeft(find.byKey(_foreground)), resting);
          expect(fixture.aggregate.occurrence.isDeleted, isFalse);
        } finally {
          await fixture.close(tester);
        }
      },
    );
  }
  testWidgets(
    'an unresolved swipe disables checkbox and menu and repeated swipes cannot replay the command',
    (tester) async {
      final pending = Completer<TaskResult<TaskMutationReceipt>>();
      final fixture = _GestureFixture(command: (_) => pending.future);
      try {
        await fixture.mount(
          tester,
          body: Center(
            child: SizedBox(
              width: 360,
              child: TaskCard(
                aggregate: fixture.aggregate,
                actions: fixture.actions,
                onEdit: () {},
              ),
            ),
          ),
        );
        final first = await tester.startGesture(
          tester.getCenter(find.text('A task')),
        );
        await first.moveBy(const Offset(100, 0));
        await first.up();
        await tester.pump();
        expect(
          fixture.actions.isPending(fixture.aggregate.occurrence.id),
          isTrue,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Mark done',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>),
              )
              .enabled,
          isFalse,
        );
        final second = await tester.startGesture(
          tester.getCenter(find.text('A task')),
        );
        await second.moveBy(const Offset(-100, 0));
        await second.up();
        await tester.pump();
        expect(fixture.calls, [TaskAction.complete]);
        pending.complete(TaskSuccess(fixture.receipt()));
        await tester.pumpAndSettle();
        expect(
          fixture.actions.isPending(fixture.aggregate.occurrence.id),
          isFalse,
        );
        expect(fixture.calls, [TaskAction.complete]);
      } finally {
        if (!pending.isCompleted) {
          pending.complete(
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
          );
        }
        await tester.pump();
        await fixture.close(tester);
      }
    },
  );
}

const _foreground = ValueKey('swipe-test-foreground');

class _GestureFixture {
  _GestureFixture({
    bool completed = false,
    Future<TaskResult<TaskMutationReceipt>> Function(TaskAction)? command,
  }) {
    final date = LocalDate(2024, 1, 1);
    final taskId = TaskId('gesture-task');
    aggregate = TaskAggregate(
      task: Task(
        id: taskId,
        title: TaskTitle('A task'),
        schedule: TaskSchedule(
          cadence: TaskCadence.oneTime,
          recurrenceEnabled: false,
          startDate: date,
        ),
      ),
      occurrence: TaskOccurrence(
        id: OccurrenceId('gesture-occurrence'),
        taskId: taskId,
        scheduledDate: date,
        effectiveDate: date,
        completed: completed,
      ),
    );
    actions = TaskActionsViewModel(
      commands: {
        for (final action in TaskAction.values)
          action: (id, expected) {
            calls.add(action);
            return command?.call(action) ??
                Future.value(TaskSuccess(receipt()));
          },
      },
      undo: (_) async => throw StateError('unused'),
      elapsed: () => Duration.zero,
    );
  }
  late final TaskAggregate aggregate;
  late final TaskActionsViewModel actions;
  final calls = <TaskAction>[];
  TaskMutationReceipt receipt() => TaskMutationReceipt(
    taskId: aggregate.task.id,
    occurrenceId: aggregate.occurrence.id,
    taskRevision: aggregate.task.revision,
    occurrenceRevision: aggregate.occurrence.revision + 1,
    affectedDates: {aggregate.occurrence.effectiveDate},
  );
  Widget swipe() => SwipeTaskCard(
    aggregate: aggregate,
    actions: actions,
    child: Container(
      key: _foreground,
      width: 250,
      height: 100,
      color: Colors.white,
    ),
  );
  Future<void> mount(
    WidgetTester tester, {
    Widget? body,
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: body ?? Center(child: swipe())),
      ),
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    actions.dispose();
  }
}
