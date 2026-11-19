import 'dart:developer' as developer;

import 'package:app/data/services/notification_database.dart';
import 'package:app/data/services/local_notification_service.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/value_objects/local_date.dart';

abstract class NotificationRepository {
  Stream<String> get taps;
  Future<void> setEnabled(bool enabled);
  Future<bool> getEnabled();
  Future<ReminderCapability> capability({
    bool request = false,
    bool timing = false,
  });
  DateTime resolve(LocalDate date, int minute);
  Future<ReminderSnapshot> refresh(
    List<TaskReminder> desired, {
    required bool pt,
    ReminderCapability? capability,
  });
}

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this.store, this.service);
  final NotificationStore store;
  final LocalNotificationService service;
  final _signatures = <int, String>{};
  @override
  Stream<String> get taps => service.taps;
  @override
  Future<void> setEnabled(bool enabled) => store.writeEnabled(enabled);
  @override
  Future<bool> getEnabled() => store.readEnabled();
  @override
  Future<ReminderCapability> capability({
    bool request = false,
    bool timing = false,
  }) => service.inspect(request: request, timing: timing);
  @override
  DateTime resolve(LocalDate date, int minute) => service.resolve(date, minute);
  @override
  Future<ReminderSnapshot> refresh(
    List<TaskReminder> desired, {
    required bool pt,
    ReminderCapability? capability,
  }) async {
    var enabled = false;
    try {
      enabled = await store.readEnabled();
      final c = capability ?? await service.inspect();
      if (!c.supported) {
        return ReminderSnapshot(
          enabled: enabled,
          availability: ReminderAvailability.unsupported,
        );
      }
      final pending = await service.pendingIds();
      if (!enabled || !c.allowed) {
        for (final id in pending) {
          await service.cancel(id);
        }
        _signatures.clear();
        return ReminderSnapshot(
          enabled: enabled,
          availability: enabled
              ? ReminderAvailability.denied
              : ReminderAvailability.off,
          precise: c.precise,
        );
      }
      final ids = await store.allocate(
        desired.map((r) => r.occurrenceId).toList(),
      );
      final wanted = ids.values.toSet();
      for (final id in pending.difference(wanted)) {
        await service.cancel(id);
        _signatures.remove(id);
      }
      for (final r in desired) {
        final id = ids[r.occurrenceId]!;
        final signature =
            '${r.title}\u0000${r.fireAt.toUtc().toIso8601String()}\u0000${r.startAt.toUtc().toIso8601String()}\u0000$pt\u0000${c.precise}\u0000${c.zone}';
        if (!pending.contains(id) || _signatures[id] != signature) {
          await service.schedule(id, r, pt: pt, precise: c.precise);
          _signatures[id] = signature;
        }
      }
      final confirmed = await service.pendingIds();
      if (!confirmed.containsAll(wanted)) {
        throw StateError('Incomplete notification queue');
      }
      return ReminderSnapshot(
        enabled: true,
        availability: ReminderAvailability.ready,
        precise: c.precise,
        queued: desired,
      );
    } catch (error) {
      developer.log(
        'Reminder reconciliation unavailable',
        name: 'notifications',
        error: error.runtimeType,
      );
      return ReminderSnapshot(
        enabled: enabled,
        availability: ReminderAvailability.unavailable,
      );
    }
  }
}
