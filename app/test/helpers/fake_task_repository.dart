import 'dart:async';

import 'package:app/data/repositories/task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

class FakeTaskRepository implements TaskRepository {
  final Map<TaskId, Task> tasks = {};
  final Map<TaskId, List<SchedulePeriod>> histories = {};
  final Map<OccurrenceId, TaskOccurrence> occurrences = {};
  final _changes = StreamController<TaskChange>.broadcast(sync: true);
  TaskFailure? failNext;
  int saves = 0;
  @override
  Stream<TaskChange> get changes => _changes.stream;
  TaskError<T>? _failure<T>() {
    final failure = failNext;
    failNext = null;
    return failure == null ? null : TaskError<T>(failure);
  }

  TaskAggregate aggregate(TaskOccurrence o) => TaskAggregate(
    task: tasks[o.taskId]!,
    occurrence: o,
    history: histories[o.taskId] ?? [],
  );
  @override
  Future<TaskResult<TaskAggregate>> loadTask(
    TaskId taskId,
    OccurrenceId occurrenceId,
  ) async {
    final failure = _failure<TaskAggregate>();
    if (failure != null) return failure;
    final o = occurrences[occurrenceId];
    if (o == null || o.taskId != taskId || !tasks.containsKey(taskId)) {
      return TaskError(TaskFailure(TaskFailureCode.notFound));
    }
    if (o.isDeleted) return TaskError(TaskFailure(TaskFailureCode.deleted));
    return TaskSuccess(aggregate(o));
  }

  @override
  Future<TaskResult<List<TaskAggregate>>> loadRange(
    LocalDateRange range,
  ) async {
    final failure = _failure<List<TaskAggregate>>();
    if (failure != null) return failure;
    return TaskSuccess(
      occurrences.values
          .where((o) => !o.isDeleted && range.contains(o.effectiveDate))
          .map(aggregate)
          .toList(),
    );
  }

  @override
  Future<TaskResult<List<TaskScheduleSnapshot>>> loadScheduleSnapshot(
    LocalDateRange range,
  ) async =>
      _failure<List<TaskScheduleSnapshot>>() ??
      TaskSuccess(
        tasks.values
            .map(
              (t) =>
                  TaskScheduleSnapshot(task: t, history: histories[t.id] ?? []),
            )
            .toList(),
      );
  @override
  Future<TaskResult<List<TaskOccurrence>>> loadFutureOccurrences(
    TaskId id,
    LocalDate after,
  ) async =>
      _failure<List<TaskOccurrence>>() ??
      TaskSuccess(
        occurrences.values
            .where(
              (o) => o.taskId == id && o.scheduledDate.compareTo(after) > 0,
            )
            .toList(),
      );
  @override
  Future<TaskResult<List<TaskStreakHistory>>> loadStreakHistory(
    Set<TaskId> ids,
    LocalDate throughDate,
  ) async =>
      _failure<List<TaskStreakHistory>>() ??
      TaskSuccess(
        tasks.values
            .where((t) => ids.contains(t.id))
            .map(
              (t) => TaskStreakHistory(
                snapshot: TaskScheduleSnapshot(
                  task: t,
                  history: histories[t.id] ?? [],
                ),
                occurrences: occurrences.values
                    .where(
                      (o) =>
                          o.taskId == t.id &&
                          o.scheduledDate.compareTo(throughDate) <= 0,
                    )
                    .toList(),
              ),
            )
            .toList(),
      );
  TaskFailure? _check(
    ExpectedRevisions e,
    OccurrenceId id, {
    bool deleted = false,
  }) {
    final t = tasks[e.taskId];
    final o = occurrences[id];
    if (t == null || o == null || o.taskId != t.id) {
      return TaskFailure(TaskFailureCode.notFound);
    }
    if (!deleted && o.isDeleted) return TaskFailure(TaskFailureCode.deleted);
    if (t.revision != e.taskRevision || o.revision != e.occurrenceRevision) {
      return TaskFailure(TaskFailureCode.staleRevision);
    }
    return null;
  }

  @override
  Future<TaskResult<TaskSaveResult>> saveTask(PreparedTaskSave p) async {
    saves++;
    final failure = _failure<TaskSaveResult>();
    if (failure != null) return failure;
    final a = p.aggregate;
    if (p.expected != null) {
      final check = _check(p.expected!, a.occurrence.id);
      if (check != null) return TaskError(check);
    } else if (tasks.containsKey(a.task.id) ||
        occurrences.containsKey(a.occurrence.id)) {
      return TaskError(TaskFailure(TaskFailureCode.staleRevision));
    }
    tasks[a.task.id] = a.task;
    histories[a.task.id] = a.history;
    occurrences[a.occurrence.id] = a.occurrence;
    for (final id in p.removed) {
      occurrences.remove(id);
    }
    for (final o in p.reconciled) {
      occurrences[o.id] = o;
    }
    for (final o in p.generated) {
      if (!occurrences.values.any(
        (v) => v.taskId == o.taskId && v.scheduledDate == o.scheduledDate,
      )) {
        occurrences[o.id] = o;
      }
    }
    final receipt = TaskMutationReceipt(
      taskId: a.task.id,
      occurrenceId: a.occurrence.id,
      taskRevision: a.task.revision,
      occurrenceRevision: a.occurrence.revision,
      affectedDates: {
        a.occurrence.scheduledDate,
        a.occurrence.effectiveDate,
        ...p.reconciled.map((o) => o.effectiveDate),
        ...p.generated.map((o) => o.effectiveDate),
      },
    );
    _changes.add(
      TaskChange(
        taskIds: {a.task.id},
        dates: receipt.affectedDates,
        sharedMetadataChanged:
            p.expected == null || a.task.revision != p.expected!.taskRevision,
      ),
    );
    return TaskSuccess(TaskSaveResult(a, receipt));
  }

  @override
  Future<TaskResult<bool>> ensureOccurrences(
    List<TaskOccurrence> candidates,
    Map<TaskId, int> expected,
  ) async {
    final failure = _failure<bool>();
    if (failure != null) return failure;
    for (final e in expected.entries) {
      if (tasks[e.key]?.revision != e.value) {
        return TaskError(TaskFailure(TaskFailureCode.staleRevision));
      }
    }
    var changed = false;
    final dates = <LocalDate>{};
    for (final o in candidates) {
      if (occurrences.values.any(
        (v) => v.taskId == o.taskId && v.scheduledDate == o.scheduledDate,
      )) {
        continue;
      }
      occurrences[o.id] = o;
      changed = true;
      dates.add(o.effectiveDate);
    }
    if (changed) {
      _changes.add(TaskChange(taskIds: expected.keys.toSet(), dates: dates));
    }
    return TaskSuccess(changed);
  }

  @override
  Future<TaskResult<TaskMutationReceipt>> applyOccurrenceChange(
    PreparedOccurrenceChange p,
  ) async {
    final failure = _failure<TaskMutationReceipt>();
    if (failure != null) return failure;
    final check = _check(p.expected, p.before.id);
    if (check != null) return TaskError(check);
    final o = p.after;
    occurrences[o.id] = o;
    final receipt = TaskMutationReceipt(
      taskId: o.taskId,
      occurrenceId: o.id,
      taskRevision: p.expected.taskRevision,
      occurrenceRevision: o.revision,
      affectedDates: {p.before.effectiveDate, o.effectiveDate, o.scheduledDate},
      undo: p.undoable
          ? TaskUndoSnapshot(
              before: p.before,
              expected: ExpectedRevisions(
                taskId: o.taskId,
                taskRevision: p.expected.taskRevision,
                occurrenceRevision: o.revision,
              ),
            )
          : null,
    );
    _changes.add(TaskChange(taskIds: {o.taskId}, dates: receipt.affectedDates));
    return TaskSuccess(receipt);
  }

  @override
  Future<TaskResult<TaskMutationReceipt>> restoreOccurrence(
    TaskUndoSnapshot p,
  ) async {
    final failure = _failure<TaskMutationReceipt>();
    if (failure != null) return failure;
    final check = _check(p.expected, p.before.id, deleted: true);
    if (check != null) return TaskError(check);
    final current = occurrences[p.before.id]!;
    final o = p.before.copyWith(revision: current.revision + 1);
    occurrences[o.id] = o;
    final receipt = TaskMutationReceipt(
      taskId: o.taskId,
      occurrenceId: o.id,
      taskRevision: p.expected.taskRevision,
      occurrenceRevision: o.revision,
      affectedDates: {o.scheduledDate, o.effectiveDate, current.effectiveDate},
    );
    _changes.add(TaskChange(taskIds: {o.taskId}, dates: receipt.affectedDates));
    return TaskSuccess(receipt);
  }

  @override
  Future<void> dispose() => _changes.close();
}
