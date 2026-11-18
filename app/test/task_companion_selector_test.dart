import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/widgets/task_companion_selector.dart';

void main() {
  testWidgets(
    'companion selection is explicit and failed choices preserve membership',
    (tester) async {
      var failure = false;
      final model = TaskEditorViewModel(
        draft: TaskDraft.newTask(
          date: LocalDate(2026, 11, 18),
          newId: () => 'test',
        ).copyWith(title: 'Walk'),
        newId: () => 'test',
        validate: validateTaskDraft,
        save: (_) async =>
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
        loadPeople: () async => failure
            ? const PeopleResult.error(PeopleFailure.storageUnavailable)
            : PeopleResult.success(
                PeopleSnapshot(
                  people: [Person(id: 'p', name: 'Ana')],
                ),
              ),
      );
      addTearDown(model.dispose);
      await model.refreshPeople();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: model,
              builder: (_, _) => TaskCompanionSelector(model: model),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Ana'));
      await tester.pump();
      expect(model.state.draft.participants!.single.id, 'p');
      failure = true;
      await model.refreshPeople();
      await tester.pump();
      expect(find.text('Reload choices'), findsOneWidget);
      expect(model.state.draft.participants!.single.id, 'p');
    },
  );
}
