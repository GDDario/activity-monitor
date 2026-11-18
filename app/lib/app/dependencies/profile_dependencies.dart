import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/database_dependencies.dart';
import 'package:app/data/repositories/profile_repository.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/data/services/profile_database.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final path = await ref.watch(databaseInitializationProvider.future);
  final repo = LocalProfileRepository(ProfileDatabase(path: path));
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
});
final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => LocalAvatarRepository(),
);
final profileSessionProvider = Provider<ProfileSessionViewModel>((ref) {
  final model = ProfileSessionViewModel(
    load: () async => (await ref.read(profileRepositoryProvider.future)).load(),
  );
  ref.onDispose(model.dispose);
  return model;
});
final profileChangesProvider = StreamProvider<LocalProfile>((ref) async* {
  final repo = await ref.watch(profileRepositoryProvider.future);
  yield* repo.changes;
});
final profileEditorFactoryProvider =
    Provider<Future<ProfileEditorViewModel> Function()>(
      (ref) => () async {
        final repo = await ref.read(profileRepositoryProvider.future);
        final session = ref.read(profileSessionProvider);
        final profile = session.state.profile;
        if (session.state.status != ProfileStatus.ready &&
            session.state.status != ProfileStatus.setupRequired) {
          throw StateError('Profile unavailable');
        }
        return ProfileEditorViewModel(
          repository: repo,
          avatars: ref.read(avatarRepositoryProvider),
          draft: profile == null
              ? ProfileDraft(id: ref.read(uuidProvider).v7(), name: '')
              : ProfileDraft.fromProfile(profile),
          onSaved: session.accept,
        );
      },
    );
