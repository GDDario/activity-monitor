import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/dependencies/notification_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/data/repositories/notification_repository.dart';

import 'helpers/fake_notification_service.dart';
import 'helpers/profile_ready.dart';

void main() {
  testWidgets(
    'foreground timer pauses in background and refreshes once on resume',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final store = MemoryNotificationStore(),
          service = FakeNotificationService();
      final container = ProviderContainer(
        overrides: [
          ...profileReadyOverrides(),
          notificationRepositoryProvider.overrideWith(
            (ref) async => LocalNotificationRepository(store, service),
          ),
          taskChangesProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.tapsController.close();
      });
      final model = await container.read(notificationViewModelProvider.future);
      await model.refresh();
      final initial = service.inspections;
      await tester.pump(const Duration(minutes: 1));
      expect(service.inspections, greaterThan(initial));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = service.inspections;
      await tester.pump(const Duration(minutes: 3));
      expect(service.inspections, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.inspections, paused + 1);
    },
  );
}
