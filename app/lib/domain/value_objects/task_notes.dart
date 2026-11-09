import 'bounded_text.dart';

final class TaskNotes {
  TaskNotes(String value)
    : value = boundedText(value, 10000, trim: false, allowBlank: true);
  final String value;
  @override
  bool operator ==(Object other) => other is TaskNotes && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
