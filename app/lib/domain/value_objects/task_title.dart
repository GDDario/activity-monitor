import 'bounded_text.dart';

final class TaskTitle {
  TaskTitle(String value) : value = boundedText(value, 200);
  TaskTitle.persisted(String value)
    : value = boundedText(value, 200, trim: false);
  final String value;
  @override
  bool operator ==(Object other) => other is TaskTitle && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
