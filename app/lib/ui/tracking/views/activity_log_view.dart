import 'package:flutter/material.dart';

import 'package:app/ui/tracking/tracking_strings.dart';
import 'package:app/ui/tracking/view_models/log_editor_model.dart';
import 'package:app/ui/tracking/widgets/tracking_fields_form.dart';
import 'package:app/ui/tracking/widgets/tracking_surface.dart';

class ActivityLogView extends StatelessWidget {
  const ActivityLogView({super.key, required this.model});
  final LogEditorModel model;
  Future<void> close(BuildContext context) async {
    if (await confirmTrackingDiscard(context, model.dirty) && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TrackingStrings.of(context), at = model.recordedAt;
      final localizations = MaterialLocalizations.of(context);
      return TrackingSurface(
        title: l.text(model.original == null ? 'record' : 'edit'),
        busy: model.busy,
        dirty: model.dirty,
        onClose: () => close(context),
        footer: FilledButton(
          onPressed: model.busy
              ? null
              : () async {
                  if (await model.save() && context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: model.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.text('save')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.text('date'), style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(localizations.formatMediumDate(at)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: at,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      model.changeDate(
                        DateTime(
                          d.year,
                          d.month,
                          d.day,
                          at.hour,
                          at.minute,
                          at.second,
                        ),
                      );
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at)),
                  ),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(at),
                    );
                    if (time != null) {
                      model.changeDate(
                        DateTime(
                          at.year,
                          at.month,
                          at.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            if (model.showErrors && model.errors.containsKey('recordedAt'))
              Text(
                l.error('invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            TrackingFieldsForm(model: model),
          ],
        ),
      );
    },
  );
}
