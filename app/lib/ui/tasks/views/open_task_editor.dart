import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/views/task_editor_sheet.dart';

Future<void> openTaskEditor(
  BuildContext context,
  WidgetRef ref,
  TaskEditorRequest request,
) async {
  final factory = ref.read(taskEditorFactoryProvider);
  try {
    final model = await factory(request);
    if (!context.mounted) {
      model.dispose();
      return;
    }
    try {
      await TaskEditorSheet.show(context, model);
      if (context.mounted && model.state.hasSaved) {
        if (MediaQuery.supportsAnnounceOf(context)) {
          await SemanticsService.sendAnnouncement(
            View.of(context),
            TaskLocalizations.of(context).text('taskSaved'),
            Directionality.of(context),
          );
        }
      }
    } finally {
      model.dispose();
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TaskLocalizations.of(context).text('unavailable')),
        ),
      );
    }
  }
}
