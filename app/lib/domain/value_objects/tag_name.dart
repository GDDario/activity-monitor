import 'bounded_text.dart';

final class TagName {
  factory TagName(String input) {
    var display = input.trim();
    if (display.startsWith('#')) display = display.substring(1).trim();
    return TagName._(boundedText(display, 32));
  }
  TagName._(this.value);
  final String value;
  String get key => value.toLowerCase();
  @override
  bool operator ==(Object other) => other is TagName && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
