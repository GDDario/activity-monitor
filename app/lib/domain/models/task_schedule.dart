import '../value_objects/local_date.dart';
import '../value_objects/reminder_preference.dart';
import '../value_objects/time_window.dart';
import '../value_objects/weekly_days.dart';

enum TaskCadence { oneTime, daily, weekly }

enum DayPeriod { morning, afternoon, evening }

final class TaskSchedule {
  TaskSchedule({
    required this.cadence,
    required this.recurrenceEnabled,
    required this.startDate,
    this.effectiveFrom,
    this.weeklyDays,
    this.timeWindow,
    this.reminder = const ReminderPreference.off(),
    this.streakEnabled = false,
    this.dayPeriod,
  }) {
    if (cadence == TaskCadence.oneTime && recurrenceEnabled ||
        cadence == TaskCadence.weekly &&
            recurrenceEnabled &&
            (weeklyDays == null || weeklyDays!.mask == 0) ||
        cadence != TaskCadence.weekly &&
            weeklyDays != null &&
            weeklyDays!.mask != 0 ||
        reminder.minutesBefore != null && timeWindow == null ||
        streakEnabled && (cadence != TaskCadence.daily || !recurrenceEnabled) ||
        dayPeriod != null && cadence != TaskCadence.daily) {
      throw ArgumentError('Invalid schedule');
    }
  }
  final TaskCadence cadence;
  final bool recurrenceEnabled;
  final LocalDate startDate;
  final LocalDate? effectiveFrom;
  final WeeklyDays? weeklyDays;
  final TimeWindow? timeWindow;
  final ReminderPreference reminder;
  final bool streakEnabled;
  final DayPeriod? dayPeriod;

  bool matches(LocalDate date) {
    if (date.compareTo(startDate) < 0 ||
        effectiveFrom != null && date.compareTo(effectiveFrom!) < 0) {
      return false;
    }
    if (!recurrenceEnabled) return date == startDate;
    return switch (cadence) {
      TaskCadence.oneTime => date == startDate,
      TaskCadence.daily => true,
      TaskCadence.weekly => weeklyDays!.contains(date.weekday),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TaskSchedule &&
      other.cadence == cadence &&
      other.recurrenceEnabled == recurrenceEnabled &&
      other.startDate == startDate &&
      other.effectiveFrom == effectiveFrom &&
      other.weeklyDays == weeklyDays &&
      other.timeWindow == timeWindow &&
      other.reminder == reminder &&
      other.streakEnabled == streakEnabled &&
      other.dayPeriod == dayPeriod;
  @override
  int get hashCode => Object.hash(
    cadence,
    recurrenceEnabled,
    startDate,
    effectiveFrom,
    weeklyDays,
    timeWindow,
    reminder,
    streakEnabled,
    dayPeriod,
  );
}
