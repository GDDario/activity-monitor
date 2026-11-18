import 'bounded_text.dart';

final class SubtaskTitle {
  SubtaskTitle(String value) : value = boundedText(value, 200);
  final String value;
  @override
  bool operator ==(Object other) =>
      other is SubtaskTitle && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
