import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_theme.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.statusLabel,
    this.isComplete = false,
  });

  final String title;
  final String description;
  final String timeLabel;
  final String statusLabel;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ActivitySpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isComplete
                  ? ActivityColors.primaryContainer
                  : ActivityColors.outline,
              semanticLabel: isComplete ? 'Completed' : 'Not completed',
            ),
            const SizedBox(width: ActivitySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: ActivitySpace.sm,
                    runSpacing: ActivitySpace.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: textTheme.headlineSmall?.copyWith(
                          decoration: isComplete
                              ? TextDecoration.lineThrough
                              : null,
                          color: isComplete ? ActivityColors.mutedInk : null,
                        ),
                      ),
                      _StatusChip(label: statusLabel),
                    ],
                  ),
                  const SizedBox(height: ActivitySpace.sm),
                  Text(description, style: textTheme.bodySmall),
                  const SizedBox(height: ActivitySpace.md),
                  const Divider(height: 1),
                  const SizedBox(height: ActivitySpace.sm),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 16),
                      const SizedBox(width: ActivitySpace.xs),
                      Text(timeLabel, style: textTheme.labelMedium),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Activity options',
                        onPressed: () {},
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isPriority = label == 'High priority';
    final color = isPriority
        ? ActivityColors.secondary
        : ActivityColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
