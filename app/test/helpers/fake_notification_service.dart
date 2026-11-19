import 'dart:async';

import 'package:app/data/services/notification_database.dart';
import 'package:app/data/services/local_notification_service.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/value_objects/local_date.dart';

class MemoryNotificationStore implements NotificationStore {
  bool enabled = false;
  final ids = <String, int>{};
  bool fail = false;
  @override
  Future<bool> readEnabled() async {
    if (fail) throw StateError('unavailable');
    return enabled;
  }

  @override
  Future<void> writeEnabled(bool v) async {
    enabled = v;
  }

  @override
  Future<Map<String, int>> allocate(List<String> keys) async => {
    for (final k in keys) k: ids.putIfAbsent(k, () => ids.length + 1),
  };
}

class FakeNotificationService implements LocalNotificationService {
  ReminderCapability capability = const ReminderCapability(
    allowed: true,
    precise: true,
  );
  final pending = <int>{};
  final tapsController = StreamController<String>.broadcast();
  int writes = 0, requests = 0, inspections = 0;
  bool fail = false;
  int? failAfter;
  @override
  Stream<String> get taps => tapsController.stream;
  @override
  Future<ReminderCapability> inspect({
    bool request = false,
    bool timing = false,
  }) async {
    inspections++;
    if (request) requests++;
    return capability;
  }

  @override
  DateTime resolve(LocalDate d, int m) =>
      DateTime.utc(d.year, d.month, d.day, m ~/ 60, m % 60);
  @override
  Future<Set<int>> pendingIds() async => Set.of(pending);
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<void> schedule(
    int id,
    TaskReminder reminder, {
    required bool pt,
    required bool precise,
  }) async {
    if (fail || writes == failAfter) throw StateError('failed');
    pending.add(id);
    writes++;
  }
}

TaskReminder notificationFixture(String id, {DateTime? fireAt}) {
  final fire = fireAt ?? DateTime.utc(2026, 11, 19, 9);
  final start = fire.add(const Duration(hours: 1));
  return TaskReminder(
    occurrenceId: id,
    taskId: 'task-$id',
    title: 'Authored title',
    date: LocalDate(start.year, start.month, start.day),
    startAt: start,
    fireAt: fire,
  );
}
