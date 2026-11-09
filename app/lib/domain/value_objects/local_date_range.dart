import 'local_date.dart';

final class LocalDateRange {
  LocalDateRange(this.start, this.end) {
    if (start.compareTo(end) > 0) throw ArgumentError('Invalid date range');
  }
  final LocalDate start, end;
  bool contains(LocalDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
  @override
  bool operator ==(Object other) =>
      other is LocalDateRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}
