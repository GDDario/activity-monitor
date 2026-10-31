import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';

class BaseDestinationView extends StatelessWidget {
  const BaseDestinationView({
    super.key,
    required this.destination,
    required this.title,
    required this.phrase,
    required this.description,
    required this.icon,
  });

  final AppDestination destination;
  final String title;
  final String phrase;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ApplicationShell(
      destination: destination,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ActivitySpace.md,
          ActivitySpace.lg,
          ActivitySpace.md,
          112,
        ),
        children: [
          ScreenTitleBar(title: title, phrase: phrase),
          const SizedBox(height: ActivitySpace.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(ActivitySpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: ActivityColors.primary, size: 32),
                  const SizedBox(height: ActivitySpace.md),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: ActivitySpace.sm),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
