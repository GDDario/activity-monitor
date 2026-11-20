import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/use_cases/tracking_metrics.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/view_models/log_editor_model.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';
import 'package:app/ui/tracking/views/activity_log_view.dart';
import 'package:app/ui/tracking/widgets/metric_chart.dart';
import 'package:app/ui/tracking/widgets/tracking_surface.dart';

class TaskTrackingView extends StatefulWidget {
  const TaskTrackingView({
    super.key,
    required this.model,
    this.onEdit,
    this.completionAction,
  });
  final TrackingViewModel model;
  final VoidCallback? onEdit;
  final Widget? completionAction;
  @override
  State<TaskTrackingView> createState() => _TaskTrackingViewState();
}

class _TaskTrackingViewState extends State<TaskTrackingView> {
  final Map<String, MetricSummary> summaries = {};
  late final Timer ticker;
  TrackingViewModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          model.detail?.timer?.stoppedSeconds == null &&
          model.detail?.timer != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    ticker.cancel();
    super.dispose();
  }

  Future<void> record([ActivityLog? log]) async {
    final editor = LogEditorModel(model, original: log);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ActivityLogView(model: editor),
      );
    } finally {
      editor.dispose();
    }
    if (mounted) await model.load(model.detail!.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context), d = model.detail;
      final progress = model.progress;
      final timer = d?.timer;
      return TrackingSurface(
        title: d?.title ?? l.text('details'),
        busy: model.busy,
        onClose: () => Navigator.pop(context),
        footer: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (widget.onEdit != null)
              TextButton.icon(
                onPressed: model.busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onEdit!();
                      },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.text('edit')),
              ),
            if (widget.completionAction != null) widget.completionAction!,
            if (d != null)
              FilledButton.icon(
                onPressed: model.busy ? null : () => record(),
                icon: const Icon(Icons.add),
                label: Text(l.text('record')),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.busy) const LinearProgressIndicator(),
            if (model.failure != null) ...[
              Text(l.error(model.failure)),
              TextButton(
                onPressed: d == null ? null : () => model.load(d.id),
                child: Text(l.text('reload')),
              ),
            ],
            if (d != null) ...[
              Row(
                children: [
                  Icon(
                    trackingIcon(d.setup.type.icon),
                    color: ActivityPalette.of(context).primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.type(d.setup.type),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (progress != null)
                _section(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.text('metrics'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${l.number(progress.done)} / ${l.number(progress.total)}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.fraction,
                        semanticsLabel: l.text('metrics'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.tr(
                          '${l.number(progress.remaining)} remaining',
                          '${l.number(progress.remaining)} restantes',
                        ),
                      ),
                      if (progress.pace != null)
                        Text(
                          l.tr(
                            'About ${l.number(progress.pace!)} per day',
                            'Cerca de ${l.number(progress.pace!)} por dia',
                          ),
                        ),
                      if (progress.overdue)
                        Text(
                          l.tr(
                            'Your target date has passed. Adjust it whenever you need.',
                            'Sua data desejada passou. Ajuste quando precisar.',
                          ),
                        ),
                    ],
                  ),
                ),
              if (d.setup.finishDate != null)
                Text(
                  '${l.text('finishDate')}: ${MaterialLocalizations.of(context).formatMediumDate(DateTime(d.setup.finishDate!.year, d.setup.finishDate!.month, d.setup.finishDate!.day))}',
                ),
              for (final f in d.setup.type.fields.where(
                (f) =>
                    f.scope == FieldScope.setup &&
                    d.setup.values.containsKey(f.id),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${l.field(f, builtin: d.setup.type.builtin)}: ${_value(l, d.setup.values[f.id], builtin: d.setup.type.builtin && f.kind == FieldKind.choice)}',
                  ),
                ),
              if (d.setup.history.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    l.tr('Previous setup values', 'Configurações anteriores'),
                  ),
                  children: [
                    for (final h in d.setup.history)
                      ListTile(
                        title: Text(l.type(h.type)),
                        subtitle: Text(
                          [
                            for (final f in h.type.fields.where(
                              (f) => h.values.containsKey(f.id),
                            ))
                              '${l.field(f, builtin: h.type.builtin)}: ${_value(l, h.values[f.id], builtin: h.type.builtin && f.kind == FieldKind.choice)}',
                          ].join('\n'),
                        ),
                      ),
                  ],
                ),
              if (timer != null)
                _section(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.text('timer'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${l.number(model.timerSeconds())} ${l.text('seconds')}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (timer.taskId != d.id)
                        Text(
                          l.tr(
                            'A timer belongs to another task. Stop or discard it before starting a new one.',
                            'O cronômetro pertence a outra tarefa. Pare ou descarte antes de iniciar outro.',
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (timer.stoppedSeconds == null)
                            TextButton.icon(
                              onPressed: model.stopTimer,
                              icon: const Icon(Icons.stop),
                              label: Text(l.text('stop')),
                            ),
                          TextButton(
                            onPressed: model.discardTimer,
                            child: Text(l.text('discardTimer')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (timer == null)
                Wrap(
                  spacing: 12,
                  children: [
                    for (final f in d.setup.type.fields.where(
                      (f) =>
                          f.scope == FieldScope.log &&
                          f.kind == FieldKind.duration,
                    ))
                      TextButton.icon(
                        onPressed: () => model.startTimer(f.id),
                        icon: const Icon(Icons.play_arrow_outlined),
                        label: Text(
                          '${l.text('start')} · ${l.field(f, builtin: d.setup.type.builtin)}',
                        ),
                      ),
                  ],
                ),
              for (final m in model.metrics)
                _section(context, _metric(context, l, m)),
              const SizedBox(height: 20),
              Text(
                l.text('history'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (d.logs.isEmpty) Text(l.text('empty')),
              for (final log in d.logs.reversed)
                _section(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${MaterialLocalizations.of(context).formatMediumDate(log.recordedAt.toLocal())} · ${TimeOfDay.fromDateTime(log.recordedAt.toLocal()).format(context)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l.type(log.type)),
                      for (final f in log.type.fields.where(
                        (f) => log.values.containsKey(f.id),
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${l.field(f, builtin: log.type.builtin)}: ${_value(l, log.values[f.id], builtin: log.type.builtin && f.kind == FieldKind.choice)}',
                          ),
                        ),
                      Wrap(
                        children: [
                          IconButton(
                            tooltip: l.text('edit'),
                            onPressed: () => record(log),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: l.text('delete'),
                            onPressed: () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(
                                    l.tr(
                                      'Delete this activity?',
                                      'Excluir esta atividade?',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(l.text('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(l.text('delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true) await model.deleteLog(log);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(
                        l.text(d.setup.finished ? 'reopen' : 'finish'),
                      ),
                      content: Text(
                        l.tr(
                          'Your activity history will be preserved. This changes future occurrences.',
                          'Seu histórico será preservado. Esta ação altera ocorrências futuras.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(l.text('cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(l.text('save')),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await model.lifecycle();
                    if (context.mounted && model.failure == null) {
                      Navigator.pop(context);
                    }
                  }
                },
                icon: Icon(
                  d.setup.finished ? Icons.replay : Icons.flag_outlined,
                ),
                label: Text(l.text(d.setup.finished ? 'reopen' : 'finish')),
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _metric(BuildContext context, TrackingStrings l, TrackingMetric m) {
    final mode = summaries[m.id] ?? m.summary;
    final value = model.summaryFor(m, mode);
    final label = m.label.endsWith(' · repetitions')
        ? '${m.label.substring(0, m.label.length - ' · repetitions'.length)} · ${l.text('reps')}'
        : m.label.endsWith(' · weight')
        ? '${m.label.substring(0, m.label.length - ' · weight'.length)} · ${l.text('weight')}'
        : m.builtin
        ? l.text(m.label)
        : m.label;
    final unit = m.builtin ? l.text(m.unit) : m.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<MetricSummary>(
          initialValue: mode,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.text('summary')),
          items: [
            for (final s in MetricSummary.values)
              DropdownMenuItem(value: s, child: Text(l.text(s.name))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => summaries[m.id] = v);
          },
        ),
        const SizedBox(height: 12),
        Text(
          value == null ? '—' : '${l.number(value)} $unit',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (m.target != null)
          Text('${l.text('target')}: ${l.number(m.target!)} $unit'),
        if (m.points.isNotEmpty) ...[
          MetricChart(points: m.points, description: label),
          ExpansionTile(
            title: Text(l.tr('Chart values', 'Valores do gráfico')),
            children: [
              for (final p in m.points)
                ListTile(
                  dense: true,
                  title: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(p.at.toLocal()),
                  ),
                  trailing: Text(l.number(p.value)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _section(BuildContext context, Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Material(
    color: ActivityPalette.of(context).surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: ActivityPalette.of(context).border),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);
String _value(TrackingStrings l, Object? value, {bool builtin = false}) {
  if (value is bool) return value ? l.tr('Yes', 'Sim') : l.tr('No', 'Não');
  if (value is num) return l.number(value);
  if (value is List) {
    return value
        .map((v) {
          final m = v as Map;
          if (m.containsKey('exercise')) {
            return '${m['exercise']} · ${m['reps']} ${l.text('reps')}${m['weight'] == null ? '' : ' · ${m['weight']} ${m['unit'] ?? 'kg'}'}';
          }
          if (m.containsKey('episode')) {
            return '${l.text('season')} ${m['season'] ?? 1}, ${l.text('episode')} ${m['episode']}';
          }
          return '${m['done'] == true ? '✓' : '○'} ${m['title']}';
        })
        .join('\n');
  }
  return builtin ? l.text(value?.toString() ?? '') : value?.toString() ?? '';
}
