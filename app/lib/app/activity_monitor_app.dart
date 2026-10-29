import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/dashboard/views/dashboard_view.dart';

class ActivityMonitorApp extends StatelessWidget {
  const ActivityMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Monitor',
      debugShowCheckedModeBanner: false,
      theme: ActivityTheme.light(),
      home: const DashboardView(),
    );
  }
}
