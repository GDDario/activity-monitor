import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/activity_monitor_app.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/app/profile_route_policy.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

import 'helpers/fake_profile_repository.dart';
import 'helpers/fake_task_repository.dart';

void main() {
  test('setup policy retains only a safe requested destination and stops redirecting after setup', () {
    final policy = ProfileRoutePolicy();
    expect(
      policy.redirect(const ProfileSessionState(), '/calendar'),
      '/profile',
    );
    expect(
      policy.redirect(
        const ProfileSessionState(status: ProfileStatus.setupRequired),
        '/profile',
      ),
      isNull,
    );
    final ready = ProfileSessionState(
      status: ProfileStatus.ready,
      profile: exampleProfile(),
    );
    expect(policy.redirect(ready, '/profile'), '/calendar');
    expect(policy.redirect(ready, '/profile'), isNull);
  });
  testWidgets(
    'first setup blocks navigation then opens Home with saved real identity',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeProfileRepository();
      final tasks = FakeTaskRepository();
      addTearDown(repo.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWith((ref) async => repo),
            taskRepositoryProvider.overrideWith((ref) async => tasks),
            taskClockProvider.overrideWithValue(
              () => DateTime(2026, 11, 18, 9),
            ),
          ],
          child: const ActivityMonitorApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to your rhythm'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome to your rhythm'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Robin Ward',
      );
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Good morning, Robin Ward'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testWidgets('setup returns to an initial valid Calendar deep link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.defaultRouteNameTestValue = '/calendar';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final repo = FakeProfileRepository(), tasks = FakeTaskRepository();
    addTearDown(repo.dispose);
    addTearDown(tasks.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseInitializationProvider.overrideWith((ref) async => 'unused'),
          profileRepositoryProvider.overrideWith((ref) async => repo),
          taskRepositoryProvider.overrideWith((ref) async => tasks),
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: const ActivityMonitorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to your rhythm'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Robin');
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ActivityMonitorApp)),
    );
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/calendar',
    );
    expect(find.text('Calendar'), findsWidgets);
  });
  testWidgets('unavailable profile store cannot silently open writable setup', (
    tester,
  ) async {
    final repo = FakeProfileRepository()
      ..failure = ProfileFailure.storageUnavailable;
    final tasks = FakeTaskRepository();
    addTearDown(repo.dispose);
    addTearDown(tasks.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseInitializationProvider.overrideWith((ref) async => 'unused'),
          profileRepositoryProvider.overrideWith((ref) async => repo),
          taskRepositoryProvider.overrideWith((ref) async => tasks),
        ],
        child: const ActivityMonitorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your profile is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-name')), findsNothing);
    expect(repo.saves, 0);
    repo.failure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to your rhythm'), findsOneWidget);
    expect(repo.profile, isNull);
    expect(repo.saves, 0);
  });
}
