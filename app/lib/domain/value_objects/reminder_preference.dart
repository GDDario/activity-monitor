final class ReminderPreference {
  ReminderPreference(this.minutesBefore) {
    if (minutesBefore != null &&
        !const [0, 5, 15, 30, 60].contains(minutesBefore)) {
      throw ArgumentError('Invalid reminder');
    }
  }
  const ReminderPreference.off() : minutesBefore = null;
  final int? minutesBefore;
  @override
  bool operator ==(Object other) =>
      other is ReminderPreference && other.minutesBefore == minutesBefore;
  @override
  int get hashCode => minutesBefore.hashCode;
}
