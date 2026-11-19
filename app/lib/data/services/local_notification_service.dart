import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/domain/value_objects/local_date.dart';

abstract class LocalNotificationService {
  Stream<String> get taps;
  Future<ReminderCapability> inspect({
    bool request = false,
    bool timing = false,
  });
  DateTime resolve(LocalDate date, int minute);
  Future<Set<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule(
    int id,
    TaskReminder reminder, {
    required bool pt,
    required bool precise,
  });
}

class NativeLocalNotificationService implements LocalNotificationService {
  NativeLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _ready;
  static const channelId = 'task_reminders';
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Stream<String> get taps => _taps.stream;
  Future<void> _initialize() async {
    zones.initializeTimeZones();
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    if (initialized != true) throw StateError('Notifications unavailable');
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'Task reminders',
            description: 'Reminders for scheduled tasks',
            importance: Importance.high,
          ),
        );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      _taps.add(payload);
    }
  }

  @override
  Future<ReminderCapability> inspect({
    bool request = false,
    bool timing = false,
  }) async {
    if (!supported) return const ReminderCapability(supported: false);
    try {
      await (_ready ??= _initialize());
    } catch (_) {
      _ready = null;
      rethrow;
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (request) await android.requestNotificationsPermission();
      if (timing) await android.requestExactAlarmsPermission();
      final channels = await android.getNotificationChannels();
      final blocked =
          channels?.any(
            (c) => c.id == channelId && c.importance == Importance.none,
          ) ??
          false;
      return ReminderCapability(
        allowed: !blocked && (await android.areNotificationsEnabled() ?? false),
        precise: await android.canScheduleExactNotifications() ?? false,
        zone: zone.identifier,
      );
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (request) await ios?.requestPermissions(alert: true, sound: true);
    final permission = await ios?.checkPermissions();
    return ReminderCapability(
      allowed:
          permission?.isEnabled == true && permission?.isAlertEnabled == true,
      precise: true,
      zone: zone.identifier,
    );
  }

  @override
  DateTime resolve(LocalDate date, int minute) => tz.TZDateTime(
    tz.local,
    date.year,
    date.month,
    date.day,
    minute ~/ 60,
    minute % 60,
  );
  @override
  Future<Set<int>> pendingIds() async => {
    for (final item in await _plugin.pendingNotificationRequests()) item.id,
  };
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> schedule(
    int id,
    TaskReminder reminder, {
    required bool pt,
    required bool precise,
  }) async {
    final start = tz.TZDateTime.from(reminder.startAt, tz.local);
    final date =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    await _plugin.zonedSchedule(
      id: id,
      title: reminder.title,
      body: pt
          ? 'Sua tarefa começa em $date às $time.'
          : 'Your task starts on $date at $time.',
      scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Task reminders',
          channelDescription: 'Reminders for scheduled tasks',
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: precise
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
  }

  Future<void> dispose() => _taps.close();
}
