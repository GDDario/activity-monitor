final class WeeklyDays {
  WeeklyDays(this.mask) {
    if (mask < 0 || mask > 127) throw ArgumentError('Invalid weekday mask');
  }
  final int mask;
  bool contains(int weekday) {
    if (weekday < 1 || weekday > 7) throw ArgumentError('Invalid weekday');
    return mask & (1 << (weekday - 1)) != 0;
  }

  @override
  bool operator ==(Object other) => other is WeeklyDays && other.mask == mask;
  @override
  int get hashCode => mask.hashCode;
}
