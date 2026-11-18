import 'package:flutter/material.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/profile/profile_localizations.dart';
import 'package:app/ui/profile/widgets/profile_avatar.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

Future<bool> confirmProfileDiscard(BuildContext context) async {
  final l = ProfileLocalizations.of(context);
  return await showDialog<bool>(
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
}

class ProfileEditorForm extends StatefulWidget {
  const ProfileEditorForm({
    super.key,
    required this.model,
    this.setup = false,
    this.onCancel,
    this.onSaved,
    this.onReload,
  });
  final ProfileEditorViewModel model;
  final bool setup;
  final VoidCallback? onCancel, onSaved, onReload;
  @override
  State<ProfileEditorForm> createState() => _ProfileEditorFormState();
}

class _ProfileEditorFormState extends State<ProfileEditorForm> {
  final _nameFocus = FocusNode();
  ProfileEditorViewModel get model => widget.model;
  bool get setup => widget.setup;
  VoidCallback? get onCancel => widget.onCancel;
  VoidCallback? get onReload => widget.onReload;
  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await model.save();
    if (!mounted) return;
    if (saved) {
      widget.onSaved?.call();
    } else if (model.state.draft.errors.containsKey('name')) {
      _nameFocus.requestFocus();
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _nameFocus.context != null) {
        await Scrollable.ensureVisible(
          _nameFocus.context!,
          alignment: .2,
          duration: const Duration(milliseconds: 150),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final s = model.state,
          d = s.draft,
          l = ProfileLocalizations.of(context),
          enabled = model.canEdit && !s.picking;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.text(setup ? 'setup' : 'edit'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (setup) ...[
              const SizedBox(height: 12),
              Text(l.text('setupBody')),
            ],
            const SizedBox(height: 24),
            Center(
              child: Semantics(
                label: l.text('avatar'),
                image: true,
                child: ProfileImage(name: d.name, image: d.avatar, radius: 40),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: enabled ? model.chooseAvatar : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.text('choosePhoto')),
                ),
                if (d.avatar != null)
                  TextButton(
                    onPressed: model.canEdit ? model.removeAvatar : null,
                    child: Text(l.text('removePhoto')),
                  ),
              ],
            ),
            Text(
              l.text('photoHint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (s.picking) const LinearProgressIndicator(),
            if (s.avatarFailure != null)
              Text(
                l.avatarFailure(s.avatarFailure!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey('profile-name'),
              focusNode: _nameFocus,
              initialValue: d.name,
              enabled: enabled,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.text('name'),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorMaxLines: 3,
                errorText: s.showErrors && d.errors.containsKey('name')
                    ? l.text('nameError')
                    : null,
              ),
              onChanged: (v) => model.change(name: v),
            ),
            const SizedBox(height: 24),
            Text(
              l.text('appearance'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<ProfileAppearance>(
              groupValue: d.appearance,
              onChanged: (v) {
                if (enabled && v != null) model.change(appearance: v);
              },
              child: Column(
                children: [
                  for (final a in ProfileAppearance.values)
                    RadioListTile<ProfileAppearance>(
                      value: a,
                      enabled: enabled,
                      title: Text(l.appearance(a)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.text('language'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<ProfileLanguage>(
              groupValue: d.language,
              onChanged: (v) {
                if (enabled && v != null) model.change(language: v);
              },
              child: Column(
                children: [
                  for (final language in ProfileLanguage.values)
                    RadioListTile<ProfileLanguage>(
                      value: language,
                      enabled: enabled,
                      title: Text(l.language(language)),
                    ),
                ],
              ),
            ),
            if (s.failure != null) ...[
              Text(
                l.text(
                  s.failure == ProfileFailure.staleRevision
                      ? 'stale'
                      : 'savingError',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (s.failure == ProfileFailure.staleRevision && onReload != null)
                TextButton(onPressed: onReload, child: Text(l.text('reload'))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: enabled ? _save : null,
              child: s.saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    )
                  : Text(l.text(setup ? 'continue' : 'save')),
            ),
            if (!setup)
              TextButton(
                onPressed: s.saving ? null : onCancel,
                child: Text(l.text('cancel')),
              ),
          ],
        ),
      );
    },
  );
}
