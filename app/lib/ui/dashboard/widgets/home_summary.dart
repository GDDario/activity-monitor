import 'package:flutter/material.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/dashboard/home_localizations.dart';

class HomeSummary extends StatelessWidget {
  const HomeSummary({super.key, required this.progress});
  final DailyProgress progress;
  @override
  Widget build(BuildContext context) {
    final l = HomeLocalizations.of(context), theme = Theme.of(context);
    final next = progress.next;
    final window = next?.occurrence.timeWindow;
    final nextText = next == null || window == null
        ? l.text('noNext')
        : '${l.text('next')}: ${TimeOfDay(hour: window.startMinute ~/ 60, minute: window.startMinute % 60).format(context)} · ${next.task.title.value}';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ActivityColors.outline.withValues(alpha: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 270 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ActivityColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      l.text('rhythm').toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ActivityColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.completed(progress.completed, progress.total),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  progress.total == 0
                      ? l.text('emptyGuidance')
                      : l.remaining(progress.pending),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ActivityColors.mutedInk,
                  ),
                ),
              ],
            );
            final ring = Semantics(
              label: l.text('progress'),
              value: '${progress.percentage}%',
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: stack ? 96 : 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: progress.fraction,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: ActivityColors.primaryContainer,
                          backgroundColor: ActivityColors.surfaceStrong,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${progress.percentage}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: ActivityColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stack) ...[
                  copy,
                  const SizedBox(height: 20),
                  ring,
                ] else
                  Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 20),
                      ring,
                    ],
                  ),
                const Divider(height: 32, color: ActivityColors.surfaceStrong),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      icon: Icons.schedule,
                      text: nextText,
                      maxWidth: constraints.maxWidth,
                    ),
                    _Metric(
                      icon: Icons.group_outlined,
                      text: l.collaborative(progress.collaborative),
                      maxWidth: constraints.maxWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.text,
    required this.maxWidth,
  });
  final IconData icon;
  final String text;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: ActivityColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: ActivityColors.mutedInk),
          ),
        ),
      ],
    ),
  );
}
