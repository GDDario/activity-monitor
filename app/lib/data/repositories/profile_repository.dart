import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:app/data/services/profile_database.dart';
import 'package:app/domain/models/local_profile.dart';

abstract class ProfileRepository {
  Stream<LocalProfile> get changes;
  Future<ProfileResult<LocalProfile?>> load();
  Future<ProfileResult<LocalProfile>> save(ProfileDraft draft);
  Future<void> dispose();
}

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this.database);
  final ProfileDatabase database;
  final _changes = StreamController<LocalProfile>.broadcast();
  @override
  Stream<LocalProfile> get changes => _changes.stream;
  LocalProfile _map(Map<String, Object?> r) => LocalProfile(
    id: r['id'] as String,
    name: ProfileName(r['display_name'] as String),
    appearance: ProfileAppearance.values.byName(r['appearance'] as String),
    language: ProfileLanguage.values.byName(r['language'] as String),
    avatar: r['avatar_png'] as Uint8List?,
    revision: r['revision'] as int,
  );
  Future<ProfileResult<T>> _run<T>(
    Map<String, Object?> r,
    T Function(Map<String, Object?>) map,
  ) async {
    try {
      final result = await database.request(r);
      if (result['failure'] != null) {
        final failure = ProfileFailure.values.byName(
          result['failure'] as String,
        );
        if (failure == ProfileFailure.storageUnavailable) {
          developer.log(
            'Profile storage unavailable',
            name: 'profile_repository',
            error: r['operation'],
          );
        }
        return ProfileResult.error(failure);
      }
      return ProfileResult.success(map(result));
    } catch (e) {
      developer.log(
        'Profile storage unavailable',
        name: 'profile_repository',
        error: e.runtimeType,
      );
      return const ProfileResult.error(ProfileFailure.storageUnavailable);
    }
  }

  @override
  Future<ProfileResult<LocalProfile?>> load() => _run(
    {'operation': 'load'},
    (r) => r['profile'] == null
        ? null
        : _map(Map<String, Object?>.from(r['profile'] as Map)),
  );
  @override
  Future<ProfileResult<LocalProfile>> save(ProfileDraft d) async {
    if (d.errors.isNotEmpty) {
      return const ProfileResult.error(ProfileFailure.validation);
    }
    final result = await _run({
      'operation': 'save',
      'id': d.id,
      'name': d.name.trim(),
      'appearance': d.appearance.name,
      'language': d.language.name,
      'avatar': d.avatar,
      'expected': d.expectedRevision,
    }, (r) => _map(Map<String, Object?>.from(r['profile'] as Map)));
    if (result.isSuccess && !_changes.isClosed) _changes.add(result.value!);
    return result;
  }

  @override
  Future<void> dispose() => _changes.close();
}
