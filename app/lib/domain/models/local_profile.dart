import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:app/domain/value_objects/bounded_text.dart';

enum ProfileAppearance { system, light, dark }

enum ProfileLanguage { device, enUs, ptBr }

class ProfileName {
  ProfileName(String input) : value = boundedText(input, 100);
  final String value;
}

String profileInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'AM';
  return '${parts.first.characters.first}${parts.length > 1 ? parts.last.characters.first : ''}'
      .toUpperCase();
}

ProfileLanguage resolveProfileLanguage(List<String> tags) {
  for (final tag in tags) {
    final language = tag.toLowerCase().split(RegExp('[-_]')).first;
    if (language == 'pt') return ProfileLanguage.ptBr;
    if (language == 'en') return ProfileLanguage.enUs;
  }
  return ProfileLanguage.enUs;
}

class LocalProfile {
  LocalProfile({
    required this.id,
    required this.name,
    this.appearance = ProfileAppearance.system,
    this.language = ProfileLanguage.device,
    Uint8List? avatar,
    this.revision = 0,
  }) : avatar = avatar == null
           ? null
           : Uint8List.fromList(avatar).asUnmodifiableView();
  final String id;
  final ProfileName name;
  final ProfileAppearance appearance;
  final ProfileLanguage language;
  final Uint8List? avatar;
  final int revision;
}

const _keepProfileAvatar = Object();

class ProfileDraft {
  ProfileDraft({
    required this.id,
    required this.name,
    this.appearance = ProfileAppearance.system,
    this.language = ProfileLanguage.device,
    Uint8List? avatar,
    this.expectedRevision,
  }) : avatar = avatar == null
           ? null
           : Uint8List.fromList(avatar).asUnmodifiableView();
  factory ProfileDraft.fromProfile(LocalProfile p) => ProfileDraft(
    id: p.id,
    name: p.name.value,
    appearance: p.appearance,
    language: p.language,
    avatar: p.avatar,
    expectedRevision: p.revision,
  );
  final String id, name;
  final ProfileAppearance appearance;
  final ProfileLanguage language;
  final Uint8List? avatar;
  final int? expectedRevision;
  Map<String, String> get errors {
    final result = <String, String>{};
    try {
      ProfileName(name);
    } on ArgumentError {
      result['name'] = 'invalid';
    }
    if (id.trim().isEmpty) result['id'] = 'invalid';
    if (avatar != null &&
        (avatar!.isEmpty || avatar!.length > 5 * 1024 * 1024)) {
      result['avatar'] = 'invalid';
    }
    return result;
  }

  ProfileDraft copyWith({
    String? name,
    ProfileAppearance? appearance,
    ProfileLanguage? language,
    Object? avatar = _keepProfileAvatar,
  }) => ProfileDraft(
    id: id,
    name: name ?? this.name,
    appearance: appearance ?? this.appearance,
    language: language ?? this.language,
    avatar: identical(avatar, _keepProfileAvatar)
        ? this.avatar
        : avatar as Uint8List?,
    expectedRevision: expectedRevision,
  );
}

enum ProfileFailure {
  validation,
  notFound,
  staleRevision,
  identityConflict,
  storageUnavailable,
}

class ProfileResult<T> {
  const ProfileResult.success(this.value) : failure = null;
  const ProfileResult.error(this.failure) : value = null;
  final T? value;
  final ProfileFailure? failure;
  bool get isSuccess => failure == null;
}

enum AvatarFailure {
  unsupportedPlatform,
  selectionUnavailable,
  unsupportedFormat,
  invalidImage,
  tooLarge,
}

class AvatarSelection {
  AvatarSelection.selected(Uint8List image)
    : image = Uint8List.fromList(image).asUnmodifiableView(),
      failure = null,
      canceled = false;
  const AvatarSelection.canceled()
    : image = null,
      failure = null,
      canceled = true;
  const AvatarSelection.failed(this.failure) : image = null, canceled = false;
  final Uint8List? image;
  final AvatarFailure? failure;
  final bool canceled;
}
