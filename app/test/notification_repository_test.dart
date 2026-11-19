import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/notification_repository.dart';
import 'package:app/domain/models/task_reminder.dart';

import 'helpers/fake_notification_service.dart';

void main() {
  late MemoryNotificationStore store;
  late FakeNotificationService service;
  late LocalNotificationRepository repo;
  setUp(() {
    store = MemoryNotificationStore();
    service = FakeNotificationService();
    repo = LocalNotificationRepository(store, service);
  });
  tearDown(() async {
    await service.tapsController.close();
  });
  test(
    'startup never requests permission and disabled or denied cancels queue',
    () async {
      service.pending.add(9);
      expect(
        (await repo.refresh([
          notificationFixture('a'),
        ], pt: false)).availability,
        ReminderAvailability.off,
      );
      expect(service.pending, isEmpty);
      expect(service.requests, 0);
      await repo.setEnabled(true);
      service.capability = const ReminderCapability(allowed: false);
      expect(
        (await repo.refresh([], pt: false)).availability,
        ReminderAvailability.denied,
      );
    },
  );
  test('stable ids and unchanged refresh avoid duplicate schedules; deletion cancels', () async {
    await repo.setEnabled(true);
    await repo.refresh([notificationFixture('a')], pt: false);
    await repo.refresh([notificationFixture('a')], pt: false);
    expect(service.writes, 1);
    await repo.refresh([], pt: false);
    expect(service.pending, isEmpty);
  });
  test('locale or zone changes update pending content and a retry repairs partial failure', () async {
    await repo.setEnabled(true);
    await repo.refresh([notificationFixture('a')], pt: false);
    await repo.refresh([notificationFixture('a')], pt: true);
    expect(service.writes, 2);
    service.fail = true;
    final failed = await repo.refresh([notificationFixture('b')], pt: true);
    expect(failed.availability, ReminderAvailability.unavailable);
    expect(service.pending, isEmpty);
    service.fail = false;
    final recovered = await repo.refresh([notificationFixture('b')], pt: true);
    expect(recovered.queued.single.occurrenceId, 'b');
    expect(service.pending.length, 1);
  });
  test('reopened repository repairs content once while keeping persisted native ids', () async {
    await repo.setEnabled(true);
    await repo.refresh([notificationFixture('a')], pt: false);
    final before = service.pending.single;
    repo = LocalNotificationRepository(store, service);
    await repo.refresh([notificationFixture('a')], pt: false);
    expect(service.pending.single, before);
    expect(service.writes, 2);
  });
  test(
    'unsupported is explicit and storage failure cannot become empty success',
    () async {
      service.capability = const ReminderCapability(supported: false);
      expect(
        (await repo.refresh([], pt: false)).availability,
        ReminderAvailability.unsupported,
      );
      store.fail = true;
      expect(
        (await repo.refresh([], pt: false)).availability,
        ReminderAvailability.unavailable,
      );
    },
  );
  test('partial native failure retries only missing entries', () async {
    await repo.setEnabled(true);
    service.failAfter = 1;
    final desired = [notificationFixture('a'), notificationFixture('b')];
    final partial = await repo.refresh(desired, pt: false);
    expect(partial.availability, ReminderAvailability.unavailable);
    expect(partial.queued, isEmpty);
    expect(service.pending.length, 1);
    service.failAfter = null;
    final repaired = await repo.refresh(desired, pt: false);
    expect(repaired.queued.length, 2);
    expect(service.pending.length, 2);
    expect(service.writes, 2);
  });
}
