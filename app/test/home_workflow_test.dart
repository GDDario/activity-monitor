import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/complete_task_occurrence.dart';
import 'package:app/domain/use_cases/delete_task_occurrence.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/use_cases/postpone_task_occurrence.dart';
import 'package:app/domain/use_cases/reopen_task_occurrence.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/undo_task_occurrence_action.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';

void main() {
  test('file-backed Home projects committed edits actions recovery and restart without another store', () async {
    final directory = Directory('../.scratches/home-validation')
        .createTempSync('workflow-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/home.db';
    initializeDatabaseAtPath(path);
    final fixtureDb = sqlite3.open(path);
    fixtureDb.execute('PRAGMA foreign_keys = ON');
    fixtureDb.execute('DELETE FROM tasks');
    fixtureDb.close();
    var repo = LocalTaskRepository(TaskDatabase(path: path));
    final day = LocalDate(2026, 11, 17);
    DateTime clock() => DateTime(2026, 11, 17, 9);
    var next = 0;
    String id() => 'home-${next++}';
    final model = TodayViewModel(
      clock: clock,
      load: (range) => EnsureTaskOccurrences(repo, newId: id).execute(range),
      changes: repo.changes,
    );
    addTearDown(model.dispose);
    Future<DailyOverview> overview() async {
      await model.load();
      while (model.state.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return model.state.overview!;
    }

    expect((await overview()).progress.total, 0);
    final created = (await SaveTask(repo, newId: id, clock: clock).execute(
      TaskDraft.newTask(date: day, newId: id).copyWith(
        title: 'Intentional work',
        notes: 'Preserve this context',
        timeWindow: TimeWindow(600, 660),
      ),
    )).value!.aggregate;
    expect(
      (await overview()).sections.single.period,
      DailyAgendaPeriod.morning,
    );
    expect(model.state.overview!.progress.next!.task.id, created.task.id);
    final edited = (await SaveTask(repo, newId: id, clock: clock).execute(
      TaskDraft.fromAggregate(created).copyWith(
        timeWindow: TimeWindow(780, 840),
        occurrenceTimeWindow: TimeWindow(780, 840),
      ),
    )).value!.aggregate;
    expect(
      (await overview()).sections.single.period,
      DailyAgendaPeriod.afternoonEvening,
    );
    final stale = await SaveTask(repo, newId: id, clock: clock).execute(
      TaskDraft.fromAggregate(created).copyWith(title: 'Stale overwrite'),
    );
    expect(stale.isSuccess, isFalse);
    expect(
      (await overview()).entries.single.task.title.value,
      'Intentional work',
    );
    final complete = await CompleteTaskOccurrence(
      repo,
      now: clock,
    ).execute(edited.occurrence.id, edited.expected);
    expect(complete.isSuccess, isTrue);
    expect((await overview()).progress.percentage, 100);
    expect(model.state.overview!.progress.next, isNull);
    var current = model.visible.single;
    expect(
      (await ReopenTaskOccurrence(
        repo,
        now: clock,
      ).execute(current.occurrence.id, current.expected)).isSuccess,
      isTrue,
    );
    expect((await overview()).progress.completed, 0);
    current = model.visible.single;
    final deleted = (await DeleteTaskOccurrence(
      repo,
      now: clock,
    ).execute(current.occurrence.id, current.expected)).value!;
    expect((await overview()).progress.total, 0);
    expect(
      (await UndoTaskOccurrenceAction(repo).execute(deleted.undo!)).isSuccess,
      isTrue,
    );
    expect(
      (await overview()).entries.single.occurrence.id,
      created.occurrence.id,
    );
    current = model.visible.single;
    expect(
      (await PostponeTaskOccurrence(
        repo,
        now: clock,
      ).execute(current.occurrence.id, current.expected)).isSuccess,
      isTrue,
    );
    expect((await overview()).progress.total, 0);
    model.setResumed(false);
    await repo.dispose();
    repo = LocalTaskRepository(TaskDatabase(path: path));
    addTearDown(repo.dispose);
    final persisted = (await EnsureTaskOccurrences(
      repo,
      newId: id,
    ).execute(LocalDateRange(day, day.addDays(1)))).value!;
    expect(persisted.length, 1);
    expect(persisted.single.occurrence.id, created.occurrence.id);
    expect(persisted.single.occurrence.effectiveDate, day.addDays(1));
    expect(persisted.single.occurrence.completed, isFalse);
    expect(persisted.single.task.notes, 'Preserve this context');
    expect(persisted.single.occurrence.timeWindow, TimeWindow(780, 840));
  });
}
