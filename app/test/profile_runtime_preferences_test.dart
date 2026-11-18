import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/activity_monitor_app.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/local_profile.dart';

import 'helpers/fake_profile_repository.dart';
import 'helpers/fake_task_repository.dart';

Future<void> boot(
  WidgetTester tester,
  FakeProfileRepository profile,
  FakeTaskRepository tasks,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseInitializationProvider.overrideWith((ref) async => 'unused'),
        profileRepositoryProvider.overrideWith((ref) async => profile),
        taskRepositoryProvider.overrideWith((ref) async => tasks),
      ],
      child: const ActivityMonitorApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'editing saves explicit theme language and name then shows localized success',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeProfileRepository(profile: exampleProfile()),
          tasks = FakeTaskRepository();
      addTearDown(repo.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      await boot(tester, repo, tasks);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Renée',
      );
      await tester.tap(find.text('Dark'));
      await tester.tap(find.text('Português (Brasil)'));
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil salvo'), findsOneWidget);
      expect(find.text('Renée'), findsOneWidget);
      expect(find.text('Escura'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(
        Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
        const Locale('pt', 'BR'),
      );
    },
  );
  testWidgets(
    'device preferences react at runtime while explicit choices remain authoritative',
    (tester) async {
      final repo = FakeProfileRepository(
            profile: LocalProfile(id: 'p', name: ProfileName('Robin')),
          ),
          tasks = FakeTaskRepository();
      addTearDown(repo.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.localesTestValue = [const Locale('pt', 'PT')];
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await boot(tester, repo, tasks);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(
        Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
        const Locale('pt', 'BR'),
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'GB')];
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      expect(
        Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
        const Locale('en', 'US'),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ActivityMonitorApp)),
      );
      container
          .read(profileSessionProvider)
          .accept(
            LocalProfile(
              id: 'p',
              name: ProfileName('Robin'),
              appearance: ProfileAppearance.dark,
              language: ProfileLanguage.ptBr,
              revision: 1,
            ),
          );
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      tester.platformDispatcher.localesTestValue = [const Locale('fr', 'FR')];
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(
        Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
        const Locale('pt', 'BR'),
      );
      container.read(appRouterProvider).go('/missing');
      await tester.pumpAndSettle();
      expect(find.text('Esta página está indisponível.'), findsOneWidget);
    },
  );
  testWidgets(
    'discarded edits leave committed identity and appearance unchanged',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeProfileRepository(profile: exampleProfile()),
          tasks = FakeTaskRepository();
      addTearDown(repo.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      await boot(tester, repo, tasks);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Unsaved',
      );
      await tester.tap(find.text('Dark'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      expect(find.text('Robin Ward'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
    },
  );
  testWidgets(
    'corrupt saved avatar falls back to initials without resetting profile',
    (tester) async {
      final repo = FakeProfileRepository(
            profile: LocalProfile(
              id: 'p',
              name: ProfileName('Robin Ward'),
              avatar: Uint8List.fromList([1, 2, 3]),
            ),
          ),
          tasks = FakeTaskRepository();
      addTearDown(repo.dispose);
      addTearDown(tasks.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      await boot(tester, repo, tasks);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.text('RW'), findsOneWidget);
      expect(repo.profile!.name.value, 'Robin Ward');
      expect(repo.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
