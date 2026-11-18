import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/dashboard/home_localizations.dart';
import 'package:app/ui/tasks/task_localizations.dart';

class ActivityMonitorApp extends ConsumerStatefulWidget {
  const ActivityMonitorApp({super.key});
  @override
  ConsumerState<ActivityMonitorApp> createState() => _ActivityMonitorAppState();
}

class _ActivityMonitorAppState extends ConsumerState<ActivityMonitorApp> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(profileSessionProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseInitializationProvider);
    final session = ref.watch(profileSessionProvider);
    ref.listen(
      profileChangesProvider,
      (_, result) => result.whenData(session.accept),
    );
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final p = session.state.profile;
        return ToastificationWrapper(
          child: MaterialApp.router(
            title: 'Activity Monitor',
            debugShowCheckedModeBanner: false,
            theme: ActivityTheme.light(),
            darkTheme: ActivityTheme.dark(),
            themeMode: switch (p?.appearance) {
              ProfileAppearance.light => ThemeMode.light,
              ProfileAppearance.dark => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            locale: switch (p?.language) {
              ProfileLanguage.enUs => const Locale('en', 'US'),
              ProfileLanguage.ptBr => const Locale('pt', 'BR'),
              _ => null,
            },
            localeListResolutionCallback: (locales, supported) {
              final language = resolveProfileLanguage(
                (locales ?? []).map((l) => l.toLanguageTag()).toList(),
              );
              return language == ProfileLanguage.ptBr
                  ? const Locale('pt', 'BR')
                  : const Locale('en', 'US');
            },
            routerConfig: ref.watch(appRouterProvider),
            localizationsDelegates: const [
              TaskLocalizationsDelegate(),
              HomeLocalizationsDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
          ),
        );
      },
    );
  }
}
