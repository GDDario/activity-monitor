final class TimeWindow {
  TimeWindow(this.startMinute, this.endMinute) {
    if (startMinute < 0 || endMinute >= 1440 || endMinute <= startMinute) {
      throw ArgumentError('Invalid time window');
    }
  }
  final int startMinute, endMinute;
  int get durationMinutes => endMinute - startMinute;
  @override
  bool operator ==(Object other) =>
      other is TimeWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;
  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}
