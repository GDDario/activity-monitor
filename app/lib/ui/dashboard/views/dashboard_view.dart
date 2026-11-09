import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/dashboard/view_models/today_view_model.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/views/open_task_editor.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';
import 'package:app/ui/tasks/widgets/task_undo_banner.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(todayViewModelProvider);
    final actions = ref.watch(taskActionsViewModelProvider);
    final l = TaskLocalizations.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final state = model.state;
        return ApplicationShell(
          destination: AppDestination.today,
          floatingActionButton: FloatingActionButton(
            onPressed: state.isLoading || state.failure != null
                ? null
                : () => openTaskEditor(
                    context,
                    ref,
                    TaskEditorRequest(date: model.today),
                  ),
            backgroundColor: ActivityColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 192),
                children: [
                  ScreenTitleBar(
                    title: l.text('todayTitle'),
                    phrase: l.text('todayPhrase'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in TodayFilter.values)
                        FilterChip(
                          label: Text(l.text(filter.name)),
                          selected: state.filter == filter,
                          selectedColor: ActivityColors.primary,
                          backgroundColor: ActivityColors.surfaceMuted,
                          labelStyle: TextStyle(
                            color: state.filter == filter
                                ? Colors.white
                                : ActivityColors.mutedInk,
                          ),
                          showCheckmark: false,
                          side: BorderSide(
                            color: state.filter == filter
                                ? ActivityColors.primary
                                : ActivityColors.outline.withValues(alpha: .4),
                          ),
                          onSelected: (_) => model.setFilter(filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (state.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (state.failure case final failure?) ...[
                    Text(l.failure(failure)),
                    TextButton.icon(
                      onPressed: model.load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l.text('retry')),
                    ),
                  ] else ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: ActivityColors.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.text('progress').toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l.counts(
                                      model.pendingCount,
                                      model.doneCount,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ],
                              ),
                            ),
                            if (model.visible.isNotEmpty)
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: Semantics(
                                  label: l.counts(
                                    model.pendingCount,
                                    model.doneCount,
                                  ),
                                  child: CircularProgressIndicator(
                                    value:
                                        model.doneCount / model.visible.length,
                                    strokeWidth: 6,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        ActivityColors.surfaceStrong,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (model.visible.isEmpty) Text(l.text('empty')),
                    for (final aggregate in model.visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TaskCard(
                          aggregate: aggregate,
                          actions: actions,
                          streak: state.streaks[aggregate.task.id],
                          onEdit: () => openTaskEditor(
                            context,
                            ref,
                            TaskEditorRequest(
                              date: aggregate.occurrence.effectiveDate,
                              taskId: aggregate.task.id,
                              occurrenceId: aggregate.occurrence.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: TaskUndoBanner(model: actions),
              ),
            ],
          ),
        );
      },
    );
  }
}
