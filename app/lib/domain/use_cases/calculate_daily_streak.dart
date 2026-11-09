import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';

class CalculateDailyStreak {
  const CalculateDailyStreak();
  int? execute(TaskStreakHistory history, LocalDate today) {
    final snapshot = history.snapshot;
    if (!snapshot.task.schedule.streakEnabled) return null;
    final active = scheduleAt(snapshot, today);
    if (active == null ||
        active.cadence != TaskCadence.daily ||
        !active.recurrenceEnabled ||
        today.compareTo(active.startDate) < 0) {
      return null;
    }
    var start = _later(
      active.startDate,
      active.effectiveFrom ?? active.startDate,
    );
    // Default/visibility edits within uninterrupted daily periods retain the run.
    final periods = [
      ...snapshot.history,
      SchedulePeriod(snapshot.task.schedule),
    ];
    var index = periods.indexWhere((p) => identical(p.schedule, active));
    if (index < 0) index = periods.indexWhere((p) => p.schedule == active);
    while (index > 0) {
      final previous = periods[index - 1];
      if (previous.until != start ||
          previous.schedule.cadence != TaskCadence.daily ||
          !previous.schedule.recurrenceEnabled) {
        break;
      }
      final precedingStart = _later(
        previous.schedule.startDate,
        previous.schedule.effectiveFrom ?? previous.schedule.startDate,
      );
      // A start moved forward introduces a real gap, even within daily cadence.
      if (start !=
          (periods[index].schedule.effectiveFrom ??
              periods[index].schedule.startDate)) {
        break;
      }
      start = precedingStart;
      index--;
    }
    final completed = {
      for (final o in history.occurrences)
        if (o.completed &&
            !o.isDeleted &&
            o.scheduledDate.compareTo(today) <= 0)
          o.scheduledDate,
    };
    var date = completed.contains(today) ? today : today.addDays(-1);
    var count = 0;
    while (date.compareTo(start) >= 0 && completed.contains(date)) {
      count++;
      if (date == start) break;
      date = date.addDays(-1);
    }
    return count;
  }
}

LocalDate _later(LocalDate a, LocalDate b) => a.compareTo(b) >= 0 ? a : b;
