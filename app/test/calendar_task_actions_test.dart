import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';

void main() {
  for (final floating in [true, false]) {
    testWidgets(
      'Calendar ${floating ? 'floating' : 'header'} action creates on its selected date',
      (tester) async {
        final selected = DateTime(2024, 2, 29);
        final model = CalendarViewModel(
          selected,
          () async => const CalendarData([], []),
        );
        await model.load();
        addTearDown(model.dispose);
        LocalDate? requested;
        var id = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              calendarViewModelProvider.overrideWith((ref) => model),
              taskEditorFactoryProvider.overrideWithValue((request) async {
                requested = request.date;
                return TaskEditorViewModel(
                  draft: TaskDraft.newTask(
                    date: request.date,
                    newId: () => 'id-${id++}',
                  ),
                  newId: () => 'id-${id++}',
                  validate: validateTaskDraft,
                  save: (_) async => TaskError(
                    TaskFailure(TaskFailureCode.storageUnavailable),
                  ),
                );
              }),
            ],
            child: const MaterialApp(home: CalendarView()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FloatingActionButton, 'Create task'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Create task'),
          findsOneWidget,
        );
        expect(find.widgetWithText(OutlinedButton, 'Today'), findsNothing);
        await tester.tap(
          find.widgetWithText(
            floating ? FloatingActionButton : OutlinedButton,
            'Create task',
          ),
        );
        await tester.pumpAndSettle();
        expect(requested, LocalDate(2024, 2, 29));
        expect(find.text('Task title'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(model.calendar.selected, selected);
      },
    );
  }
}
