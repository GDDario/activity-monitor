import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';

import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/dashboard/home_localizations.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSessionProvider);
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) {
        final l = HomeLocalizations.of(context);
        return ScreenTitleBar(
          title:
              '${l.greeting(now.hour)}${profile.state.profile == null ? '' : ', ${profile.state.profile!.name.value}'}',
          titleStyle: Theme.of(context).textTheme.headlineSmall,
          phrase:
              '${MaterialLocalizations.of(context).formatMediumDate(now)} · ${l.text('phrase')}',
        );
      },
    );
  }
}
