import 'dart:async';
import 'dart:developer' as developer;

import 'package:app/data/repositories/task_repository.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/services/task_row_mapper.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository(this.database);
  final TaskDatabase database;
  final _changes = StreamController<TaskChange>.broadcast();
  @override
  Stream<TaskChange> get changes => _changes.stream;
  Future<TaskResult<T>> _run<T>(
    String operation,
    Map<String, Object?> request,
    T Function(Map<String, Object?>) map,
  ) async {
    try {
      final result = await database.request({
        'operation': operation,
        ...request,
      });
      if (result['failure'] != null) {
        final code = TaskFailureCode.values.byName(result['failure'] as String);
        if (code == TaskFailureCode.storageUnavailable) {
          developer.log(
            'Task database operation unavailable',
            name: 'task_repository',
            error: operation,
          );
        }
        return TaskError(TaskFailure(code));
      }
      return TaskSuccess(map(result));
    } catch (error) {
      developer.log(
        'Task database operation unavailable',
        name: 'task_repository',
        error: '$operation:${error.runtimeType}',
      );
      return TaskError(TaskFailure(TaskFailureCode.storageUnavailable));
    }
  }

  List<Map<String, Object?>> _rows(Map<String, Object?> r) =>
      (r['rows'] as List)
          .map((r) => Map<String, Object?>.from(r as Map))
          .toList();
  @override
  Future<TaskResult<TaskAggregate>> loadTask(
    TaskId taskId,
    OccurrenceId occurrenceId,
  ) async {
    final result = await _run<List<TaskAggregate>>('aggregate', {
      'taskId': taskId.value,
      'occurrenceId': occurrenceId.value,
    }, (r) => _rows(r).map(taskAggregateFromRow).toList());
    if (!result.isSuccess) return TaskError(result.failure!);
    if (result.value!.isEmpty) {
      return TaskError(TaskFailure(TaskFailureCode.notFound));
    }
    final aggregate = result.value!.single;
    if (aggregate.occurrence.isDeleted) {
      return TaskError(TaskFailure(TaskFailureCode.deleted));
    }
    return TaskSuccess(aggregate);
  }

  @override
  Future<TaskResult<List<TaskAggregate>>> loadRange(LocalDateRange range) =>
      _run(
        'range',
        {'from': range.start.toString(), 'through': range.end.toString()},
        (r) {
          final rows = _rows(r).map(taskAggregateFromRow).toList();
          rows.sort(compareTaskAggregates);
          return rows;
        },
      );
  @override
  Future<TaskResult<List<TaskScheduleSnapshot>>> loadScheduleSnapshot(
    LocalDateRange range,
  ) => _run(
    'schedules',
    {'from': range.start.toString(), 'through': range.end.toString()},
    (r) => _rows(r)
        .map(
          (graph) => TaskScheduleSnapshot(
            task: taskFromRow(graph),
            history: taskHistoryFromRow(graph),
          ),
        )
        .toList(),
  );
  @override
  Future<TaskResult<List<TaskOccurrence>>> loadFutureOccurrences(
    TaskId taskId,
    LocalDate after,
  ) => _run('future', {
    'taskId': taskId.value,
    'after': after.toString(),
  }, (r) => _rows(r).map((g) => taskAggregateFromRow(g).occurrence).toList());
  @override
  Future<TaskResult<List<TaskStreakHistory>>> loadStreakHistory(
    Set<TaskId> taskIds,
    LocalDate throughDate,
  ) => _run(
    'streaks',
    {
      'taskIds': taskIds.map((id) => id.value).toList(),
      'through': throughDate.toString(),
    },
    (r) => _rows(r)
        .map(
          (g) => TaskStreakHistory(
            snapshot: TaskScheduleSnapshot(
              task: taskFromRow(g),
              history: taskHistoryFromRow(g),
            ),
            occurrences: (g['occurrences'] as List)
                .map(
                  (o) => taskOccurrenceFromRow(
                    Map<String, Object?>.from(o as Map),
                  ),
                )
                .toList(),
          ),
        )
        .toList(),
  );
  void _emit(Set<TaskId> tasks, Set<LocalDate> dates, {bool shared = false}) {
    if (!_changes.isClosed) {
      _changes.add(
        TaskChange(taskIds: tasks, dates: dates, sharedMetadataChanged: shared),
      );
    }
  }

  Set<LocalDate> _dates(Map<String, Object?> r) =>
      (r['dates'] as List).map((d) => LocalDate.parse(d as String)).toSet();
  @override
  Future<TaskResult<TaskSaveResult>> saveTask(PreparedTaskSave p) => _run(
    'save',
    {
      'task': _taskRow(p.aggregate.task),
      'occurrence': _occurrenceRow(p.aggregate.occurrence),
      'expected': p.expected == null ? null : _expect(p.expected!),
      'states': _states(p.aggregate.occurrence),
      'weekdays': [
        for (var day = 1; day <= 7; day++)
          if (p.aggregate.task.schedule.weeklyDays?.contains(day) ?? false) day,
      ],
      'history': p.aggregate.history
          .map((h) => _historyRow(p.aggregate.task.id, h))
          .toList(),
      'tags': p.aggregate.task.tags
          .map(
            (t) => <String, Object?>{
              'id': t.id.value,
              'name': t.name.value,
              'normalized_name': t.name.key,
            },
          )
          .toList(),
      'subtasks': p.aggregate.task.subtasks
          .map(
            (s) => <String, Object?>{
              'id': s.id.value,
              'title': s.title.value,
              'position': s.position,
              'active': s.active ? 1 : 0,
            },
          )
          .toList(),
      'today': p.today.toString(),
      'reconciled': p.reconciled.map(_occurrenceRow).toList(),
      'removed': p.removed.map((id) => id.value).toList(),
      'generated': p.generated.map(_occurrenceRow).toList(),
    },
    (r) {
      final aggregate = taskAggregateFromRow(
        Map<String, Object?>.from(r['aggregate'] as Map),
      );
      final dates = _dates(r);
      final receipt = TaskMutationReceipt(
        taskId: aggregate.task.id,
        occurrenceId: aggregate.occurrence.id,
        taskRevision: aggregate.task.revision,
        occurrenceRevision: aggregate.occurrence.revision,
        affectedDates: dates,
      );
      _emit(
        {aggregate.task.id},
        dates,
        shared:
            p.expected == null ||
            aggregate.task.revision != p.expected!.taskRevision,
      );
      return TaskSaveResult(aggregate, receipt);
    },
  );
  @override
  Future<TaskResult<bool>> ensureOccurrences(
    List<TaskOccurrence> candidates,
    Map<TaskId, int> expectedTaskRevisions,
  ) => _run(
    'ensure',
    {
      'candidates': candidates.map(_occurrenceRow).toList(),
      'taskRevisions': {
        for (final e in expectedTaskRevisions.entries) e.key.value: e.value,
      },
    },
    (r) {
      final changed = r['changed'] as bool;
      if (changed) {
        _emit(
          (r['taskIds'] as List).map((id) => TaskId(id as String)).toSet(),
          _dates(r),
        );
      }
      return changed;
    },
  );
  @override
  Future<TaskResult<TaskMutationReceipt>> applyOccurrenceChange(
    PreparedOccurrenceChange p,
  ) => _run(
    'change',
    {
      'expected': _expect(p.expected),
      'occurrence': _occurrenceRow(p.after),
      'states': _states(p.after),
    },
    (r) {
      final dates = _dates(r);
      final receipt = TaskMutationReceipt(
        taskId: p.after.taskId,
        occurrenceId: p.after.id,
        taskRevision: p.expected.taskRevision,
        occurrenceRevision: p.after.revision,
        affectedDates: dates,
        undo: p.undoable
            ? TaskUndoSnapshot(
                before: p.before,
                expected: ExpectedRevisions(
                  taskId: p.after.taskId,
                  taskRevision: p.expected.taskRevision,
                  occurrenceRevision: p.after.revision,
                ),
              )
            : null,
      );
      _emit({p.after.taskId}, dates);
      return receipt;
    },
  );
  @override
  Future<TaskResult<TaskMutationReceipt>> restoreOccurrence(
    TaskUndoSnapshot p,
  ) {
    final restored = p.before.copyWith(
      revision: p.expected.occurrenceRevision + 1,
    );
    return _run(
      'restore',
      {
        'expected': _expect(p.expected),
        'occurrence': _occurrenceRow(restored),
        'states': _states(restored),
      },
      (r) {
        final dates = _dates(r);
        final receipt = TaskMutationReceipt(
          taskId: restored.taskId,
          occurrenceId: restored.id,
          taskRevision: p.expected.taskRevision,
          occurrenceRevision: restored.revision,
          affectedDates: dates,
        );
        _emit({restored.taskId}, dates);
        return receipt;
      },
    );
  }

  @override
  Future<void> dispose() => _changes.close();
}

int compareTaskAggregates(TaskAggregate a, TaskAggregate b) {
  final completion = (a.occurrence.completed ? 1 : 0).compareTo(
    b.occurrence.completed ? 1 : 0,
  );
  if (completion != 0) return completion;
  final time = (a.occurrence.timeWindow?.startMinute ?? 1440).compareTo(
    b.occurrence.timeWindow?.startMinute ?? 1440,
  );
  if (time != 0) return time;
  final title = a.task.title.value.compareTo(b.task.title.value);
  return title != 0
      ? title
      : a.occurrence.id.value.compareTo(b.occurrence.id.value);
}

Map<String, Object?> _expect(ExpectedRevisions e) => {
  'taskId': e.taskId.value,
  'taskRevision': e.taskRevision,
  'occurrenceRevision': e.occurrenceRevision,
};
Map<String, Object?> _scheduleRow(TaskSchedule s) => {
  'cadence': switch (s.cadence) {
    TaskCadence.oneTime => 'one-time',
    _ => s.cadence.name,
  },
  'recurrence_enabled': s.recurrenceEnabled ? 1 : 0,
  'start_date': s.startDate.toString(),
  'start_minute': s.timeWindow?.startMinute,
  'end_minute': s.timeWindow?.endMinute,
  'reminder_minutes_before': s.reminder.minutesBefore,
};
Map<String, Object?> _taskRow(Task t) => {
  'id': t.id.value,
  'title': t.title.value,
  'notes': t.notes.isEmpty ? null : t.notes,
  'priority': t.priority.name,
  ..._scheduleRow(t.schedule),
  'rule_effective_date': t.schedule.effectiveFrom?.toString(),
  'streak_enabled': t.schedule.streakEnabled ? 1 : 0,
  'day_period': t.schedule.dayPeriod?.name,
  'revision': t.revision,
  'created_at_utc': t.createdAtUtc?.toUtc().toIso8601String(),
  'updated_at_utc': t.updatedAtUtc?.toUtc().toIso8601String(),
};
Map<String, Object?> _historyRow(TaskId id, SchedulePeriod h) => {
  'task_id': id.value,
  ..._scheduleRow(h.schedule),
  'effective_from': (h.schedule.effectiveFrom ?? h.schedule.startDate)
      .toString(),
  'effective_until': h.until!.toString(),
  'weekday_mask': h.schedule.weeklyDays?.mask ?? 0,
};
Map<String, Object?> _occurrenceRow(TaskOccurrence o) => {
  'id': o.id.value,
  'task_id': o.taskId.value,
  'scheduled_date': o.scheduledDate.toString(),
  'effective_date': o.effectiveDate.toString(),
  'start_minute': o.timeWindow?.startMinute,
  'end_minute': o.timeWindow?.endMinute,
  'reminder_minutes_before': o.reminder.minutesBefore,
  'completed': o.completed ? 1 : 0,
  'completed_at_utc': o.completedAtUtc?.toUtc().toIso8601String(),
  'deleted_at_utc': o.deletedAtUtc?.toUtc().toIso8601String(),
  'is_schedule_exception': o.isScheduleException ? 1 : 0,
  'revision': o.revision,
};
List<Map<String, Object?>> _states(TaskOccurrence o) => o.subtaskStates.entries
    .map(
      (s) => <String, Object?>{
        'subtask_id': s.key.value,
        'completed': s.value ? 1 : 0,
      },
    )
    .toList();
