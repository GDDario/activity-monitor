import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:flutter/material.dart';

import 'package:app/domain/models/task.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';

import 'swipe_task_card.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.aggregate,
    required this.actions,
    required this.onEdit,
    this.streak,
    this.showNotesPreview = false,
  });
  final TaskAggregate aggregate;
  final TaskActionsViewModel actions;
  final VoidCallback onEdit;
  final int? streak;
  final bool showNotesPreview;

  @override
  Widget build(BuildContext context) {
    final l = TaskLocalizations.of(context);
    final task = aggregate.task;
    final occurrence = aggregate.occurrence;
    final cadence = switch (task.schedule.cadence) {
      TaskCadence.oneTime => 'oneTime',
      TaskCadence.daily => 'daily',
      TaskCadence.weekly => 'weekly',
    };
    return ListenableBuilder(
      listenable: actions,
      builder: (context, _) {
        final pending = actions.isPending(occurrence.id);
        return SwipeTaskCard(
          aggregate: aggregate,
          actions: actions,
          child: Card(
            margin: EdgeInsets.zero,
            color: occurrence.completed
                ? ActivityPalette.of(context).inputSurface
                : ActivityPalette.of(context).surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ActivityPalette.of(context).border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: l.text(
                          occurrence.completed ? 'reopen' : 'markDone',
                        ),
                        onPressed: pending
                            ? null
                            : () => actions.perform(
                                occurrence.completed
                                    ? TaskAction.reopen
                                    : TaskAction.complete,
                                aggregate,
                              ),
                        icon: Icon(
                          occurrence.completed
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: pending
                              ? null
                              : ActivityPalette.of(context).completionInk,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title.value,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    decoration: occurrence.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: occurrence.completed
                                        ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                        : null,
                                  ),
                            ),
                            if (showNotesPreview &&
                                task.notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                task.notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 4),
                            if (occurrence.completed)
                              Text(
                                occurrence.completedAtUtc == null
                                    ? l.text('completed')
                                    : '${l.text('completedAt')} ${TimeOfDay.fromDateTime(occurrence.completedAtUtc!.toLocal()).format(context)}',
                              ),
                            Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(
                                    DateTime(
                                      occurrence.effectiveDate.year,
                                      occurrence.effectiveDate.month,
                                      occurrence.effectiveDate.day,
                                    ),
                                  ),
                            ),
                            if (occurrence.timeWindow case final window?)
                              Text(
                                '${TimeOfDay(hour: window.startMinute ~/ 60, minute: window.startMinute % 60).format(context)} – ${TimeOfDay(hour: window.endMinute ~/ 60, minute: window.endMinute % 60).format(context)}',
                              ),
                            if (occurrence.reminder.minutesBefore
                                case final minutes?) ...[
                              Text(l.reminder(minutes)),
                              Text(l.text('reminderInactive')),
                            ],
                            if (streak != null &&
                                task.schedule.cadence == TaskCadence.daily &&
                                task.schedule.streakEnabled)
                              Text(l.streak(streak!)),
                            if (aggregate.subtaskTotal > 0) ...[
                              Text(
                                l.subtasks(
                                  aggregate.subtaskCompleted,
                                  aggregate.subtaskTotal,
                                ),
                              ),
                              LinearProgressIndicator(
                                value:
                                    aggregate.subtaskCompleted /
                                    aggregate.subtaskTotal,
                              ),
                            ],
                            if (task.participants.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final participant in task.participants)
                                    Text(participant.name),
                                ],
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l.text('actions'),
                        enabled: !pending,
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else {
                            actions.perform(switch (value) {
                              'delete' => TaskAction.delete,
                              'complete' => TaskAction.complete,
                              'reopen' => TaskAction.reopen,
                              _ => TaskAction.postpone,
                            }, aggregate);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: occurrence.completed ? 'reopen' : 'complete',
                            child: Text(
                              l.text(
                                occurrence.completed ? 'reopen' : 'markDone',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(l.text('edit')),
                          ),
                          if (!occurrence.completed)
                            PopupMenuItem(
                              value: 'postpone',
                              child: Text(l.text('postpone')),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l.text('delete')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(
                    height: 20,
                    color: ActivityPalette.of(context).border,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TaskBadge(
                        label: l.text(cadence),
                        color: task.schedule.cadence == TaskCadence.oneTime
                            ? ActivityPalette.of(context).neutralBadge
                            : ActivityPalette.of(context).selectedBadge,
                      ),
                      if (task.priority != TaskPriority.low)
                        _TaskBadge(
                          label: l.text(task.priority.name),
                          color: task.priority == TaskPriority.medium
                              ? ActivityPalette.of(context).mediumBadge
                              : ActivityPalette.of(context).highBadge,
                          foreground: task.priority == TaskPriority.medium
                              ? ActivityPalette.of(context).mediumInk
                              : ActivityPalette.of(context).highInk,
                        ),
                      for (final tag in task.tags)
                        _TaskBadge(
                          label: '#${tag.name.value}',
                          color: ActivityPalette.of(context).neutralBadge,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskBadge extends StatelessWidget {
  const _TaskBadge({required this.label, required this.color, this.foreground});
  final String label;
  final Color color;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground ?? ActivityPalette.of(context).badgeInk,
        ),
      ),
    ),
  );
}
