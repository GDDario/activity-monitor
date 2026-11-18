import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';

void main() {
  for (final locale in const [Locale('en', 'US'), Locale('pt', 'BR')]) {
    for (final largeText in [false, true]) {
      testWidgets(
        'create editor follows Stitch structure in $locale, large text $largeText',
        (tester) async {
          tester.view.physicalSize = largeText
              ? const Size(320, 800)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var nextId = 0;
          final model = TaskEditorViewModel(
            draft: TaskDraft.newTask(
              date: LocalDate(2026, 11, 17),
              newId: () => 'design-${nextId++}',
            ),
            newId: () => 'design-${nextId++}',
            validate: validateTaskDraft,
            save: (_) async =>
                throw StateError('Opening the editor must not save'),
          );
          addTearDown(model.dispose);
          final l = TaskLocalizations(locale);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
              localizationsDelegates: const [
                TaskLocalizationsDelegate(),
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: ActivityTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => TaskEditorSheet.show(context, model),
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
          expect(
            find.text(l.text('personalTask').toUpperCase()),
            findsOneWidget,
          );
          expect(find.text(l.text('createTask')), findsNWidgets(2));
          final title = find.widgetWithText(TextField, l.text('title'));
          expect(
            Theme.of(tester.element(title))
                .inputDecorationTheme
                .floatingLabelBehavior,
            FloatingLabelBehavior.always,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, l.text('createTask')),
                )
                .onPressed,
            isNull,
          );
          final priority = largeText
              ? find.byType(ChoiceChip)
              : find.byType(SegmentedButton<TaskPriority>);
          await Scrollable.ensureVisible(
            tester.element(
              find.descendant(
                of: priority,
                matching: find.text(l.text('high')),
              ),
            ),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          if (largeText) {
            final selected = tester.widget<ChoiceChip>(
              find.byKey(const ValueKey('priority-low')),
            );
            expect(selected.selected, true);
            expect(selected.selectedColor, ActivityColors.surface);
          } else {
            final control = tester.widget<SegmentedButton<TaskPriority>>(
              priority,
            );
            expect(control.selected, {TaskPriority.low});
            expect(control.showSelectedIcon, false);
            expect(
              control.style?.backgroundColor?.resolve({WidgetState.selected}),
              Colors.transparent,
            );
            final selectedPill = tester.widget<Container>(
              find.byKey(const ValueKey('priority-low')),
            );
            final decoration = selectedPill.decoration! as BoxDecoration;
            expect(decoration.color, ActivityColors.surface);
            expect(decoration.borderRadius, BorderRadius.circular(24));
          }
          expect(
            find.descendant(of: priority, matching: find.byIcon(Icons.circle)),
            findsNWidgets(3),
          );
          await tester.tap(
            find.descendant(of: priority, matching: find.text(l.text('high'))),
          );
          await tester.pumpAndSettle();
          expect(model.state.draft.priority, TaskPriority.high);
          expect(model.state.draft.date, LocalDate(2026, 11, 17));
          model.addTag('Focus');
          await tester.pumpAndSettle();
          final chip = tester.widget<InputChip>(
            find.widgetWithText(InputChip, '#Focus'),
          );
          expect(chip.backgroundColor, ActivityColors.primaryContainer);
          expect(chip.labelStyle?.color, Colors.white);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
