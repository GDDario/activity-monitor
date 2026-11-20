import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/data/services/tracking_codec.dart';
import 'package:app/domain/models/task_tracking.dart';

void main() {
  final examples = <FieldKind, ({Object valid, Object invalid})>{
    FieldKind.text: (valid: 'A quiet morning', invalid: 42),
    FieldKind.number: (valid: -1.5, invalid: double.infinity),
    FieldKind.date: (valid: '2026-02-28', invalid: '2026-02-30'),
    FieldKind.checkbox: (valid: false, invalid: 'false'),
    FieldKind.choice: (valid: 'A', invalid: 'C'),
    FieldKind.duration: (valid: 90.5, invalid: -1),
    FieldKind.exercises: (
      valid: [
        {'exercise': 'Squat', 'reps': 5, 'weight': 20, 'unit': 'kg'},
      ],
      invalid: [
        {'exercise': 'Squat', 'reps': 0},
      ],
    ),
    FieldKind.episodes: (
      valid: [
        {'season': 2, 'episode': 3},
      ],
      invalid: [
        {'season': 0, 'episode': 3},
      ],
    ),
    FieldKind.checklist: (
      valid: [
        {'title': 'Kitchen', 'done': false},
      ],
      invalid: [
        {'title': '', 'done': false},
      ],
    ),
  };
  for (final entry in examples.entries) {
    test(
      '${entry.key.name} rejects incompatible input and survives encoded log restart',
      () {
        final field = TrackingField(
          id: 'field',
          label: 'Custom field',
          kind: entry.key,
          scope: FieldScope.log,
          required: true,
          choices: entry.key == FieldKind.choice ? ['A', 'B'] : [],
        );
        expect(field.validate(entry.value.invalid), isNotNull);
        final type = TaskType(
          id: 'type',
          name: 'Custom type',
          icon: 'task',
          fields: [field],
        );
        final log = ActivityLog(
          id: 'log',
          taskId: 'task',
          recordedAt: DateTime.utc(2026),
          type: type,
          values: {field.id: entry.value.valid},
        );
        final restored = decodeActivityLog(
          jsonDecode(jsonEncode(encodeActivityLog(log))),
        );
        expect(restored.type.fields.single.kind, entry.key);
        expect(restored.values, log.values);
        expect(restored.recordedAt, log.recordedAt);
      },
    );
  }
}
