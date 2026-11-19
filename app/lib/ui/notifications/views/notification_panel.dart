import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/notification_dependencies.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/ui/notifications/notification_localizations.dart';
import 'package:app/ui/notifications/view_models/notification_view_model.dart';

Future<void> showNotifications(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (c) => const _NotificationLoader(),
    );

class _NotificationLoader extends ConsumerWidget {
  const _NotificationLoader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = NotificationLocalizations.of(context);
    return ref
        .watch(notificationViewModelProvider)
        .when(
          data: (m) => NotificationPanel(model: m),
          loading: () => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(l.text('loading')),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.text('unavailable')),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(notificationViewModelProvider),
                  child: Text(l.text('retry')),
                ),
              ],
            ),
          ),
        );
  }
}

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key, required this.model});
  final NotificationViewModel model;
  @override
  Widget build(BuildContext context) {
    final l = NotificationLocalizations.of(context), theme = Theme.of(context);
    final stacked =
        MediaQuery.sizeOf(context).width < 500 &&
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final close = IconButton(
      tooltip: l.text('close'),
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.close),
    );
    final heading = Text(
      l.text('title'),
      style: stacked
          ? theme.textTheme.headlineSmall
          : theme.textTheme.headlineMedium,
    );
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final s = model.snapshot;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stacked) ...[
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: close,
                  ),
                  heading,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      close,
                    ],
                  ),
                Text(l.text('intro')),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.text('enable')),
                  subtitle: Text(l.text('enabledHelp')),
                  value: s?.enabled ?? false,
                  onChanged:
                      model.busy ||
                          s == null ||
                          s.availability == ReminderAvailability.unsupported
                      ? null
                      : model.enable,
                ),
                const SizedBox(height: 16),
                if (model.busy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      semanticsLabel: l.text('loading'),
                    ),
                  ),
                if (s == null)
                  Text(l.text('loading'))
                else ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(l.status(s.availability)),
                  ),
                  if (s.availability == ReminderAvailability.ready) ...[
                    const SizedBox(height: 8),
                    Text(l.text(s.precise ? 'precise' : 'approximate')),
                    if (!s.precise)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: model.busy
                              ? null
                              : () => model.refresh(timing: true),
                          child: Text(l.text('timing')),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(l.text('upcoming'), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (s.queued.isEmpty) Text(l.text('empty')),
                    for (final r in s.queued)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                '${MaterialLocalizations.of(context).formatFullDate(r.fireAt.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(r.fireAt.toLocal()))}',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (s.enabled &&
                      s.availability == ReminderAvailability.denied)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: model.busy
                            ? null
                            : () => model.refresh(request: true),
                        child: Text(l.text('permission')),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Text(l.text('horizon'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: model.busy ? null : () => model.refresh(),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    l.text(
                      s?.availability == ReminderAvailability.unavailable
                          ? 'retry'
                          : 'refresh',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
