import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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

class _UnknownLocationView extends StatelessWidget {
  const _UnknownLocationView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This page is unavailable.')),
    );
  }
}
