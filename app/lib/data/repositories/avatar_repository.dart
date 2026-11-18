import 'package:flutter/services.dart';
import 'package:app/data/services/avatar_services.dart';
import 'package:app/domain/models/local_profile.dart';

abstract class AvatarRepository {
  Future<AvatarSelection> choose();
}

class LocalAvatarRepository implements AvatarRepository {
  LocalAvatarRepository({
    Future<AvatarSource?> Function()? pick,
    AvatarCodec? codec,
  }) : _pick = pick ?? selectLocalAvatar,
       _codec = codec ?? AvatarCodec();
  final Future<AvatarSource?> Function() _pick;
  final AvatarCodec _codec;
  @override
  Future<AvatarSelection> choose() async {
    try {
      final source = await _pick();
      if (source == null) return const AvatarSelection.canceled();
      if (source.length > 5242880) {
        return const AvatarSelection.failed(AvatarFailure.tooLarge);
      }
      final bytes = await source.read();
      if (bytes.length > 5242880) {
        return const AvatarSelection.failed(AvatarFailure.tooLarge);
      }
      return await _codec.normalize(bytes);
    } on UnsupportedError {
      return const AvatarSelection.failed(AvatarFailure.unsupportedPlatform);
    } on MissingPluginException {
      return const AvatarSelection.failed(AvatarFailure.unsupportedPlatform);
    } catch (_) {
      return const AvatarSelection.failed(AvatarFailure.selectionUnavailable);
    }
  }
}
