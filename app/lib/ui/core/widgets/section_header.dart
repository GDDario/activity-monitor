import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ActivityColors.surfaceStrong,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(detail, style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    );
  }
}
