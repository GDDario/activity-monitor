import 'package:app/domain/models/calendar_data.dart';

class CalendarState {
  CalendarState(DateTime date)
    : selected = DateTime(date.year, date.month, date.day);

  DateTime selected;
  bool weekMode = false;
  CalendarData? data;
  CalendarCadence? cadence;
  String? participantId;

  List<CalendarEntry> get matchingEntries => (data?.entries ?? [])
      .where(
        (entry) =>
            (cadence == null || cadence == entry.cadence) &&
            (participantId == null ||
                entry.participantIds.contains(participantId)),
      )
      .toList();

  List<DateTime> get visibleDays {
    final anchor = weekMode
        ? selected
        : DateTime(selected.year, selected.month);
    final start = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday % 7,
    );
    final count = weekMode
        ? 7
        : ((DateTime.utc(selected.year, selected.month + 1)
                          .difference(
                            DateTime.utc(start.year, start.month, start.day),
                          )
                          .inDays +
                      6) ~/
                  7) *
              7;
    return List.generate(
      count,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
  }

  void move(int amount) {
    if (weekMode) {
      selected = DateTime(
        selected.year,
        selected.month,
        selected.day + amount * 7,
      );
    } else {
      final first = DateTime(selected.year, selected.month + amount);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      selected = DateTime(
        first.year,
        first.month,
        selected.day > lastDay ? lastDay : selected.day,
      );
    }
  }
}
