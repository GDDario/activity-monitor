import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/task_database_operations.dart';
import 'package:app/data/services/task_row_mapper.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

class CalendarDatabase {
  CalendarDatabase(this.open);
  final Future<Database> Function() open;

  Future<CalendarData> load({LocalDateRange? range}) async {
    final db = await open();
    // The catalog stays available when a range or active filter has no cards.
    final participants = db
        .select('SELECT id, name FROM calendar_participants ORDER BY name, id')
        .map((r) => CalendarParticipant(r['id'] as String, r['name'] as String))
        .toList();
    final aggregates = readTaskAggregates(
      db,
      from: range?.start.toString(),
      through: range?.end.toString(),
    ).map(taskAggregateFromRow).toList()..sort(_compare);
    final entries = aggregates.map((aggregate) {
      final task = aggregate.task;
      final occurrence = aggregate.occurrence;
      final date = occurrence.effectiveDate;
      return CalendarEntry(
        id: occurrence.id.value,
        title: task.title.value,
        date: DateTime(date.year, date.month, date.day),
        cadence: switch (task.schedule.cadence) {
          TaskCadence.daily => CalendarCadence.daily,
          TaskCadence.weekly => CalendarCadence.weekly,
          TaskCadence.oneTime => CalendarCadence.oneTime,
        },
        participantIds: task.participants.map((person) => person.id).toList(),
        isDone: occurrence.completed,
        taskAggregate: aggregate,
      );
    }).toList();
    return CalendarData(entries, participants);
  }

  static int _compare(TaskAggregate first, TaskAggregate second) {
    final a = first.occurrence;
    final b = second.occurrence;
    var result = a.effectiveDate.compareTo(b.effectiveDate);
    if (result == 0) {
      result = (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0);
    }
    if (result == 0) {
      result = (a.timeWindow?.startMinute ?? 1440).compareTo(
        b.timeWindow?.startMinute ?? 1440,
      );
    }
    if (result == 0) {
      result = first.task.title.value.compareTo(second.task.title.value);
    }
    return result == 0 ? a.id.value.compareTo(b.id.value) : result;
  }
}
