import 'package:flutter/foundation.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/ui/tracking/view_models/tracking_form_model.dart';

class FieldEditorModel extends ChangeNotifier {
  FieldEditorModel({required this.newId, this.original})
    : id = original?.id ?? newId(),
      label = original?.label ?? '',
      unit = original?.unit ?? '',
      choices = original?.choices.join('\n') ?? '',
      target = original?.target?.toString() ?? '',
      kind = original?.kind ?? FieldKind.text,
      scope = original?.scope ?? FieldScope.log,
      required = original?.required ?? false,
      summary = original?.summary ?? MetricSummary.total {
    _makeTemplate(original?.template ?? []);
  }
  final String Function() newId;
  final TrackingField? original;
  final String id;
  String label, unit, choices, target;
  FieldKind kind;
  FieldScope scope;
  bool required;
  MetricSummary summary;
  String? failure;
  late TrackingFormModel templateModel;
  bool get structured => [
    FieldKind.exercises,
    FieldKind.episodes,
    FieldKind.checklist,
  ].contains(kind);
  void _makeTemplate(List<Object?> template) {
    templateModel = TrackingFormModel(
      type: TaskType(
        id: 'template',
        name: 'Template',
        builtin: true,
        icon: 'task',
        fields: [
          TrackingField(
            id: 'template',
            label: 'Template',
            kind: structured ? kind : FieldKind.checklist,
            scope: FieldScope.setup,
          ),
        ],
      ),
      scope: FieldScope.setup,
      values: {'template': template},
    );
  }

  void change({
    String? label,
    String? unit,
    String? choices,
    String? target,
    FieldKind? kind,
    FieldScope? scope,
    bool? required,
    MetricSummary? summary,
  }) {
    this.label = label ?? this.label;
    this.unit = unit ?? this.unit;
    this.choices = choices ?? this.choices;
    this.target = target ?? this.target;
    if (kind != null && kind != this.kind) {
      templateModel.dispose();
      this.kind = kind;
      _makeTemplate([]);
    }
    this.scope = scope ?? this.scope;
    this.required = required ?? this.required;
    this.summary = summary ?? this.summary;
    failure = null;
    notifyListeners();
  }

  TrackingField? build() {
    try {
      if (structured && !templateModel.valid) throw ArgumentError();
      final replaced =
          original != null &&
          (original!.kind != kind ||
              original!.unit != unit ||
              original!.scope != scope);
      return TrackingField(
        id: replaced ? newId() : id,
        label: label,
        kind: kind,
        scope: scope,
        required: required,
        unit: unit,
        summary: summary,
        target: target.trim().isEmpty
            ? null
            : double.tryParse(target.replaceAll(',', '.')) ?? double.nan,
        choices: choices.split('\n'),
        template: structured
            ? (templateModel.values['template'] as List? ?? [])
            : [],
      );
    } on ArgumentError {
      failure = 'validation';
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    templateModel.dispose();
    super.dispose();
  }
}
