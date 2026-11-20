import 'package:flutter/material.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/view_models/tracking_form_model.dart';

class TrackingFieldsForm extends StatefulWidget {
  const TrackingFieldsForm({super.key, required this.model, this.onChanged});
  final TrackingFormModel model;
  final ValueChanged<Map<String, Object?>>? onChanged;
  @override
  State<TrackingFieldsForm> createState() => _TrackingFieldsFormState();
}

class _TrackingFieldsFormState extends State<TrackingFieldsForm> {
  final Map<String, FocusNode> nodes = {};
  String? focusedError;
  TrackingFormModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    model.addListener(_focusError);
  }

  @override
  void didUpdateWidget(TrackingFieldsForm old) {
    super.didUpdateWidget(old);
    if (old.model != model) {
      old.model.removeListener(_focusError);
      model.addListener(_focusError);
      focusedError = null;
    }
  }

  void _focusError() {
    if (!model.showErrors) return;
    final id = model.errors.keys.firstOrNull;
    if (id == focusedError) return;
    focusedError = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || id == null) return;
      final node = nodes[id];
      node?.requestFocus();
      if (node?.context case final target?) {
        Scrollable.ensureVisible(
          target,
          duration: Duration.zero,
          alignment: .2,
        );
      }
    });
  }

  @override
  void dispose() {
    model.removeListener(_focusError);
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context);
      return AbsorbPointer(
        absorbing: model.busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final field in model.type.fields.where(
              (f) => f.scope == model.scope,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FieldInput(
                  key: ValueKey('${field.id}:${model.type.revision}'),
                  field: field,
                  focusNode: nodes.putIfAbsent(
                    field.id,
                    () => FocusNode(debugLabel: field.id),
                  ),
                  value: model.values[field.id],
                  builtin: model.type.builtin,
                  error: model.showErrors || model.dirty
                      ? model.errors[field.id]
                      : null,
                  onChanged: (v) {
                    model.set(field.id, v);
                    widget.onChanged?.call(model.values);
                  },
                ),
              ),
            if (model.failure != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  l.error(model.failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.builtin,
    required this.focusNode,
    this.error,
  });
  final FocusNode focusNode;
  final TrackingField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool builtin;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final l = TrackingStrings.of(context), f = field;
    final label = '${l.field(f, builtin: builtin)}${f.required ? ' *' : ''}';
    final decoration = InputDecoration(
      labelText: label,
      suffixText: f.unit.isEmpty
          ? null
          : builtin
          ? l.text(f.unit)
          : f.unit,
      errorText: error == null ? null : l.error(error),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
    switch (f.kind) {
      case FieldKind.checkbox:
        return CheckboxListTile(
          focusNode: focusNode,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true,
          onChanged: onChanged,
          subtitle: error == null ? null : Text(l.error(error)),
        );
      case FieldKind.choice:
        return DropdownButtonFormField<String>(
          focusNode: focusNode,
          initialValue: value as String?,
          isExpanded: true,
          decoration: decoration,
          items: [
            DropdownMenuItem(value: null, child: Text(l.text('none'))),
            for (final choice in f.choices)
              DropdownMenuItem(
                value: choice,
                child: Text(builtin ? l.text(choice) : choice),
              ),
          ],
          onChanged: onChanged,
        );
      case FieldKind.date:
        final selected = DateTime.tryParse(value as String? ?? '');
        Future<void> pick() async {
          final date = await showDatePicker(
            context: context,
            initialDate: selected ?? DateTime.now(),
            firstDate: DateTime(1),
            lastDate: DateTime(9999),
          );
          if (date != null) {
            onChanged(LocalDate(date.year, date.month, date.day).toString());
          }
        }
        return TextFormField(
          key: ValueKey(value),
          focusNode: focusNode,
          readOnly: true,
          initialValue: selected == null
              ? ''
              : MaterialLocalizations.of(context).formatMediumDate(selected),
          onTap: pick,
          decoration: decoration.copyWith(
            suffixIcon: Wrap(
              children: [
                if (value != null)
                  IconButton(
                    tooltip: l.text('remove'),
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close),
                  ),
                IconButton(
                  tooltip: l.tr('Choose date', 'Escolher data'),
                  onPressed: pick,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
          ),
        );
      case FieldKind.text:
        return TextFormField(
          focusNode: focusNode,
          initialValue: value as String? ?? '',
          decoration: decoration,
          minLines: 1,
          maxLines: 4,
          onChanged: onChanged,
        );
      case FieldKind.number:
      case FieldKind.duration:
        return TextFormField(
          focusNode: focusNode,
          initialValue: value is num && (value as num).isFinite
              ? value.toString()
              : '',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: decoration,
          onChanged: (v) => onChanged(
            v.trim().isEmpty
                ? null
                : double.tryParse(v.replaceAll(',', '.')) ?? double.nan,
          ),
        );
      case FieldKind.exercises:
      case FieldKind.episodes:
      case FieldKind.checklist:
        final rows = (value as List? ?? [])
            .map((v) => Map<String, Object?>.from(v as Map))
            .toList();
        void change(int index, String key, Object? v) {
          final next = [...rows];
          next[index] = {...next[index], key: v};
          onChanged(next);
        }
        return Focus(
          focusNode: focusNode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              if (error != null)
                Text(
                  l.error(error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (final (i, row) in rows.indexed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (f.kind == FieldKind.exercises) ...[
                          TextFormField(
                            key: ValueKey('$i-exercise-${rows.length}'),
                            initialValue: row['exercise'] as String? ?? '',
                            decoration: InputDecoration(
                              labelText: l.text('exercise'),
                            ),
                            onChanged: (v) => change(i, 'exercise', v),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  key: ValueKey('$i-reps-${rows.length}'),
                                  initialValue: '${row['reps'] ?? ''}',
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l.text('reps'),
                                  ),
                                  onChanged: (v) => change(
                                    i,
                                    'reps',
                                    num.tryParse(v) ?? double.nan,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  key: ValueKey('$i-weight-${rows.length}'),
                                  initialValue: '${row['weight'] ?? ''}',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: l.text('weight'),
                                  ),
                                  onChanged: (v) => change(
                                    i,
                                    'weight',
                                    v.isEmpty
                                        ? null
                                        : num.tryParse(
                                                v.replaceAll(',', '.'),
                                              ) ??
                                              double.nan,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  key: ValueKey('$i-unit-${rows.length}'),
                                  initialValue: row['unit'] as String? ?? 'kg',
                                  decoration: InputDecoration(
                                    labelText: l.text('unit'),
                                  ),
                                  onChanged: (v) => change(i, 'unit', v),
                                ),
                              ),
                            ],
                          ),
                        ] else if (f.kind == FieldKind.episodes) ...[
                          if (f.id != 'units')
                            TextFormField(
                              key: ValueKey('$i-season-${rows.length}'),
                              initialValue: '${row['season'] ?? 1}',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.text('season'),
                              ),
                              onChanged: (v) => change(
                                i,
                                'season',
                                num.tryParse(v) ?? double.nan,
                              ),
                            ),
                          TextFormField(
                            key: ValueKey('$i-episode-${rows.length}'),
                            initialValue: '${row['episode'] ?? ''}',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l.text('episode'),
                            ),
                            onChanged: (v) => change(
                              i,
                              'episode',
                              num.tryParse(v) ?? double.nan,
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            key: ValueKey('$i-title-${rows.length}'),
                            initialValue: row['title'] as String? ?? '',
                            decoration: InputDecoration(
                              labelText: l.text('item'),
                            ),
                            onChanged: (v) => change(i, 'title', v),
                          ),
                          Checkbox(
                            value: row['done'] == true,
                            semanticLabel: l.text('Completed items'),
                            onChanged: (v) => change(i, 'done', v),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: l.text('remove'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onChanged([...rows]..removeAt(i)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => onChanged([
                  ...rows,
                  switch (f.kind) {
                    FieldKind.exercises => {
                      'exercise': '',
                      'reps': 1,
                      'unit': 'kg',
                    },
                    FieldKind.episodes => {'season': 1, 'episode': 1},
                    _ => {'title': '', 'done': false},
                  },
                ]),
                icon: const Icon(Icons.add),
                label: Text(l.text('add')),
              ),
            ],
          ),
        );
    }
  }
}
