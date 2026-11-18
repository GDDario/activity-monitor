import 'package:flutter/foundation.dart';
import 'package:app/data/repositories/profile_repository.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/domain/models/local_profile.dart';

enum ProfileStatus { loading, setupRequired, ready, unavailable }

class ProfileSessionState {
  const ProfileSessionState({
    this.status = ProfileStatus.loading,
    this.profile,
    this.failure,
  });
  final ProfileStatus status;
  final ProfileFailure? failure;
  final LocalProfile? profile;
}

class ProfileSessionViewModel extends ChangeNotifier {
  ProfileSessionViewModel({required this._load, LocalProfile? initial})
    : _state = ProfileSessionState(
        status: initial == null ? ProfileStatus.loading : ProfileStatus.ready,
        profile: initial,
      ),
      _started = initial != null;
  final Future<ProfileResult<LocalProfile?>> Function() _load;
  ProfileSessionState _state;
  ProfileSessionState get state => _state;
  bool _disposed = false, _started;
  int _sequence = 0;
  Future<void> load({bool force = false}) async {
    if (_disposed || (_started && !force)) return;
    _started = true;
    final seq = ++_sequence;
    _state = ProfileSessionState(
      status: state.profile == null
          ? ProfileStatus.loading
          : ProfileStatus.ready,
      profile: state.profile,
    );
    notifyListeners();
    ProfileResult<LocalProfile?> result;
    try {
      result = await _load();
    } catch (_) {
      result = const ProfileResult.error(ProfileFailure.storageUnavailable);
    }
    if (_disposed || seq != _sequence) return;
    if (result.isSuccess) {
      _state = ProfileSessionState(
        status: result.value == null
            ? ProfileStatus.setupRequired
            : ProfileStatus.ready,
        profile: result.value,
      );
    } else {
      _state = ProfileSessionState(
        status: state.profile == null
            ? ProfileStatus.unavailable
            : ProfileStatus.ready,
        profile: state.profile,
        failure: result.failure,
      );
    }
    notifyListeners();
  }

  void accept(LocalProfile profile) {
    if (_disposed) return;
    if (state.status == ProfileStatus.ready &&
        state.profile?.id == profile.id &&
        state.profile?.revision == profile.revision) {
      return;
    }
    _sequence++;
    _started = true;
    _state = ProfileSessionState(status: ProfileStatus.ready, profile: profile);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}

class ProfileEditorState {
  const ProfileEditorState({
    required this.draft,
    this.saving = false,
    this.picking = false,
    this.dirty = false,
    this.saved = false,
    this.showErrors = false,
    this.failure,
    this.avatarFailure,
  });
  final ProfileDraft draft;
  final bool saving, picking, dirty, saved, showErrors;
  final ProfileFailure? failure;
  final AvatarFailure? avatarFailure;
}

class ProfileEditorViewModel extends ChangeNotifier {
  ProfileEditorViewModel({
    required this.repository,
    required this.avatars,
    required ProfileDraft draft,
    this.onSaved,
  }) : _state = ProfileEditorState(draft: draft);
  final ProfileRepository repository;
  final AvatarRepository avatars;
  final void Function(LocalProfile)? onSaved;
  ProfileEditorState _state;
  ProfileEditorState get state => _state;
  bool _disposed = false;
  int _photoSequence = 0;
  bool get canEdit => !_disposed && !state.saving && !state.saved;
  void change({
    String? name,
    ProfileAppearance? appearance,
    ProfileLanguage? language,
  }) {
    if (!canEdit) return;
    _state = ProfileEditorState(
      draft: state.draft.copyWith(
        name: name,
        appearance: appearance,
        language: language,
      ),
      dirty: true,
      picking: state.picking,
      showErrors: state.showErrors,
    );
    notifyListeners();
  }

  void removeAvatar() {
    if (!canEdit) return;
    _photoSequence++;
    _state = ProfileEditorState(
      draft: state.draft.copyWith(avatar: null),
      dirty: true,
      showErrors: state.showErrors,
    );
    notifyListeners();
  }

  Future<void> chooseAvatar() async {
    if (!canEdit || state.picking) return;
    final seq = ++_photoSequence;
    _state = ProfileEditorState(
      draft: state.draft,
      dirty: state.dirty,
      picking: true,
      showErrors: state.showErrors,
    );
    notifyListeners();
    AvatarSelection result;
    try {
      result = await avatars.choose();
    } catch (_) {
      result = const AvatarSelection.failed(AvatarFailure.selectionUnavailable);
    }
    if (_disposed || seq != _photoSequence) return;
    _state = ProfileEditorState(
      draft: result.image == null
          ? state.draft
          : state.draft.copyWith(avatar: result.image),
      dirty: state.dirty || result.image != null,
      showErrors: state.showErrors,
      avatarFailure: result.failure,
    );
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canEdit || state.picking) return false;
    if (state.draft.errors.isNotEmpty) {
      _state = ProfileEditorState(
        draft: state.draft,
        dirty: state.dirty,
        showErrors: true,
      );
      notifyListeners();
      return false;
    }
    _state = ProfileEditorState(
      draft: state.draft,
      dirty: state.dirty,
      saving: true,
    );
    notifyListeners();
    ProfileResult<LocalProfile> result;
    try {
      result = await repository.save(state.draft);
    } catch (_) {
      result = const ProfileResult.error(ProfileFailure.storageUnavailable);
    }
    if (_disposed) return false;
    _state = ProfileEditorState(
      draft: state.draft,
      dirty: !result.isSuccess,
      saved: result.isSuccess,
      failure: result.failure,
    );
    notifyListeners();
    if (result.isSuccess) onSaved?.call(result.value!);
    return result.isSuccess;
  }

  @override
  void dispose() {
    _disposed = true;
    _photoSequence++;
    super.dispose();
  }
}
