import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/daily_overview.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/dashboard/home_localizations.dart';
import 'package:app/ui/dashboard/widgets/home_agenda.dart';
import 'package:app/ui/dashboard/widgets/home_filters.dart';
import 'package:app/ui/dashboard/widgets/home_header.dart';
import 'package:app/ui/dashboard/widgets/home_summary.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/views/open_task_editor.dart';
import 'package:app/ui/tasks/widgets/task_undo_banner.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(todayViewModelProvider),
        actions = ref.watch(taskActionsViewModelProvider);
    final l = TaskLocalizations.of(context),
        home = HomeLocalizations.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final state = model.state, overview = state.overview;
        return ApplicationShell(
          destination: AppDestination.today,
          floatingActionButton: FloatingActionButton(
            tooltip: l.text('createTask'),
            onPressed: state.isLoading || state.failure != null
                ? null
                : () => openTaskEditor(
                    context,
                    ref,
                    TaskEditorRequest(date: model.today),
                  ),
            backgroundColor: ActivityPalette.of(context).primary,
            foregroundColor: ActivityPalette.of(context).onPrimary,
            child: const Icon(Icons.add),
          ),
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 192),
                children: [
                  HomeHeader(now: state.now),
                  const SizedBox(height: 16),
                  HomeFilters(
                    scope: state.scope,
                    companions: overview?.companions ?? [],
                    onSelected: model.setScope,
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
                  ] else if (overview != null) ...[
                    HomeSummary(progress: overview.progress),
                    const SizedBox(height: 24),
                    if (overview.entries.isEmpty) ...[
                      Text(
                        state.scope == const DailyTaskScope.all()
                            ? l.text('empty')
                            : home.text('filterEmpty'),
                      ),
                      TextButton(
                        onPressed: () =>
                            model.setScope(const DailyTaskScope.all()),
                        child: Text(home.text('reset')),
                      ),
                    ],
                    HomeAgenda(
                      sections: overview.sections,
                      actions: actions,
                      streaks: state.streaks,
                      onEdit: (aggregate) => openTaskEditor(
                        context,
                        ref,
                        TaskEditorRequest(
                          date: aggregate.occurrence.effectiveDate,
                          taskId: aggregate.task.id,
                          occurrenceId: aggregate.occurrence.id,
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
