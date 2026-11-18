import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/activity_monitor_app.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';

import 'helpers/fake_profile_repository.dart';
import 'helpers/fake_task_repository.dart';
import 'helpers/fake_people_repository.dart';

import 'package:app/app/dependencies/people_dependencies.dart';
import 'package:app/app/dependencies/people_repository_dependencies.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/domain/models/daily_overview.dart';

import 'helpers/home_fixture.dart';

void main() {
  testWidgets(
    'preferences preserve router Calendar selection draft and shared Undo',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = FakeProfileRepository(profile: exampleProfile()),
          tasks = FakeTaskRepository();
      addTearDown(profiles.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      final a = homeTask('pending');
      final receipt = TaskMutationReceipt(
        taskId: a.task.id,
        occurrenceId: a.occurrence.id,
        taskRevision: 0,
        occurrenceRevision: 1,
        affectedDates: {homeDay},
        undo: TaskUndoSnapshot(
          before: a.occurrence,
          expected: ExpectedRevisions(
            taskId: a.task.id,
            taskRevision: 0,
            occurrenceRevision: 1,
          ),
        ),
      );
      final actions = TaskActionsViewModel(
        commands: {TaskAction.complete: (_, _) async => TaskSuccess(receipt)},
        undo: (_) async => TaskSuccess(receipt),
        elapsed: () => Duration.zero,
      );
      addTearDown(actions.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseInitializationProvider.overrideWith(
              (ref) async => 'unused',
            ),
            profileRepositoryProvider.overrideWith((ref) async => profiles),
            taskRepositoryProvider.overrideWith((ref) async => tasks),
            peopleRepositoryProvider.overrideWith(
              (ref) async => FakePeopleRepository(
                PeopleSnapshot(
                  people: [
                    Person(
                      id: 'a',
                      name: 'Ana',
                      categories: {PersonCategory.work},
                    ),
                  ],
                ),
              ),
            ),
            calendarDataProvider.overrideWith(
              (ref) async => const CalendarData([], []),
            ),
            taskActionsViewModelProvider.overrideWithValue(actions),
          ],
          child: const ActivityMonitorApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ActivityMonitorApp)),
      );
      final today = container.read(todayViewModelProvider);
      today.setScope(const DailyTaskScope.solo());
      final people = await container.read(peopleViewModelProvider.future);
      await tester.pumpAndSettle();
      people.setQuery('ana');
      people.setFilter('work');
      final router = container.read(appRouterProvider);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      final calendar = container.read(calendarViewModelProvider);
      calendar.selectDate(DateTime(2026, 12, 4));
      calendar.setWeekMode(true);
      await tester.pumpAndSettle();
      await actions.perform(TaskAction.complete, a);
      await tester.pump();
      var next = 0;
      final editor = TaskEditorViewModel(
        draft: TaskDraft.newTask(
          date: homeDay,
          newId: () => 'draft-${next++}',
        ).copyWith(title: 'Do not lose this draft'),
        newId: () => 'draft-${next++}',
        validate: validateTaskDraft,
        save: (_) async =>
            TaskError(TaskFailure(TaskFailureCode.storageUnavailable)),
      );
      addTearDown(editor.dispose);
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(TaskEditorSheet.show(context, editor));
      await tester.pumpAndSettle();
      container
          .read(profileSessionProvider)
          .accept(
            LocalProfile(
              id: 'profile',
              name: ProfileName('Robin Ward'),
              appearance: ProfileAppearance.dark,
              language: ProfileLanguage.ptBr,
              revision: 1,
            ),
          );
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider), same(router));
      expect(container.read(calendarViewModelProvider), same(calendar));
      expect(calendar.calendar.selected, DateTime(2026, 12, 4));
      expect(calendar.calendar.weekMode, true);
      expect(actions.canUndo, true);
      expect(container.read(todayViewModelProvider), same(today));
      expect(today.state.scope, const DailyTaskScope.solo());
      expect(
        await container.read(peopleViewModelProvider.future),
        same(people),
      );
      expect(people.state.query, 'ana');
      expect(people.state.filter, 'work');
      expect(find.byType(TaskEditorSheet), findsOneWidget);
      expect(editor.state.draft.title, 'Do not lose this draft');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Localizations.localeOf(tester.element(find.byType(TaskEditorSheet))),
        const Locale('pt', 'BR'),
      );
      Navigator.of(tester.element(find.byType(TaskEditorSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendário'));
      await tester.pumpAndSettle();
      expect(
        container.read(calendarViewModelProvider).calendar.selected,
        DateTime(2026, 12, 4),
      );
      expect(container.read(calendarViewModelProvider).calendar.weekMode, true);
    },
  );
}
