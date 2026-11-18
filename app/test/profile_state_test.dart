import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

import 'helpers/fake_profile_repository.dart';

class WaitingAvatar implements AvatarRepository {
  final result = Completer<AvatarSelection>();
  @override
  Future<AvatarSelection> choose() => result.future;
}

void main() {
  test(
    'unavailable initial read cannot become writable setup and retry recovers',
    () async {
      var fail = true;
      final model = ProfileSessionViewModel(
        load: () async => fail
            ? const ProfileResult.error(ProfileFailure.storageUnavailable)
            : const ProfileResult.success(null),
      );
      addTearDown(model.dispose);
      await model.load();
      expect(model.state.status, ProfileStatus.unavailable);
      fail = false;
      await model.load(force: true);
      expect(model.state.status, ProfileStatus.setupRequired);
    },
  );
  test('new committed profile supersedes an older pending read', () async {
    final c = Completer<ProfileResult<LocalProfile?>>();
    final model = ProfileSessionViewModel(load: () => c.future);
    addTearDown(model.dispose);
    final load = model.load();
    model.accept(exampleProfile());
    c.complete(const ProfileResult.success(null));
    await load;
    expect(model.state.profile!.name.value, 'Robin Ward');
  });
  test(
    'failed save retains draft and delayed picker cannot undo explicit removal',
    () async {
      final repo = FakeProfileRepository();
      final picker = WaitingAvatar();
      final model = ProfileEditorViewModel(
        repository: repo,
        avatars: picker,
        draft: ProfileDraft(id: 'p', name: ''),
      );
      addTearDown(model.dispose);
      addTearDown(repo.dispose);
      expect(await model.save(), false);
      expect(repo.saves, 0);
      model.change(name: 'Robin');
      repo.failure = ProfileFailure.storageUnavailable;
      expect(await model.save(), false);
      expect(model.state.draft.name, 'Robin');
      final choose = model.chooseAvatar();
      model.removeAvatar();
      picker.result.complete(
        AvatarSelection.selected(Uint8List.fromList([1, 2, 3])),
      );
      await choose;
      expect(model.state.draft.avatar, isNull);
    },
  );
  test('repeated save while in flight reaches persistence only once', () async {
    final repo = FakeProfileRepository();
    final model = ProfileEditorViewModel(
      repository: repo,
      avatars: WaitingAvatar(),
      draft: ProfileDraft(id: 'p', name: 'Robin'),
    );
    addTearDown(repo.dispose);
    addTearDown(model.dispose);
    final first = model.save();
    final second = model.save();
    expect(await second, false);
    expect(await first, true);
    expect(repo.saves, 1);
  });
}
