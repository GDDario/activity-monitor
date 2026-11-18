import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/database_dependencies.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/data/repositories/task_repository.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/use_cases/calculate_daily_streak.dart';
import 'package:app/domain/use_cases/check_task_overlap.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/reopen_task_occurrence.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';

final taskClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final taskIdGeneratorProvider = Provider<String Function()>(
  (ref) => ref.watch(uuidProvider).v7,
);
final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  final repo = LocalTaskRepository(TaskDatabase(path: path));
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
});
final taskChangesProvider = StreamProvider<TaskChange>((ref) async* {
  final repository = await ref.watch(taskRepositoryProvider.future);
  yield* repository.changes;
});

final ensureTaskRangeProvider =
    Provider<Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange)>(
      (ref) => (range) async {
        final repo = await ref.read(taskRepositoryProvider.future);
        return EnsureTaskOccurrences(
          repo,
          newId: ref.read(taskIdGeneratorProvider),
        ).execute(range);
      },
    );

final taskStreakLoaderProvider =
    Provider<
      Future<TaskResult<Map<TaskId, int>>> Function(Set<TaskId>, LocalDate)
    >(
      (ref) => (ids, today) async {
        if (ids.isEmpty) return const TaskSuccess({});
        final repo = await ref.read(taskRepositoryProvider.future);
        final result = await repo.loadStreakHistory(ids, today);
        if (!result.isSuccess) return TaskError(result.failure!);
        final calculator = CalculateDailyStreak();
        final counts = <TaskId, int>{};
        for (final history in result.value!) {
          final count = calculator.execute(history, today);
          if (count != null) counts[history.snapshot.task.id] = count;
        }
        return TaskSuccess(counts);
      },
    );

final taskActionsViewModelProvider = Provider<TaskActionsViewModel>((ref) {
  final clock = ref.read(taskClockProvider);
  final model = TaskActionsViewModel(
    commands: {
      TaskAction.complete: (id, expected) async => CompleteTaskOccurrence(
        await ref.read(taskRepositoryProvider.future),
        now: clock,
      ).execute(id, expected),
      TaskAction.reopen: (id, expected) async => ReopenTaskOccurrence(
        await ref.read(taskRepositoryProvider.future),
        now: clock,
      ).execute(id, expected),
      TaskAction.postpone: (id, expected) async => PostponeTaskOccurrence(
        await ref.read(taskRepositoryProvider.future),
        now: clock,
      ).execute(id, expected),
      TaskAction.delete: (id, expected) async => DeleteTaskOccurrence(
        await ref.read(taskRepositoryProvider.future),
        now: clock,
      ).execute(id, expected),
    },
    undo: (snapshot) async =>
        UndoTaskOccurrenceAction(await ref.read(taskRepositoryProvider.future))
            .execute(snapshot),
  );
  ref.onDispose(model.dispose);
  return model;
});

class TaskEditorRequest {
  const TaskEditorRequest({
    required this.date,
    this.taskId,
    this.occurrenceId,
    this.range,
  });
  final LocalDate date;
  final TaskId? taskId;
  final OccurrenceId? occurrenceId;
  final LocalDateRange? range;
}

final taskEditorFactoryProvider =
    Provider<Future<TaskEditorViewModel> Function(TaskEditorRequest)>(
      (ref) => (request) async {
        final repo = await ref.read(taskRepositoryProvider.future);
        final newId = ref.read(taskIdGeneratorProvider);
        final save = SaveTask(
          repo,
          newId: newId,
          clock: ref.read(taskClockProvider),
        );
        final overlap = CheckTaskOverlap(
          repo,
          ensure: ref.read(ensureTaskRangeProvider),
        );
        final model = TaskEditorViewModel(
          draft: TaskDraft.newTask(date: request.date, newId: newId),
          newId: newId,
          validate: validateTaskDraft,
          save: (draft) => save.execute(draft, requestedRange: request.range),
          checkOverlap: overlap.execute,
          load: repo.loadTask,
        );
        if (request.taskId != null && request.occurrenceId != null) {
          await model.loadExisting(request.taskId!, request.occurrenceId!);
        }
        return model;
      },
    );

final todayViewModelProvider = Provider.autoDispose<TodayViewModel>((ref) {
  final model = TodayViewModel(
    clock: ref.read(taskClockProvider),
    load: ref.read(ensureTaskRangeProvider),
    loadStreaks: ref.read(taskStreakLoaderProvider),
  );
  ref.listen(taskChangesProvider, (_, value) {
    value.whenData((_) => unawaited(model.load()));
  });
  final lifecycle = AppLifecycleListener(onResume: model.refreshForLocalDay);
  ref.onDispose(() {
    lifecycle.dispose();
    model.dispose();
  });
  unawaited(model.load());
  return model;
});
