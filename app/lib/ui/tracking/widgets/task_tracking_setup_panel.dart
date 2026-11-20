import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/views/open_tracking.dart';
import 'package:app/ui/tracking/widgets/tracking_fields_form.dart';

class TaskTrackingSetupPanel extends ConsumerWidget {
  const TaskTrackingSetupPanel({super.key, required this.model});
  final TaskEditorViewModel model;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = TrackingStrings.of(context), s = model.state.draft.tracking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.typesFailure != null) ...[
          Text(l.error(model.typesFailure)),
          TextButton(
            onPressed: model.refreshTypes,
            child: Text(l.text('reload')),
          ),
        ],
        if (model.types.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('type-${s.type.id}-${model.types.length}'),
            initialValue: s.type.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.text('type'),
              prefixIcon: Icon(trackingIcon(s.type.icon)),
            ),
            items: [
              for (final t in model.types.where(
                (t) => !t.hidden || t.id == s.type.id,
              ))
                DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.group == null ? '' : '${l.group(t.group)} › '}${l.type(t)}',
                  ),
                ),
            ],
            onChanged: (id) async {
              if (id == s.type.id) return;
              if (!model.state.draft.isNew) {
                final approved = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(
                      l.tr('Change task type?', 'Alterar tipo de tarefa?'),
                    ),
                    content: Text(
                      l.tr(
                        'Future entries will use the new fields. Previous logs and setup values will remain in history.',
                        'Novos registros usarão os novos campos. Registros e valores anteriores permanecerão no histórico.',
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
                if (approved != true) return;
              }
              model.selectType(model.types.firstWhere((t) => t.id == id));
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await openTypeManager(context, ref);
              await model.refreshTypes();
            },
            icon: const Icon(Icons.tune),
            label: Text(l.text('types')),
          ),
        ),
        if (model.trackingForm case final form?)
          TrackingFieldsForm(
            key: ValueKey('${s.type.id}-${s.type.revision}'),
            model: form,
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('metric-${s.type.id}-${s.mainMetric}'),
          initialValue: s.mainMetric,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.text('mainMetric')),
          items: [
            DropdownMenuItem(value: null, child: Text(l.text('none'))),
            for (final f in s.type.fields.where(
              (f) =>
                  f.scope == FieldScope.log &&
                  (f.numeric ||
                      f.kind == FieldKind.episodes ||
                      f.kind == FieldKind.checklist),
            ))
              DropdownMenuItem(
                value: f.id,
                child: Text(l.field(f, builtin: s.type.builtin)),
              ),
          ],
          onChanged: model.selectMainMetric,
        ),
        if (s.mainMetric != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey('target-${s.type.id}'),
            initialValue: s.target?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.text('target'),
              errorText: model.state.fieldErrors.containsKey('trackingTarget')
                  ? l.error('invalid')
                  : null,
            ),
            onChanged: model.changeTrackingTarget,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(
                '${l.text('finishDate')}${s.finishDate == null ? '' : ': ${MaterialLocalizations.of(context).formatMediumDate(DateTime(s.finishDate!.year, s.finishDate!.month, s.finishDate!.day))}'}',
              ),
              onPressed: () async {
                final now = DateTime.now();
                final date = s.finishDate;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date == null
                      ? now
                      : DateTime(date.year, date.month, date.day),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(9999),
                );
                if (picked != null) {
                  model.change(
                    model.state.draft.copyWith(
                      tracking: model.state.draft.tracking.copyWith(
                        finishDate: LocalDate(
                          picked.year,
                          picked.month,
                          picked.day,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            if (s.finishDate != null)
              IconButton(
                tooltip: l.text('remove'),
                onPressed: () => model.change(
                  model.state.draft.copyWith(
                    tracking: s.copyWith(clearDate: true),
                  ),
                ),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }
}
