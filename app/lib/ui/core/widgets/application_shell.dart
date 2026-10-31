import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:app/ui/core/theme/activity_theme.dart';

enum AppDestination {
  today('/', 'Today', Icons.wb_sunny_outlined),
  people('/people', 'People', Icons.group_outlined),
  calendar('/calendar', 'Calendar', Icons.calendar_month_outlined),
  profile('/profile', 'Profile', Icons.person_outline);

  const AppDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

class ApplicationShell extends StatelessWidget {
  const ApplicationShell({
    super.key,
    required this.destination,
    required this.child,
  });

  static const _wideLayoutBreakpoint = 840.0;

  final AppDestination destination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (isWide) _SideNavigation(destination: destination),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isWide
              ? null
              : _BottomNavigation(destination: destination),
        );
      },
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: destination.index,
      onDestinationSelected: (index) => _navigateTo(context, index),
      destinations: [
        for (final destination in AppDestination.values)
          NavigationDestination(
            icon: Icon(destination.icon),
            label: destination.label,
          ),
      ],
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: destination.index,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (index) => _navigateTo(context, index),
      leading: const Padding(
        padding: EdgeInsets.all(ActivitySpace.md),
        child: CircleAvatar(
          backgroundColor: ActivityColors.primarySoft,
          child: Icon(Icons.spa_outlined, color: ActivityColors.primary),
        ),
      ),
      destinations: [
        for (final destination in AppDestination.values)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

void _navigateTo(BuildContext context, int index) {
  context.go(AppDestination.values[index].path);
}
