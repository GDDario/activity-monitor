import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/calendar_database.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/repositories/calendar_repository.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/dashboard/views/dashboard_view.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';
import 'package:app/ui/people/views/people_view.dart';
import 'package:app/ui/profile/views/profile_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DashboardView()),
      GoRoute(path: '/people', builder: (context, state) => const PeopleView()),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarView(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
      ),
    ],
    errorBuilder: (context, state) => const _UnknownLocationView(),
  );
});

final httpClientProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final databaseDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);

final databaseInitializationProvider = FutureProvider<String>((ref) async {
  try {
    final directory = await ref.watch(databaseDirectoryProvider)();
    await Directory(directory.path).create(recursive: true);
    final path = '${directory.path}/activity_monitor.db';
    await compute(initializeDatabaseAtPath, path);
    return path;
  } catch (error) {
    debugPrint(
      'Database initialization failed (${error.runtimeType}); calendar data is unavailable.',
    );
    rethrow;
  }
});

final calendarDataProvider = FutureProvider<CalendarData>((ref) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  return compute(_readCalendar, path);
});

Future<CalendarData> _readCalendar(String path) async {
  final database = sqlite3.open(path, mode: OpenMode.readWrite);
  try {
    database.execute('PRAGMA foreign_keys = ON');
    return await CalendarRepository(CalendarDatabase(() async => database))
        .load();
  } finally {
    database.close();
  }
}

class _UnknownLocationView extends StatelessWidget {
  const _UnknownLocationView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This page is unavailable.')),
    );
  }
}
