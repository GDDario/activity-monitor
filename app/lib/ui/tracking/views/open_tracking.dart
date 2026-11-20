import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/app/dependencies/tracking_dependencies.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/views/task_tracking_view.dart';
import 'package:app/ui/tracking/views/type_manager_view.dart';
import 'package:app/ui/tracking/widgets/tracking_surface.dart';

Future<void> openTypeManager(BuildContext context, WidgetRef ref) async {
  try {
    final model = await ref.read(trackingFactoryProvider)();
    try {
      await model.loadTypes();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TypeManagerView(model: model),
      );
    } finally {
      model.dispose();
    }
  } catch (_) {
    if (context.mounted) _unavailable(context);
  }
}

Future<void> openTaskTracking(
  BuildContext context,
  WidgetRef ref,
  String id, {
  VoidCallback? onEdit,
  TaskAggregate? aggregate,
}) async {
  try {
    final model = await ref.read(trackingFactoryProvider)();
    try {
      await model.load(id);
      if (!context.mounted) return;
      if (model.detail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TrackingStrings.of(context).error(model.failure)),
          ),
        );
        return;
      }
      final actions = ref.read(taskActionsViewModelProvider);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => TaskTrackingView(
          model: model,
          onEdit: onEdit,
          completionAction: aggregate == null
              ? null
              : TextButton(
                  onPressed: () async {
                    await actions.perform(
                      aggregate.occurrence.completed
                          ? TaskAction.reopen
                          : TaskAction.complete,
                      aggregate,
                    );
                    if (dialogContext.mounted && actions.failure == null) {
                      Navigator.pop(dialogContext);
                    } else if (dialogContext.mounted &&
                        actions.failure != null) {
                      await showDialog<void>(
                        context: dialogContext,
                        builder: (c) => AlertDialog(
                          content: Text(
                            TaskLocalizations.of(c).failure(actions.failure!),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: Text(TrackingStrings.of(c).text('close')),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Text(
                    TaskLocalizations.of(context).text(
                      aggregate.occurrence.completed ? 'reopen' : 'markDone',
                    ),
                  ),
                ),
        ),
      );
    } finally {
      model.dispose();
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TrackingStrings.of(context).error('storageUnavailable'),
          ),
        ),
      );
    }
  }
}

Future<void> openFinishedTasks(BuildContext context, WidgetRef ref) async {
  try {
    final model = await ref.read(trackingFactoryProvider)();
    try {
      await model.loadFinished();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => ListenableBuilder(
          listenable: model,
          builder: (c, _) {
            final l = TrackingStrings.of(c);
            return TrackingSurface(
              title: l.text('finished'),
              onClose: () => Navigator.pop(c),
              child: Column(
                children: [
                  if (model.failure != null) Text(l.error(model.failure)),
                  if (model.finished.isEmpty)
                    Text(
                      l.tr('No finished tasks.', 'Nenhuma tarefa finalizada.'),
                    ),
                  for (final task in model.finished)
                    ListTile(
                      title: Text(task.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await openTaskTracking(c, ref, task.id);
                        await model.loadFinished();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      model.dispose();
    }
  } catch (_) {
    if (context.mounted) _unavailable(context);
  }
}

void _unavailable(BuildContext context) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(TrackingStrings.of(context).error('storageUnavailable')),
      ),
    );
  }
}
