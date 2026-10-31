import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/widgets/activity_card.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/core/widgets/section_header.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApplicationShell(
      destination: AppDestination.today,
      child: _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ActivitySpace.md,
        ActivitySpace.lg,
        ActivitySpace.md,
        112,
      ),
      children: const [
        ScreenTitleBar(
          title: 'Good morning',
          phrase: 'Today · Move with intention',
        ),
        SizedBox(height: ActivitySpace.md),
        _FilterBar(),
        SizedBox(height: ActivitySpace.lg),
        _ProgressCard(),
        SizedBox(height: ActivitySpace.xl),
        SectionHeader(title: 'Morning focus', detail: '2 activities'),
        SizedBox(height: ActivitySpace.md),
        ActivityCard(
          title: 'Read a chapter',
          description:
              'Continue the book you chose for this week’s reading rhythm.',
          timeLabel: '10:00 AM',
          statusLabel: 'High priority',
        ),
        SizedBox(height: ActivitySpace.md),
        ActivityCard(
          title: 'Plan the shared workout',
          description:
              'Confirm the routine and invite the people joining today.',
          timeLabel: '11:30 AM',
          statusLabel: 'With people',
          isComplete: true,
        ),
        SizedBox(height: ActivitySpace.xl),
        SectionHeader(title: 'Later today', detail: '2 activities'),
        SizedBox(height: ActivitySpace.md),
        ActivityCard(
          title: 'Focus session',
          description: 'A quiet 25-minute block for your next meaningful task.',
          timeLabel: '2:30 PM',
          statusLabel: 'Focus',
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DashboardFilterChip(
            selected: true,
            label: 'All activities',
            icon: Icons.view_agenda_outlined,
            onSelected: (_) {},
          ),
          const SizedBox(width: ActivitySpace.sm),
          _DashboardFilterChip(
            selected: false,
            label: 'Solo',
            icon: Icons.person_outline,
            onSelected: (_) {},
          ),
          const SizedBox(width: ActivitySpace.sm),
          _DashboardFilterChip(
            selected: false,
            label: 'Shared',
            icon: Icons.group_outlined,
            onSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

class _DashboardFilterChip extends StatelessWidget {
  const _DashboardFilterChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    const foregroundColor = ActivityColors.ink;
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: Icon(icon, size: 18, color: foregroundColor),
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: foregroundColor),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ActivitySpace.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RHYTHM OF THE DAY',
                    style: textTheme.labelMedium?.copyWith(
                      color: ActivityColors.primary,
                    ),
                  ),
                  const SizedBox(height: ActivitySpace.sm),
                  Text('4 of 7 completed', style: textTheme.headlineMedium),
                  const SizedBox(height: ActivitySpace.sm),
                  Text(
                    'Steady progress with deliberate pacing. Three activities remain.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ActivitySpace.md),
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: 4 / 7,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                backgroundColor: ActivityColors.surfaceStrong,
                color: ActivityColors.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
