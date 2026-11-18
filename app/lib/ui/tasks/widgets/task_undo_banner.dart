import 'package:flutter/material.dart';

import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';

class TaskUndoBanner extends StatelessWidget {
  const TaskUndoBanner({super.key, required this.model});
  final TaskActionsViewModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final accessible = MediaQuery.accessibleNavigationOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) model.setAccessibleNavigation(accessible);
      });
      final localizations = TaskLocalizations.of(context);
      final message = model.failure != null
          ? localizations.failure(model.failure!)
          : model.messageKey == null
          ? null
          : localizations.text(model.messageKey!);
      if (message == null) return const SizedBox.shrink();
      final copy = Text(
        message,
        style: const TextStyle(color: Color(0xffeff1ed)),
      );
      final recovery = <Widget>[
        if (model.canUndo) ...[
          Text(
            '${model.remainingSeconds}s',
            style: const TextStyle(color: Color(0xffc1c9c1)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffa2d1b5),
              disabledForegroundColor: const Color(0xffc1c9c1),
              minimumSize: const Size(48, 48),
            ),
            onPressed: model.isUndoPending
                ? null
                : () => model.undoLatest(sequence: model.undoSequence),
            child: Text(localizations.text('undo')),
          ),
        ],
      ];
      return Focus(
        onFocusChange: model.setFocused,
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: const Color(0xff2e312f),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 360 &&
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        copy,
                        if (recovery.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: recovery,
                          ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy),
                      ...recovery,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
