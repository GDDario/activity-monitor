import 'package:app/data/repositories/notification_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/use_cases/build_reminder_queue.dart';

class ReconcileReminders {
  const ReconcileReminders({
    required this.repository,
    required this.load,
    required this.clock,
    required this.portuguese,
  });
  final NotificationRepository repository;
  final Future<TaskResult<List<TaskAggregate>>> Function(LocalDateRange) load;
  final DateTime Function() clock;
  final bool Function() portuguese;
  Future<ReminderSnapshot> execute({
    bool request = false,
    bool timing = false,
  }) async {
    var enabled = false;
    try {
      enabled = await repository.getEnabled();
      final c = await repository.capability(request: request, timing: timing);
      if (!enabled || !c.supported || !c.allowed) {
        return await repository.refresh([], pt: portuguese(), capability: c);
      }
      final now = clock();
      final today = LocalDate(now.year, now.month, now.day);
      final tasks = await load(LocalDateRange(today, today.addDays(31)));
      if (!tasks.isSuccess) {
        return ReminderSnapshot(
          enabled: enabled,
          availability: ReminderAvailability.unavailable,
        );
      }
      final desired = const BuildReminderQueue().execute(
        tasks.value!,
        now: now,
        resolve: repository.resolve,
      );
      return await repository.refresh(desired, pt: portuguese(), capability: c);
    } catch (_) {
      return ReminderSnapshot(
        enabled: enabled,
        availability: ReminderAvailability.unavailable,
      );
    }
  }
}
