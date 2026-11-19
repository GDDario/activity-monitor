import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/app/dependencies/notification_dependencies.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';

import 'helpers/profile_ready.dart';
import 'helpers/fake_notification_service.dart';

Future<void> eventually(bool Function() condition) async {
  for (var i = 0; i < 300; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Committed notification state did not converge');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real SQLite commits completion Undo postpone delete and notification taps reconcile', () async {
    final dir = Directory.systemTemp.createTempSync('notification-workflow');
    final service = FakeNotificationService();
    final now = DateTime.utc(2026, 11, 18, 12);
    final container = ProviderContainer(
      overrides: [
        ...profileReadyOverrides(),
        databaseDirectoryProvider.overrideWithValue(() async => dir),
        taskClockProvider.overrideWithValue(() => now),
        localNotificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.tapsController.close();
      dir.deleteSync(recursive: true);
    });
    final model = await container.read(notificationViewModelProvider.future);
    await model.refresh();
    await model.enable(true);
    final repo = await container.read(taskRepositoryProvider.future);
    var id = 0;
    final save = SaveTask(
      repo,
      newId: () => 'notification-${++id}',
      clock: () => now,
    );
    final draft =
        TaskDraft.newTask(
          date: LocalDate(2026, 11, 18),
          newId: () => 'notification-${++id}',
        ).copyWith(
          title: 'Read a real local task',
          timeWindow: TimeWindow(13 * 60, 14 * 60),
          reminder: ReminderPreference(15),
        );
    final created = await save.execute(draft);
    expect(created.isSuccess, true);
    await eventually(() => model.snapshot?.queued.length == 1 && !model.busy);
    final first = model.snapshot!.queued.single;
    expect(first.fireAt, DateTime.utc(2026, 11, 18, 12, 45));
    final nativeId = service.pending.single;
    final loaded = (await repo.loadTask(
      draft.taskId,
      draft.occurrenceId,
    )).value!;
    final writesBeforeFailure = service.writes;
    final invalid = await save.execute(
      TaskDraft.fromAggregate(loaded).copyWith(title: ''),
    );
    expect(invalid.isSuccess, false);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.writes, writesBeforeFailure);
    final completed = await CompleteTaskOccurrence(
      repo,
      now: () => now,
    ).execute(draft.occurrenceId, loaded.expected);
    expect(completed.isSuccess, true);
    await eventually(() => service.pending.isEmpty && !model.busy);
    expect(
      (await UndoTaskOccurrenceAction(repo).execute(completed.value!.undo!))
          .isSuccess,
      true,
    );
    await eventually(() => service.pending.contains(nativeId) && !model.busy);
    final restored = (await repo.loadTask(
      draft.taskId,
      draft.occurrenceId,
    )).value!;
    final postponed = await PostponeTaskOccurrence(
      repo,
      now: () => now,
    ).execute(draft.occurrenceId, restored.expected);
    expect(postponed.isSuccess, true);
    await eventually(
      () =>
          model.snapshot!.queued.single.date == LocalDate(2026, 11, 19) &&
          !model.busy,
    );
    service.tapsController.add(
      first.payload,
    ); // A stale payload uses the current effective date.
    await eventually(
      () =>
          container.read(calendarViewModelProvider).calendar.selected ==
          DateTime(2026, 11, 19),
    );
    final moved = (await repo.loadTask(
      draft.taskId,
      draft.occurrenceId,
    )).value!;
    expect(
      (await DeleteTaskOccurrence(
        repo,
        now: () => now,
      ).execute(draft.occurrenceId, moved.expected)).isSuccess,
      true,
    );
    await eventually(() => service.pending.isEmpty && !model.busy);
    final before = container.read(calendarViewModelProvider).calendar.selected;
    service.tapsController.add(first.payload);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(container.read(calendarViewModelProvider).calendar.selected, before);
    await model.enable(false);
    expect(model.snapshot!.availability, ReminderAvailability.off);
  });
  test('real recurring schedules replenish the bounded native queue after completion', () async {
    final dir = Directory.systemTemp.createTempSync('notification-recurrence');
    final service = FakeNotificationService();
    final now = DateTime.utc(2026, 11, 18, 12);
    final container = ProviderContainer(
      overrides: [
        ...profileReadyOverrides(),
        databaseDirectoryProvider.overrideWithValue(() async => dir),
        taskClockProvider.overrideWithValue(() => now),
        localNotificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.tapsController.close();
      dir.deleteSync(recursive: true);
    });
    final model = await container.read(notificationViewModelProvider.future);
    await model.refresh();
    final repo = await container.read(taskRepositoryProvider.future);
    var id = 0;
    final save = SaveTask(
      repo,
      newId: () => 'recurrence-${++id}',
      clock: () => now,
    );
    for (var i = 0; i < 3; i++) {
      final draft =
          TaskDraft.newTask(
            date: LocalDate(2026, 11, 18),
            newId: () => 'recurrence-${++id}',
          ).copyWith(
            title: 'Daily reminder $i',
            cadence: TaskCadence.daily,
            recurrenceEnabled: true,
            timeWindow: TimeWindow(13 * 60, 14 * 60),
            reminder: ReminderPreference(15),
          );
      expect((await save.execute(draft)).isSuccess, true);
    }
    await model.enable(true);
    await eventually(() => !model.busy && model.snapshot!.queued.length == 64);
    final before = model.snapshot!.queued.map((r) => r.occurrenceId).toSet();
    final first = model.snapshot!.queued.first;
    final loaded = (await repo.loadTask(
      TaskId(first.taskId),
      OccurrenceId(first.occurrenceId),
    )).value!;
    expect(
      (await CompleteTaskOccurrence(
        repo,
        now: () => now,
      ).execute(loaded.occurrence.id, loaded.expected)).isSuccess,
      true,
    );
    await eventually(
      () =>
          !model.busy &&
          model.snapshot!.queued.length == 64 &&
          !model.snapshot!.queued.any(
            (r) => r.occurrenceId == first.occurrenceId,
          ),
    );
    final after = model.snapshot!.queued.map((r) => r.occurrenceId).toSet();
    expect(after.difference(before).length, 1);
    expect(service.pending.length, 64);
  });
}
