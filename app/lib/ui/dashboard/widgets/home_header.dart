import 'package:flutter/material.dart';

import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/dashboard/home_localizations.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final l = HomeLocalizations.of(context);
    return ScreenTitleBar(
      title: l.greeting(now.hour),
      titleStyle: Theme.of(context).textTheme.headlineSmall,
      phrase:
          '${MaterialLocalizations.of(context).formatMediumDate(now)} · ${l.text('phrase')}',
    );
  }
}
