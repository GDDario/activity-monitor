String boundedText(
  String input,
  int limit, {
  bool trim = true,
  bool allowBlank = false,
}) {
  final value = trim ? input.trim() : input;
  if (value.contains('\u0000') ||
      value.runes.length > limit ||
      (!allowBlank && value.trim().isEmpty)) {
    throw ArgumentError('Invalid text');
  }
  return value;
}
