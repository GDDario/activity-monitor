import 'dart:async';

import 'package:app/data/repositories/profile_repository.dart';
import 'package:app/domain/models/local_profile.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});
  LocalProfile? profile;
  ProfileFailure? failure;
  int saves = 0;
  final events = StreamController<LocalProfile>.broadcast();
  @override
  Stream<LocalProfile> get changes => events.stream;
  @override
  Future<ProfileResult<LocalProfile?>> load() async => failure == null
      ? ProfileResult.success(profile)
      : ProfileResult.error(failure);
  @override
  Future<ProfileResult<LocalProfile>> save(ProfileDraft d) async {
    saves++;
    if (failure != null) return ProfileResult.error(failure);
    if (d.expectedRevision != profile?.revision) {
      return const ProfileResult.error(ProfileFailure.staleRevision);
    }
    profile = LocalProfile(
      id: d.id,
      name: ProfileName(d.name),
      appearance: d.appearance,
      language: d.language,
      avatar: d.avatar,
      revision: (profile?.revision ?? -1) + 1,
    );
    events.add(profile!);
    return ProfileResult.success(profile!);
  }

  @override
  Future<void> dispose() => events.close();
}

LocalProfile exampleProfile() => LocalProfile(
  id: 'profile',
  name: ProfileName('Robin Ward'),
  appearance: ProfileAppearance.light,
  language: ProfileLanguage.enUs,
);
