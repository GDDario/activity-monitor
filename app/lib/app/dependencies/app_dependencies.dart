import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/calendar_database.dart';
import 'package:app/app/dependencies/database_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/ui/calendar/view_models/calendar_state.dart';
import 'package:app/data/repositories/calendar_repository.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/dashboard/views/dashboard_view.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';
import 'package:app/ui/people/views/people_view.dart';
import 'package:app/ui/profile/views/profile_view.dart';

export 'database_dependencies.dart';

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

class CalendarRangeRequest {
  LocalDateRange? value;
}

final calendarRangeRequestProvider = Provider((ref) => CalendarRangeRequest());

final calendarDataProvider = FutureProvider<CalendarData>((ref) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  final days = CalendarState(ref.read(taskClockProvider)()).visibleDays;
  LocalDate local(DateTime d) => LocalDate(d.year, d.month, d.day);
  final range =
      ref.read(calendarRangeRequestProvider).value ??
      LocalDateRange(local(days.first), local(days.last));
  final result = await ref.read(ensureTaskRangeProvider)(range);
  if (!result.isSuccess) throw StateError('Calendar data unavailable');
  return compute(_readCalendar, (path, range));
});

final calendarViewModelProvider = Provider.autoDispose<CalendarViewModel>((
  ref,
) {
  late final CalendarViewModel model;
  model = CalendarViewModel(
    ref.read(taskClockProvider)(),
    () {
      final days = model.calendar.visibleDays;
      LocalDate local(DateTime d) => LocalDate(d.year, d.month, d.day);
      ref.read(calendarRangeRequestProvider).value = LocalDateRange(
        local(days.first),
        local(days.last),
      );
      ref.invalidate(calendarDataProvider);
      return ref.read(calendarDataProvider.future);
    },
    reloadOnNavigation: true,
    loadStreaks: (data) async {
      final ids = data.entries
          .map((e) => e.taskAggregate?.task.id)
          .nonNulls
          .toSet();
      final now = ref.read(taskClockProvider)().toLocal();
      final result = await ref.read(taskStreakLoaderProvider)(
        ids,
        LocalDate(now.year, now.month, now.day),
      );
      if (!result.isSuccess) {
        throw StateError('Calendar streak data unavailable');
      }
      return {for (final e in result.value!.entries) e.key.value: e.value};
    },
  );
  ref.listen(taskChangesProvider, (_, value) {
    value.whenData((_) => unawaited(model.load()));
  });
  ref.onDispose(model.dispose);
  unawaited(model.load());
  return model;
});

Future<CalendarData> _readCalendar((String, LocalDateRange) input) async {
  final database = sqlite3.open(input.$1, mode: OpenMode.readWrite);
  try {
    database.execute('PRAGMA foreign_keys = ON');
    return await CalendarRepository(CalendarDatabase(() async => database))
        .load(range: input.$2);
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
