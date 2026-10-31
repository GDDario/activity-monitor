import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/widgets/application_shell.dart';

class ScreenTitleBar extends StatelessWidget {
  const ScreenTitleBar({super.key, required this.title, required this.phrase});

  final String title;
  final String phrase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Semantics(
          button: true,
          container: true,
          label: 'Profile initials AM',
          child: InkResponse(
            onTap: () => context.go(AppDestination.profile.path),
            radius: 28,
            child: const ExcludeSemantics(
              child: CircleAvatar(
                radius: 24,
                backgroundColor: ActivityColors.primarySoft,
                child: Text('AM'),
              ),
            ),
          ),
        ),
        const SizedBox(width: ActivitySpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(phrase, style: textTheme.bodySmall),
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  color: ActivityColors.primary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Open calendar',
          onPressed: () => context.go(AppDestination.calendar.path),
          icon: const Icon(Icons.calendar_today_outlined),
        ),
        IconButton(
          tooltip: 'Open notifications',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications are not available yet.'),
              ),
            );
          },
          icon: const Icon(Icons.notifications_none_outlined),
        ),
      ],
    );
  }
}
