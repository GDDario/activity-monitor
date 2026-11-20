import 'package:flutter/material.dart';

import 'package:app/ui/tracking/tracking_strings.dart';

Future<bool> confirmTrackingDiscard(BuildContext context, bool dirty) async {
  if (!dirty) return true;
  final l = TrackingStrings.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            l.tr(
              'Discard unsaved changes?',
              'Descartar alterações não salvas?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l.tr('Keep editing', 'Continuar editando')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.tr('Discard', 'Descartar')),
            ),
          ],
        ),
      ) ??
      false;
}

class TrackingSurface extends StatelessWidget {
  const TrackingSurface({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.footer,
    this.busy = false,
    this.dirty = false,
  });
  final String title;
  final Widget child;
  final VoidCallback onClose;
  final Widget? footer;
  final bool busy, dirty;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onClose();
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: wide ? 32 : 0,
          vertical: wide ? 24 : 0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.sizeOf(context).height - (wide ? 48 : 0),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: TrackingStrings.of(context).text('close'),
                        onPressed: busy ? null : onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: busy,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: child,
                    ),
                  ),
                ),
                if (footer != null)
                  Padding(padding: const EdgeInsets.all(16), child: footer!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
