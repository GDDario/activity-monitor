import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/task_localizations.dart';

class SwipeTaskCard extends StatefulWidget {
  const SwipeTaskCard({
    super.key,
    required this.aggregate,
    required this.actions,
    required this.child,
  });
  final TaskAggregate aggregate;
  final TaskActionsViewModel actions;
  final Widget child;
  @override
  State<SwipeTaskCard> createState() => _SwipeTaskCardState();
}

class _SwipeTaskCardState extends State<SwipeTaskCard> {
  double offset = 0;
  double? startX;
  bool pointerCancelled = false;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Stack(
      children: [
        if (offset != 0)
          Positioned.fill(
            child: ColoredBox(
              color: offset < 0
                  ? const Color(0xff8a3822)
                  : const Color(0xff2e5a44),
              child: Align(
                alignment: offset < 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (offset > 0)
                        const Icon(Icons.check_circle, color: Colors.white),
                      if (offset > 0) const SizedBox(width: 8),
                      Text(
                        TaskLocalizations.of(context)
                            .text(offset < 0 ? 'delete' : 'done'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (offset < 0) const SizedBox(width: 8),
                      if (offset < 0)
                        const Icon(Icons.delete_outline, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (details) {
              pointerCancelled = false;
              startX = details.globalPosition.dx;
            },
            onHorizontalDragUpdate:
                widget.actions.isPending(widget.aggregate.occurrence.id)
                ? null
                : (d) => setState(
                    () => offset =
                        d.globalPosition.dx - (startX ?? d.globalPosition.dx),
                  ),
            onHorizontalDragCancel: () => setState(() => offset = 0),
            onHorizontalDragEnd: (details) {
              if (pointerCancelled) {
                setState(() => offset = 0);
                return;
              }
              final distance =
                  details.globalPosition.dx -
                  (startX ?? details.globalPosition.dx);
              final action = distance <= -90
                  ? TaskAction.delete
                  : distance >= 90 && !widget.aggregate.occurrence.completed
                  ? TaskAction.complete
                  : null;
              setState(() => offset = 0);
              if (action != null) {
                widget.actions.perform(action, widget.aggregate);
              }
            },
            child: Listener(
              onPointerCancel: (_) => pointerCancelled = true,
              child: widget.child,
            ),
          ),
        ),
      ],
    ),
  );
}
