import 'package:flutter/material.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/people/people_localizations.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';

class PersonEditorSheet extends StatelessWidget {
  const PersonEditorSheet({super.key, required this.model});
  final PersonEditorViewModel model;
  static Future<void> show(BuildContext context, PersonEditorViewModel model) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => PersonEditorSheet(model: model),
      );
  Future<void> _close(BuildContext context) async {
    if (model.state.saving) return;
    final l = PeopleLocalizations.of(context);
    final discard =
        !model.state.dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.text('discard')),
                content: Text(l.text('discardBody')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.text('keep')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.text('discardAction')),
                  ),
                ],
              ),
            ) ==
            true;
    if (context.mounted && discard) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = PeopleLocalizations.of(context), s = model.state;
      return PopScope(
        canPop: !s.saving && !s.dirty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _close(context);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_alt_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.text(
                          s.draft.expectedRevision == null ? 'create' : 'edit',
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l.text('close'),
                      onPressed: s.saving ? null : () => _close(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('person-name'),
                  initialValue: s.draft.name,
                  enabled: !s.saving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xfff2f4f0),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ActivityColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ActivityColors.outline),
                    ),
                    labelText: l.text('name'),
                    errorText:
                        s.showErrors && s.draft.errors.containsKey('name')
                        ? l.text('invalid')
                        : null,
                  ),
                  onChanged: (v) => model.change(name: v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('person-role'),
                  initialValue: s.draft.role,
                  enabled: !s.saving,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xfff2f4f0),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ActivityColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ActivityColors.outline),
                    ),
                    labelText: l.text('role'),
                    errorText:
                        s.showErrors && s.draft.errors.containsKey('role')
                        ? l.text('invalid')
                        : null,
                  ),
                  onChanged: (v) => model.change(role: v),
                ),
                const SizedBox(height: 24),
                Text(
                  l.text('categories'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in PersonCategory.values)
                      FilterChip(
                        label: Text(l.text(c.name)),
                        selected: s.draft.categories.contains(c),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        backgroundColor: const Color(0xfff2f4f0),
                        selectedColor: ActivityColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: s.draft.categories.contains(c)
                              ? Colors.white
                              : ActivityColors.primary,
                        ),
                        onSelected: s.saving
                            ? null
                            : (selected) {
                                final categories = {...s.draft.categories};
                                selected
                                    ? categories.add(c)
                                    : categories.remove(c);
                                model.change(categories: categories);
                              },
                      ),
                  ],
                ),
                if (s.failure != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.text(
                      s.failure == PeopleFailure.staleRevision
                          ? 'stale'
                          : 'unavailable',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: s.saving
                      ? null
                      : () async {
                          if (await model.save() && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: s.saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(),
                        )
                      : Text(l.text('save')),
                ),
                TextButton(
                  onPressed: s.saving ? null : () => _close(context),
                  child: Text(l.text('cancel')),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
