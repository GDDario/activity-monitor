import 'package:flutter/material.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/view_models/field_editor_model.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';
import 'package:app/ui/tracking/widgets/tracking_fields_form.dart';
import 'package:app/ui/tracking/widgets/tracking_surface.dart';

class TypeManagerView extends StatelessWidget {
  const TypeManagerView({super.key, required this.model});
  final TrackingViewModel model;
  Future<void> edit(BuildContext context, TaskType? type) async {
    final editor = TypeEditorModel(newId: model.newId, original: type);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TypeEditor(model: editor, owner: model),
      );
    } finally {
      editor.dispose();
    }
    await model.loadTypes();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context);
      return TrackingSurface(
        title: l.text('types'),
        busy: model.busy,
        onClose: () => Navigator.pop(context),
        footer: FilledButton.icon(
          onPressed: model.busy ? null : () => edit(context, null),
          icon: const Icon(Icons.add),
          label: Text(l.text('newType')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.busy) const LinearProgressIndicator(),
            if (model.failure != null) ...[
              Text(l.error(model.failure)),
              TextButton(
                onPressed: model.loadTypes,
                child: Text(l.text('reload')),
              ),
            ],
            for (final type in model.types)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(trackingIcon(type.icon)),
                        title: Text(l.type(type)),
                        subtitle: type.group == null
                            ? null
                            : Text(l.group(type.group)),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!type.builtin)
                            TextButton.icon(
                              onPressed: () => edit(context, type),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(l.text('edit')),
                            ),
                          if (type.id != generalTaskType().id)
                            TextButton.icon(
                              onPressed: () => model.visibility(type),
                              icon: Icon(
                                type.hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              label: Text(
                                l.text(type.hidden ? 'restore' : 'hide'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _TypeEditor extends StatelessWidget {
  const _TypeEditor({required this.model, required this.owner});
  final TypeEditorModel model;
  final TrackingViewModel owner;
  Future<void> close(BuildContext context) async {
    if (await confirmTrackingDiscard(context, model.dirty) && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> field(BuildContext context, int? index) async {
    final editor = FieldEditorModel(
      newId: model.newId,
      original: index == null ? null : model.fields[index],
    );
    TrackingField? result;
    try {
      result = await showDialog<TrackingField>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _FieldEditor(model: editor),
      );
    } finally {
      editor.dispose();
    }
    if (result != null) model.setField(result, index);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context);
      return TrackingSurface(
        title: l.text(model.original == null ? 'newType' : 'editType'),
        busy: model.busy,
        dirty: model.dirty,
        onClose: () => close(context),
        footer: FilledButton(
          onPressed: model.busy
              ? null
              : () async {
                  if (await model.save(owner.saveType) && context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: Text(l.text('save')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: model.name,
              decoration: InputDecoration(labelText: l.text('name')),
              onChanged: (v) => model.change(name: v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: model.group,
              decoration: InputDecoration(labelText: l.text('group')),
              onChanged: (v) => model.change(group: v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: model.icon,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.text('icon')),
              items: [
                for (final icon in trackingIcons)
                  DropdownMenuItem(
                    value: icon,
                    child: Icon(
                      trackingIcon(icon),
                      semanticLabel: l.text(icon),
                    ),
                  ),
              ],
              onChanged: (v) => model.change(icon: v),
            ),
            const SizedBox(height: 24),
            Text(
              l.text('fields'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final (i, f) in model.fields.indexed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(f.label),
                      Text('${l.text(f.scope.name)} · ${l.text(f.kind.name)}'),
                      Wrap(
                        children: [
                          IconButton(
                            tooltip: l.text('edit'),
                            onPressed: () => field(context, i),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: l.text('moveUp'),
                            onPressed: i == 0
                                ? null
                                : () => model.move(i, i - 1),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: l.text('moveDown'),
                            onPressed: i == model.fields.length - 1
                                ? null
                                : () => model.move(i, i + 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            tooltip: l.text('remove'),
                            onPressed: () => model.remove(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => field(context, null),
              icon: const Icon(Icons.add),
              label: Text(l.text('addField')),
            ),
            if (model.failure != null)
              Text(
                l.error(model.failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({required this.model});
  final FieldEditorModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context);
      return TrackingSurface(
        title: l.text('fields'),
        dirty: true,
        onClose: () async {
          if (await confirmTrackingDiscard(context, true) && context.mounted) {
            Navigator.pop(context);
          }
        },
        footer: FilledButton(
          onPressed: () {
            final f = model.build();
            if (f != null) Navigator.pop(context, f);
          },
          child: Text(l.text('save')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: model.label,
              decoration: InputDecoration(labelText: l.text('label')),
              onChanged: (v) => model.change(label: v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FieldKind>(
              initialValue: model.kind,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.text('kind')),
              items: [
                for (final kind in FieldKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(
                      kind == FieldKind.date
                          ? l.tr('Date', 'Data')
                          : l.text(kind.name),
                    ),
                  ),
              ],
              onChanged: (v) => model.change(kind: v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FieldScope>(
              initialValue: model.scope,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.text('scope')),
              items: [
                for (final scope in FieldScope.values)
                  DropdownMenuItem(
                    value: scope,
                    child: Text(l.text(scope.name)),
                  ),
              ],
              onChanged: (v) => model.change(scope: v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.text('required')),
              value: model.required,
              onChanged: (v) => model.change(required: v),
            ),
            if (model.kind == FieldKind.choice)
              TextFormField(
                initialValue: model.choices,
                maxLines: 5,
                decoration: InputDecoration(labelText: l.text('choices')),
                onChanged: (v) => model.change(choices: v),
              ),
            if (model.kind == FieldKind.number ||
                model.kind == FieldKind.duration) ...[
              TextFormField(
                initialValue: model.unit,
                decoration: InputDecoration(labelText: l.text('unit')),
                onChanged: (v) => model.change(unit: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MetricSummary>(
                initialValue: model.summary,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.text('summary')),
                items: [
                  for (final s in MetricSummary.values)
                    DropdownMenuItem(value: s, child: Text(l.text(s.name))),
                ],
                onChanged: (v) => model.change(summary: v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: model.target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l.text('target')),
                onChanged: (v) => model.change(target: v),
              ),
            ],
            if (model.structured) ...[
              const SizedBox(height: 16),
              Text(
                l.tr(
                  'Starting entries for new sessions',
                  'Itens iniciais para novas atividades',
                ),
              ),
              TrackingFieldsForm(
                key: ValueKey(model.kind),
                model: model.templateModel,
              ),
            ],
            if (model.failure != null)
              Text(
                l.error(model.failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
