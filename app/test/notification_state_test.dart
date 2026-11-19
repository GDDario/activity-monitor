import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/ui/notifications/view_models/notification_view_model.dart';

void main() {
  test(
    'concurrent requests coalesce and latest committed state wins',
    () async {
      final gate = Completer<void>();
      var active = 0, maxActive = 0, calls = 0;
      final model = NotificationViewModel(
        refresh: ({request = false, timing = false}) async {
          calls++;
          active++;
          if (active > maxActive) maxActive = active;
          if (calls == 1) await gate.future;
          active--;
          return ReminderSnapshot(
            enabled: calls > 1,
            availability: ReminderAvailability.ready,
          );
        },
        setEnabled: (v) async {},
      );
      addTearDown(model.dispose);
      final first = model.refresh();
      final second = model.refresh();
      expect(model.busy, true);
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, 2);
      expect(maxActive, 1);
      expect(model.snapshot!.enabled, true);
      expect(model.busy, false);
    },
  );
  test(
    'enable persists before permission and failures produce recoverable state',
    () async {
      var enabled = false, asked = false;
      final model = NotificationViewModel(
        refresh: ({request = false, timing = false}) async {
          asked = request;
          return ReminderSnapshot(
            enabled: enabled,
            availability: ReminderAvailability.denied,
          );
        },
        setEnabled: (v) async {
          enabled = v;
        },
      );
      addTearDown(model.dispose);
      await model.enable(true);
      expect(enabled, true);
      expect(asked, true);
      expect(model.snapshot!.availability, ReminderAvailability.denied);
      await model.enable(false);
      expect(enabled, false);
      expect(asked, false);
    },
  );
  test('disposed pending work cannot notify listeners', () async {
    final gate = Completer<ReminderSnapshot>();
    final model = NotificationViewModel(
      refresh: ({request = false, timing = false}) => gate.future,
      setEnabled: (v) async {},
    );
    final pending = model.refresh();
    model.dispose();
    gate.complete(
      ReminderSnapshot(enabled: false, availability: ReminderAvailability.off),
    );
    await pending;
  });
  test('tap accepts only bounded structured identifiers and a valid date', () {
    expect(
      ReminderTap.parse(
        '{"v":1,"task":"task-a","occurrence":"a","date":"2026-11-19"}',
      )?.taskId,
      'task-a',
    );
    for (final raw in [
      'bad',
      '{"v":1,"task":"../../x"}',
      '{"v":1,"task":"a","occurrence":"b","date":"2026-02-30"}',
    ]) {
      expect(ReminderTap.parse(raw), isNull);
    }
  });
}
