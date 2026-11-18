import 'package:flutter/material.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/dashboard/home_localizations.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';

class HomeAgenda extends StatelessWidget {
  const HomeAgenda({
    super.key,
    required this.sections,
    required this.actions,
    required this.streaks,
    required this.onEdit,
  });
  final List<DailyAgendaSection> sections;
  final TaskActionsViewModel actions;
  final Map<TaskId, int> streaks;
  final ValueChanged<TaskAggregate> onEdit;
  @override
  Widget build(BuildContext context) {
    final l = HomeLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.section(section.period),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ActivityColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      l.tasks(section.entries.length),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final aggregate in section.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TaskCard(
                key: ValueKey(aggregate.occurrence.id),
                aggregate: aggregate,
                actions: actions,
                streak: streaks[aggregate.task.id],
                onEdit: () => onEdit(aggregate),
                showNotesPreview: true,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
