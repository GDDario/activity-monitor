final class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      throw ArgumentError('Invalid date');
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError('Invalid date');
    }
  }
  factory LocalDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw ArgumentError('Invalid date');
    }
    return LocalDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }
  final int year, month, day;
  LocalDate addDays(int days) {
    final result = DateTime.utc(year, month, day + days);
    return LocalDate(result.year, result.month, result.day);
  }

  int get weekday => DateTime.utc(year, month, day).weekday;
  @override
  int compareTo(LocalDate other) => (year * 10000 + month * 100 + day)
      .compareTo(other.year * 10000 + other.month * 100 + other.day);
  @override
  bool operator ==(Object other) => other is LocalDate && compareTo(other) == 0;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
