import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/profile/profile_localizations.dart';
import 'package:app/ui/profile/widgets/profile_avatar.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';
import 'package:app/ui/profile/views/profile_editor_form.dart';

enum _ProfileEditResult { saved, reload }

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});
  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  Future<ProfileEditorViewModel>? _setupFuture;
  ProfileEditorViewModel? _setupModel;
  @override
  void dispose() {
    _setupModel?.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    ProfileEditorViewModel? model;
    try {
      model = await ref.read(profileEditorFactoryProvider)();
      if (!mounted) {
        model.dispose();
        return;
      }
      final reload = await showModalBottomSheet<_ProfileEditResult>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (context) => _ProfileEditSheet(model: model!),
      );
      if (reload == _ProfileEditResult.saved && mounted) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProfileLocalizations.of(context).text('saved')),
          ),
        );
      }
      if (reload == _ProfileEditResult.reload && mounted) {
        final session = ref.read(profileSessionProvider);
        await session.load(force: true);
        if (mounted && session.state.failure == null) {
          await _edit();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProfileLocalizations.of(context).text('unavailable')),
          ),
        );
      }
    } finally {
      model?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(profileSessionProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.state,
            l = ProfileLocalizations.of(context),
            profile = s.profile;
        if (s.status == ProfileStatus.loading && profile == null) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }
        if (s.status == ProfileStatus.unavailable) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.text('unavailable')),
                      TextButton(
                        onPressed: () => session.load(force: true),
                        child: Text(l.text('retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (profile == null) {
          _setupFuture ??= ref.read(profileEditorFactoryProvider)().then((
            model,
          ) {
            if (mounted) {
              _setupModel = model;
            } else {
              model.dispose();
            }
            return model;
          });
          return PopScope(
            canPop: false,
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: FutureBuilder(
                      future: _setupFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return TextButton(
                            onPressed: () {
                              setState(() => _setupFuture = null);
                            },
                            child: Text(l.text('retry')),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ProfileEditorForm(
                          model: snapshot.data!,
                          setup: true,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return ApplicationShell(
          destination: AppDestination.profile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
            children: [
              if (s.failure != null) ...[
                Text(l.text('unavailable')),
                TextButton(
                  onPressed: () => session.load(force: true),
                  child: Text(l.text('retry')),
                ),
              ],
              ScreenTitleBar(
                title: l.text('profile'),
                phrase: l.text('phrase'),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ProfileImage(
                        name: profile.name.value,
                        image: profile.avatar,
                        radius: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.name.value,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.text('appearance'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l.appearance(profile.appearance)),
                      const Divider(),
                      Text(
                        l.text('language'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l.language(profile.language)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.text('edit')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileEditSheet extends StatelessWidget {
  const _ProfileEditSheet({required this.model});
  final ProfileEditorViewModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      Future<void> close() async {
        if (model.state.saving) return;
        if (!model.state.dirty || await confirmProfileDiscard(context)) {
          if (context.mounted) Navigator.pop(context);
        }
      }

      return PopScope(
        canPop: !model.state.dirty && !model.state.saving,
        onPopInvokedWithResult: (popped, result) {
          if (!popped) close();
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
          ),
          child: ProfileEditorForm(
            model: model,
            onCancel: close,
            onSaved: () {
              if (context.mounted) {
                Navigator.pop(context, _ProfileEditResult.saved);
              }
            },
            onReload: () async {
              if (await confirmProfileDiscard(context) && context.mounted) {
                Navigator.pop(context, _ProfileEditResult.reload);
              }
            },
          ),
        ),
      );
    },
  );
}
