import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/ui/core/theme/activity_theme.dart';

class ActivityMonitorApp extends ConsumerWidget {
  const ActivityMonitorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'Activity Monitor',
        debugShowCheckedModeBanner: false,
        theme: ActivityTheme.light(),
        routerConfig: ref.watch(appRouterProvider),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en')],
      ),
    );
  }
}
