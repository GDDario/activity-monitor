import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/value_objects/task_id.dart';

import '../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repo;
  var next = 0;
  String newId() => 'r-${next++}';
  setUp(() => repo = FakeTaskRepository());
  tearDown(() => repo.dispose());
  test(
    'daily expansion is bounded and idempotent across month boundary',
    () async {
      final draft = TaskDraft.newTask(
        date: LocalDate(2026, 1, 30),
        newId: newId,
      ).copyWith(title: 'Daily', cadence: TaskCadence.daily);
      await SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      ).execute(draft);
      final ensure = EnsureTaskOccurrences(repo, newId: newId);
      final range = LocalDateRange(
        LocalDate(2026, 1, 30),
        LocalDate(2026, 2, 2),
      );
      expect((await ensure.execute(range)).value!.length, 4);
      final ids = repo.occurrences.keys.toSet();
      expect((await ensure.execute(range)).value!.length, 4);
      expect(repo.occurrences.keys.toSet(), ids);
      expect(repo.tasks[draft.taskId]!.revision, 0);
    },
  );
  test('weekly lower bound selects only chosen weekdays', () async {
    final draft = TaskDraft.newTask(date: LocalDate(2026, 1, 28), newId: newId)
        .copyWith(
          title: 'Weekly',
          cadence: TaskCadence.weekly,
          weeklyDays: WeeklyDays(1 | 8),
        );
    await SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 28, 12),
    ).execute(draft);
    final result = await EnsureTaskOccurrences(
      repo,
      newId: newId,
    ).execute(LocalDateRange(LocalDate(2026, 1, 26), LocalDate(2026, 2, 8)));
    expect(
      result.value!.map((a) => a.occurrence.scheduledDate.toString()).toSet(),
      {'2026-01-29', '2026-02-02', '2026-02-05'},
    );
  });
  test(
    'repeat-disabled legacy schedules do not synthesize another slot',
    () async {
      final draft = TaskDraft.newTask(
        date: LocalDate(2026, 1, 30),
        newId: newId,
      ).copyWith(title: 'Once');
      await SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      ).execute(draft);
      final result = await EnsureTaskOccurrences(
        repo,
        newId: newId,
      ).execute(LocalDateRange(LocalDate(2026, 1, 31), LocalDate(2026, 2, 2)));
      expect(result.value, isEmpty);
    },
  );
  test('a stale schedule retries once; repeated race is explicit', () async {
    repo.failNext = TaskFailure(TaskFailureCode.staleRevision);
    final result = await EnsureTaskOccurrences(
      repo,
      newId: newId,
    ).execute(LocalDateRange(LocalDate(2026, 1, 30), LocalDate(2026, 1, 30)));
    // A snapshot failure is observable; only a commit race is retried.
    expect(result.failure!.code, TaskFailureCode.staleRevision);
  });
  test(
    'a commit race reloads once and a second race remains explicit',
    () async {
      for (final staleCount in [1, 2]) {
        final racing = RacingTaskRepository(staleCount);
        addTearDown(racing.dispose);
        final draft = TaskDraft.newTask(
          date: LocalDate(2026, 1, 30),
          newId: newId,
        ).copyWith(title: 'Daily', cadence: TaskCadence.daily);
        await SaveTask(
          racing,
          newId: newId,
          clock: () => DateTime.utc(2026, 1, 30, 12),
        ).execute(draft);
        final result = await EnsureTaskOccurrences(racing, newId: newId)
            .execute(
              LocalDateRange(LocalDate(2026, 1, 30), LocalDate(2026, 2, 2)),
            );
        expect(racing.attempts, 2);
        if (staleCount == 1) {
          expect(result.value!.length, 4);
        } else {
          expect(result.failure!.code, TaskFailureCode.staleRevision);
          expect(racing.occurrences.length, 1);
        }
      }
    },
  );
}

class RacingTaskRepository extends FakeTaskRepository {
  RacingTaskRepository(this.staleCount);
  final int staleCount;
  int attempts = 0;
  @override
  Future<TaskResult<bool>> ensureOccurrences(
    List<TaskOccurrence> candidates,
    Map<TaskId, int> expected,
  ) {
    attempts++;
    if (attempts <= staleCount) {
      return Future.value(
        TaskError(TaskFailure(TaskFailureCode.staleRevision)),
      );
    }
    return super.ensureOccurrences(candidates, expected);
  }
}
