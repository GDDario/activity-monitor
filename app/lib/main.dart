import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/activity_monitor_app.dart';

void main() {
  runApp(const ProviderScope(child: ActivityMonitorApp()));
}
