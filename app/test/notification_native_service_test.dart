import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/services/local_notification_service.dart';

import 'helpers/fake_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const zoneChannel = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          zoneChannel,
          (call) async => 'America/Sao_Paulo',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': true,
              'notificationResponse': {
                'id': 1,
                'payload': notificationFixture('a').payload,
                'notificationResponseType': 0,
              },
            },
            'areNotificationsEnabled' => true,
            'canScheduleExactNotifications' => false,
            'getNotificationChannels' => [],
            'pendingNotificationRequests' => [],
            'requestNotificationsPermission' => true,
            'requestExactAlarmsPermission' => true,
            _ => null,
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, null);
  });
  test('native initialization has no permission prompt and supports cold-launch payload', () async {
    final service = NativeLocalNotificationService();
    addTearDown(service.dispose);
    final tap = service.taps.first;
    final c = await service.inspect();
    expect(c.allowed, true);
    expect(c.precise, false);
    expect(c.zone, 'America/Sao_Paulo');
    expect(calls.any((c) => c.method.startsWith('request')), false);
    expect(await tap, notificationFixture('a').payload);
    await service.inspect(request: true, timing: true);
    expect(calls.where((c) => c.method == 'initialize').length, 1);
    expect(
      calls.any((c) => c.method == 'requestNotificationsPermission'),
      true,
    );
  });
  test('native scheduling uses OS time-zone alarm, private visibility and selected locale', () async {
    final service = NativeLocalNotificationService();
    addTearDown(service.dispose);
    await service.inspect();
    final reminder = notificationFixture(
      'a',
      fireAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    await service.schedule(17, reminder, pt: true, precise: false);
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['id'], 17);
    expect(args['timeZoneName'], 'America/Sao_Paulo');
    expect(args['body'], contains('Sua tarefa'));
    expect(args['title'], 'Authored title');
    expect(args['payload'], reminder.payload);
    expect(args['platformSpecifics']['scheduleMode'], isNotNull);
    expect(
      args['platformSpecifics']['visibility'],
      NotificationVisibility.private.index,
    );
  });
}
