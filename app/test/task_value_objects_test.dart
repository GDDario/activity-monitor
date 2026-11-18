import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/subtask_title.dart';
import 'package:app/domain/value_objects/tag_name.dart';
import 'package:app/domain/value_objects/task_notes.dart';
import 'package:app/domain/value_objects/task_id.dart';

void main() {
  test('titles reject blank, NUL and more than 200 Unicode scalars', () {
    expect(() => TaskTitle('  '), throwsArgumentError);
    expect(() => TaskTitle('a\u0000b'), throwsArgumentError);
    expect(TaskTitle('😀' * 200).value.runes.length, 200);
    expect(() => TaskTitle('😀' * 201), throwsArgumentError);
    expect(() => SubtaskTitle('a' * 201), throwsArgumentError);
    expect(TaskTitle(' x ').value, 'x');
    expect(TaskTitle.persisted(' x ').value, ' x ');
  });
  test('tags normalize display and keys without folding accents', () {
    final tag = TagName(' #  Café  ');
    expect(tag.value, 'Café');
    expect(tag.key, 'café');
    expect(TagName('CAFE').key, isNot(tag.key));
    expect(() => TagName('# '), throwsArgumentError);
    expect(() => TagName('😀' * 33), throwsArgumentError);
    expect(() => TagName('a\u0000'), throwsArgumentError);
  });
  test('notes preserve whitespace and enforce scalar bounds', () {
    expect(TaskNotes(' a\n ').value, ' a\n ');
    expect(TaskNotes('😀' * 10000).value.runes.length, 10000);
    expect(() => TaskNotes('😀' * 10001), throwsArgumentError);
    expect(() => TaskNotes('\u0000'), throwsArgumentError);
  });
  test('legacy identifiers have value equality', () {
    expect(TaskId('legacy-id'), TaskId('legacy-id'));
    expect(TaskId('legacy-id').hashCode, TaskId('legacy-id').hashCode);
  });
}
