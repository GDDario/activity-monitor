import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/app_database.dart';
import 'package:app/data/services/profile_database.dart';
import 'package:app/data/repositories/profile_repository.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/data/services/avatar_services.dart';

import 'helpers/profile_image_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String path;
  late ProfileRepository repo;
  setUp(() {
    dir = Directory('../.scratches/profile-validation')
        .createTempSync('storage-');
    path = '${dir.path}/test.db';
    initializeDatabaseAtPath(path);
    repo = LocalProfileRepository(ProfileDatabase(path: path));
  });
  tearDown(() async {
    await repo.dispose();
    dir.deleteSync(recursive: true);
  });
  test('absent profile is successful and saved preferences/avatar survive reopening', () async {
    final empty = await repo.load();
    expect(empty.isSuccess, true);
    expect(empty.value, isNull);
    final created = await repo.save(
      ProfileDraft(
        id: 'p',
        name: ' Robin ',
        appearance: ProfileAppearance.dark,
        language: ProfileLanguage.ptBr,
        avatar: Uint8List.fromList([1, 2, 3]),
      ),
    );
    expect(created.isSuccess, true);
    final reopened = LocalProfileRepository(ProfileDatabase(path: path));
    addTearDown(reopened.dispose);
    final p = (await reopened.load()).value!;
    expect(p.name.value, 'Robin');
    expect(p.appearance, ProfileAppearance.dark);
    expect(p.language, ProfileLanguage.ptBr);
    expect(p.avatar, [1, 2, 3]);
  });
  test(
    'singleton conflicts and stale writes leave complete saved profile intact',
    () async {
      final first = (await repo.save(ProfileDraft(id: 'p', name: 'Robin')))
          .value!;
      expect(
        (await repo.save(ProfileDraft(id: 'other', name: 'Other'))).failure,
        ProfileFailure.identityConflict,
      );
      expect(
        (await repo.save(ProfileDraft.fromProfile(first).copyWith(name: 'New')))
            .isSuccess,
        true,
      );
      expect(
        (await repo.save(
          ProfileDraft.fromProfile(first)
              .copyWith(name: 'Old', appearance: ProfileAppearance.dark),
        )).failure,
        ProfileFailure.staleRevision,
      );
      expect((await repo.load()).value!.name.value, 'New');
      expect((await repo.load()).value!.appearance, ProfileAppearance.system);
    },
  );
  test(
    'invalid name saves nothing and unavailable is distinct from absent',
    () async {
      expect(
        (await repo.save(ProfileDraft(id: 'p', name: ''))).failure,
        ProfileFailure.validation,
      );
      expect((await repo.load()).value, isNull);
      final missing = LocalProfileRepository(
        ProfileDatabase(path: '${dir.path}/missing.db'),
      );
      addTearDown(missing.dispose);
      expect((await missing.load()).failure, ProfileFailure.storageUnavailable);
    },
  );
  test('database constraint failure rolls back all profile fields', () async {
    await repo.save(ProfileDraft(id: 'p', name: 'Robin'));
    final service = ProfileDatabase(path: path);
    final result = await service.request({
      'operation': 'save',
      'id': 'p',
      'name': 'Changed',
      'appearance': 'invalid',
      'language': 'ptBr',
      'avatar': null,
      'expected': 0,
    });
    expect(result['failure'], 'storageUnavailable');
    expect((await repo.load()).value!.name.value, 'Robin');
    final db = sqlite3.open(path);
    expect(db.select('PRAGMA user_version').single.values.single, 6);
    db.close();
  });
  test(
    'saved normalized avatar is owned after the source file is removed',
    () async {
      final source = File('${dir.path}/source.png');
      await source.writeAsBytes(await profileImageFixture(32, 16));
      final selection = await LocalAvatarRepository(
        pick: () async => AvatarSource(
          length: await source.length(),
          read: source.readAsBytes,
        ),
      ).choose();
      expect(selection.failure, isNull);
      await source.delete();
      expect(
        (await repo.save(
          ProfileDraft(id: 'p', name: 'Robin', avatar: selection.image),
        )).isSuccess,
        true,
      );
      final reopened = LocalProfileRepository(ProfileDatabase(path: path));
      addTearDown(reopened.dispose);
      expect((await reopened.load()).value!.avatar, selection.image);
    },
  );
}
