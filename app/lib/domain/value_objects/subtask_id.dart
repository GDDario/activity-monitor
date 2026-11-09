final class SubtaskId {
  SubtaskId(this.value) {
    if (value.isEmpty || value.contains('\u0000')) {
      throw ArgumentError('Invalid ID');
    }
  }
  final String value;
  @override
  bool operator ==(Object other) => other is SubtaskId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
