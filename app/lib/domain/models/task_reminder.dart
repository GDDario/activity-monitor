import 'dart:convert';

import 'package:app/domain/value_objects/local_date.dart';

class TaskReminder {
  const TaskReminder({
    required this.occurrenceId,
    required this.taskId,
    required this.title,
    required this.date,
    required this.startAt,
    required this.fireAt,
  });
  final String occurrenceId, taskId, title;
  final LocalDate date;
  final DateTime startAt, fireAt;
  String get payload => jsonEncode({
    'v': 1,
    'task': taskId,
    'occurrence': occurrenceId,
    'date': date.toString(),
  });
}

class ReminderTap {
  const ReminderTap(this.taskId, this.occurrenceId, this.date);
  final String taskId, occurrenceId;
  final LocalDate date;
  static ReminderTap? parse(String? raw) {
    if (raw == null || raw.length > 1024) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map || m['v'] != 1) return null;
      final task = m['task'], occurrence = m['occurrence'];
      final safe = RegExp(r'^[a-zA-Z0-9-]{1,100}$');
      if (task is! String ||
          occurrence is! String ||
          !safe.hasMatch(task) ||
          !safe.hasMatch(occurrence)) {
        return null;
      }
      return ReminderTap(
        task,
        occurrence,
        LocalDate.parse(m['date'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

enum ReminderAvailability { off, ready, denied, unsupported, unavailable }

class ReminderCapability {
  const ReminderCapability({
    this.supported = true,
    this.allowed = false,
    this.precise = false,
    this.zone = 'UTC',
  });
  final bool supported, allowed, precise;
  final String zone;
}

class ReminderSnapshot {
  ReminderSnapshot({
    required this.enabled,
    required this.availability,
    this.precise = false,
    List<TaskReminder> queued = const [],
  }) : queued = List.unmodifiable(queued);
  final bool enabled, precise;
  final ReminderAvailability availability;
  final List<TaskReminder> queued;
}
