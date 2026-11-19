import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/value_objects/local_date.dart';

class BuildReminderQueue {
  const BuildReminderQueue();
  List<TaskReminder> execute(
    Iterable<TaskAggregate> tasks, {
    required DateTime now,
    required DateTime Function(LocalDate, int) resolve,
    int horizonDays = 30,
    int limit = 64,
  }) {
    final today = LocalDate(now.year, now.month, now.day),
        last = now.add(Duration(days: horizonDays));
    final candidates = <String, TaskReminder>{};
    for (final a in tasks) {
      final o = a.occurrence,
          window = o.timeWindow,
          lead = o.reminder.minutesBefore;
      if (o.completed ||
          o.isDeleted ||
          window == null ||
          lead == null ||
          o.effectiveDate.compareTo(today) < 0) {
        continue;
      }
      final start = resolve(o.effectiveDate, window.startMinute);
      // DST gaps must not silently become a reminder for a different wall time.
      if (start.year != o.effectiveDate.year ||
          start.month != o.effectiveDate.month ||
          start.day != o.effectiveDate.day ||
          start.hour * 60 + start.minute != window.startMinute) {
        continue;
      }
      final fire = start.subtract(Duration(minutes: lead));
      if (!fire.isAfter(now) || fire.isAfter(last)) continue;
      candidates[o.id.value] = TaskReminder(
        occurrenceId: o.id.value,
        taskId: a.task.id.value,
        title: a.task.title.value,
        date: o.effectiveDate,
        startAt: start,
        fireAt: fire,
      );
    }
    final sorted = candidates.values.toList()
      ..sort((a, b) {
        final c = a.fireAt.compareTo(b.fireAt);
        return c != 0 ? c : a.occurrenceId.compareTo(b.occurrenceId);
      });
    return List.unmodifiable(sorted.take(limit));
  }
}
