import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/data/repositories/notification_repository.dart';
import 'package:app/data/services/notification_database.dart';
import 'package:app/data/services/local_notification_service.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/use_cases/reconcile_reminders.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/ui/notifications/view_models/notification_view_model.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = NativeLocalNotificationService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  return LocalNotificationRepository(
    NotificationDatabase(path: path),
    ref.watch(localNotificationServiceProvider),
  );
});
final notificationViewModelProvider = FutureProvider<NotificationViewModel>((
  ref,
) async {
  final repository = await ref.watch(notificationRepositoryProvider.future);
  bool pt() {
    final language = ref.read(profileSessionProvider).state.profile?.language;
    if (language == ProfileLanguage.ptBr) return true;
    if (language == ProfileLanguage.enUs) return false;
    return resolveProfileLanguage(
          WidgetsBinding.instance.platformDispatcher.locales
              .map((l) => l.toLanguageTag())
              .toList(),
        ) ==
        ProfileLanguage.ptBr;
  }

  final reconcile = ReconcileReminders(
    repository: repository,
    load: ref.read(ensureTaskRangeProvider),
    clock: ref.read(taskClockProvider),
    portuguese: pt,
  );
  final model = NotificationViewModel(
    refresh: reconcile.execute,
    setEnabled: repository.setEnabled,
  );
  var disposed = false;
  final taps = repository.taps.listen((raw) async {
    final tap = ReminderTap.parse(raw);
    if (tap == null || disposed) return;
    try {
      final tasks = await ref.read(taskRepositoryProvider.future);
      final result = await tasks.loadTask(
        TaskId(tap.taskId),
        OccurrenceId(tap.occurrenceId),
      );
      if (disposed || !result.isSuccess || result.value!.occurrence.isDeleted) {
        return;
      }
      if (ref.read(profileSessionProvider).state.profile == null) return;
      final date = result.value!.occurrence.effectiveDate;
      ref
          .read(calendarViewModelProvider)
          .selectDate(DateTime(date.year, date.month, date.day));
      ref.read(appRouterProvider).go('/calendar');
    } catch (_) {
      /* A stale or unavailable notification cannot mutate task data. */
    }
  });
  ref.listen(taskChangesProvider, (_, v) {
    v.whenData((_) => unawaited(model.refresh()));
  });
  ref.listen(profileChangesProvider, (_, v) {
    v.whenData((_) => unawaited(model.refresh()));
  });
  Timer? timer;
  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(model.refresh()),
    );
  }

  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      timer?.cancel();
      timer = null;
      if (state == AppLifecycleState.resumed) {
        unawaited(model.refresh());
        startTimer();
      }
    },
  );
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    startTimer();
  }
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    lifecycle.dispose();
    unawaited(taps.cancel());
    model.dispose();
  });
  unawaited(model.refresh());
  return model;
});
