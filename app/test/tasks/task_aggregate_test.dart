import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';

void main() {
  test('editing a new draft retains allocated identities across retries', () {
    var next = 0;
    final draft = TaskDraft.newTask(
      date: LocalDate(2026, 1, 30),
      newId: () => 'id-${next++}',
    );
    final retry = draft.copyWith(title: ' Read ');
    expect(retry.taskId, draft.taskId);
    expect(retry.occurrenceId, draft.occurrenceId);
    expect(next, 2);
    expect(retry.title, ' Read ');
    expect(draft.title, '');
    expect(draft.subtasks, isEmpty);
  });
  test('typed failures retain only domain codes and field paths', () {
    final result = TaskError<int>(
      TaskFailure.validation({'title': 'required'}),
    );
    expect(result.isSuccess, false);
    expect(result.failure!.code, TaskFailureCode.validation);
    expect(result.failure!.fields, {'title': 'required'});
    expect(
      () => result.failure!.fields['notes'] = 'invalid',
      throwsUnsupportedError,
    );
  });
  test(
    'aggregate rejects occurrence ownership and overlapping rule history',
    () {
      final date = LocalDate(2026, 1, 30);
      final schedule = TaskSchedule(
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
        startDate: date,
        effectiveFrom: date,
      );
      final task = Task(
        id: TaskId('owner'),
        title: TaskTitle('Read'),
        schedule: schedule,
      );
      final wrong = TaskOccurrence(
        id: OccurrenceId('other'),
        taskId: TaskId('wrong'),
        scheduledDate: date,
        effectiveDate: date,
      );
      expect(
        () => TaskAggregate(task: task, occurrence: wrong),
        throwsArgumentError,
      );
      final old = TaskSchedule(
        cadence: TaskCadence.daily,
        recurrenceEnabled: true,
        startDate: LocalDate(2026, 1, 1),
        effectiveFrom: LocalDate(2026, 1, 1),
      );
      expect(
        () => TaskScheduleSnapshot(
          task: task,
          history: [SchedulePeriod(old, until: LocalDate(2026, 1, 31))],
        ),
        throwsArgumentError,
      );
    },
  );
  test('occurrences reject negative revisions and completion/reminder contradictions', () {
    final date = LocalDate(2026, 1, 30);
    expect(
      () => TaskOccurrence(
        id: OccurrenceId('o'),
        taskId: TaskId('t'),
        scheduledDate: date,
        effectiveDate: date,
        revision: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => TaskOccurrence(
        id: OccurrenceId('o'),
        taskId: TaskId('t'),
        scheduledDate: date,
        effectiveDate: date,
        completedAtUtc: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });
}
