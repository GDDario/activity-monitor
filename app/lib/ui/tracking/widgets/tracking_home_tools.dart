import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/tracking_dependencies.dart';
import 'package:app/domain/models/task_tracking.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';
import 'package:app/ui/tracking/views/open_tracking.dart';

class TrackingHomeTools extends ConsumerStatefulWidget {
  const TrackingHomeTools({super.key});
  @override
  ConsumerState<TrackingHomeTools> createState() => _TrackingHomeToolsState();
}

class _TrackingHomeToolsState extends ConsumerState<TrackingHomeTools> {
  TrackingViewModel? model;
  bool unavailable = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final next = await ref.read(trackingFactoryProvider)();
      if (!mounted) {
        next.dispose();
        return;
      }
      model = next;
      await next.loadTypes();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    }
  }

  @override
  void dispose() {
    model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = TrackingStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unavailable || model?.failure != null)
          Text(
            l.tr(
              'Task types are temporarily unavailable.',
              'Tipos de tarefa temporariamente indisponíveis.',
            ),
          ),
        Wrap(
          spacing: 12,
          children: [
            TextButton.icon(
              onPressed: () async {
                await openTypeManager(context, ref);
                await model?.loadTypes();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.tune),
              label: Text(l.text('types')),
            ),
            TextButton.icon(
              onPressed: () => openFinishedTasks(context, ref),
              icon: const Icon(Icons.flag_outlined),
              label: Text(l.text('finished')),
            ),
          ],
        ),
        for (final type in model?.types.where((t) => t.notice) ?? <TaskType>[])
          Card(
            child: ListTile(
              title: Text(l.text('newTypes')),
              subtitle: Text(l.type(type)),
              trailing: IconButton(
                tooltip: l.text('dismiss'),
                onPressed: () async {
                  await model!.dismiss(type);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
      ],
    );
  }
}
