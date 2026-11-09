import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/activity_monitor_app.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';

import 'helpers/fake_task_repository.dart';

void main() {
  testWidgets(
    'capture, completion, cross-screen Undo and filters share committed state',
    (tester) async {
      final repo = FakeTaskRepository();
      addTearDown(repo.dispose);
      final now = DateTime(2026, 11, 7, 12);
      var nextId = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseInitializationProvider.overrideWith(
              (ref) async => 'unused',
            ),
            taskRepositoryProvider.overrideWith((ref) async => repo),
            taskClockProvider.overrideWithValue(() => now),
            taskIdGeneratorProvider.overrideWithValue(
              () => 'workflow-${nextId++}',
            ),
            calendarDataProvider.overrideWith(
              (ref) async => CalendarData([
                for (final occurrence in repo.occurrences.values)
                  if (!occurrence.isDeleted)
                    CalendarEntry(
                      id: occurrence.id.value,
                      title: repo.tasks[occurrence.taskId]!.title.value,
                      date: DateTime(
                        occurrence.effectiveDate.year,
                        occurrence.effectiveDate.month,
                        occurrence.effectiveDate.day,
                      ),
                      cadence: CalendarCadence.oneTime,
                      participantIds: const [],
                      isDone: occurrence.completed,
                      taskAggregate: repo.aggregate(occurrence),
                    ),
              ], const []),
            ),
          ],
          child: const ActivityMonitorApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task title'),
        'Reading journal',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TaskEditorSheet),
          matching: find.widgetWithText(FilledButton, 'Create task'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.tasks.values.single.title.value, 'Reading journal');
      expect(find.text('Reading journal'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Mark done'));
      await tester.tap(find.byTooltip('Mark done'));
      await tester.pumpAndSettle();
      expect(repo.occurrences.values.single.completed, true);
      expect(find.text('Task marked as completed'), findsOneWidget);
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(find.text('Task marked as completed'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.occurrences.values.single.completed, false);
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared'));
      await tester.pumpAndSettle();
      expect(find.text('Reading journal'), findsNothing);
      await tester.tap(find.text('All activities'));
      await tester.pumpAndSettle();
      expect(find.text('Reading journal'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test(
    'requested-range schedule edits and tombstones survive storage reopening',
    () async {
      final scratch = Directory('../.scratches')..createSync(recursive: true);
      final directory = scratch.createTempSync('task-workflow-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/activity_monitor.db';
      initializeDatabaseAtPath(path);
      var repo = LocalTaskRepository(TaskDatabase(path: path));
      var next = 0;
      String id() => 'workflow-${next++}';
      final today = LocalDate(2026, 11, 7);
      final range = LocalDateRange(today, today.addDays(3));
      DateTime clock() => DateTime(2026, 11, 7, 12);
      final draft = TaskDraft.newTask(date: today, newId: id).copyWith(
        title: 'Persisted rhythm',
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
      );
      final created = (await SaveTask(
        repo,
        newId: id,
        clock: clock,
      ).execute(draft, requestedRange: range)).value!.aggregate;
      final edited = (await SaveTask(repo, newId: id, clock: clock).execute(
        TaskDraft.fromAggregate(created)
            .copyWith(cadence: TaskCadence.weekly, weeklyDays: WeeklyDays(1)),
        requestedRange: range,
      )).value!.aggregate;
      expect(edited.history, hasLength(1));
      final monday = (await repo.loadRange(range)).value!
          .where(
            (a) =>
                a.task.id == created.task.id &&
                a.occurrence.scheduledDate == today.addDays(2),
          )
          .single;
      expect(
        (await DeleteTaskOccurrence(
          repo,
          now: clock,
        ).execute(monday.occurrence.id, monday.expected)).isSuccess,
        true,
      );
      await repo.dispose();
      repo = LocalTaskRepository(TaskDatabase(path: path));
      addTearDown(repo.dispose);
      final reopened = await EnsureTaskOccurrences(
        repo,
        newId: id,
      ).execute(range);
      expect(reopened.isSuccess, true);
      final own = reopened.value!
          .where((a) => a.task.id == created.task.id)
          .toList();
      expect(own.map((a) => a.occurrence.scheduledDate), [today]);
      expect(own.single.history, hasLength(1));
      expect(own.single.task.schedule.cadence, TaskCadence.weekly);
    },
  );
}
