import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/data/services/avatar_services.dart';
import 'package:app/domain/models/local_profile.dart';

import 'helpers/profile_image_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cancel and overlarge reported input never read or replace image',
    () async {
      final canceled = LocalAvatarRepository(pick: () async => null);
      expect((await canceled.choose()).canceled, true);
      var read = false;
      final large = LocalAvatarRepository(
        pick: () async => AvatarSource(
          length: 5242881,
          read: () async {
            read = true;
            return Uint8List(0);
          },
        ),
      );
      expect((await large.choose()).failure, AvatarFailure.tooLarge);
      expect(read, false);
    },
  );
  test(
    'normalization accepts real image and bounds its longest edge',
    () async {
      final bytes = await profileImageFixture(2048, 1024);
      final repo = LocalAvatarRepository(
        pick: () async =>
            AvatarSource(length: bytes.length, read: () async => bytes),
      );
      final selected = await repo.choose();
      expect(selected.failure, isNull);
      final codec = await ui.instantiateImageCodec(selected.image!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1024);
      expect(frame.image.height, 512);
      frame.image.dispose();
      codec.dispose();
    },
  );
  test('unsupported and corrupt contents fail explicitly', () async {
    final bmp = Uint8List.fromList([66, 77, 0, 0]);
    expect(
      (await LocalAvatarRepository(
        pick: () async =>
            AvatarSource(length: bmp.length, read: () async => bmp),
      ).choose()).failure,
      AvatarFailure.unsupportedFormat,
    );
    final corrupt = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]);
    expect(
      (await LocalAvatarRepository(
        pick: () async =>
            AvatarSource(length: corrupt.length, read: () async => corrupt),
      ).choose()).failure,
      AvatarFailure.invalidImage,
    );
  });
  test(
    'JPEG contents normalize to PNG and actual bytes cannot exceed the limit',
    () async {
      final jpeg = profileJpegFixture();
      final selected = await LocalAvatarRepository(
        pick: () async =>
            AvatarSource(length: jpeg.length, read: () async => jpeg),
      ).choose();
      expect(selected.failure, isNull);
      expect(selected.image!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final oversized = LocalAvatarRepository(
        pick: () async =>
            AvatarSource(length: 1, read: () async => Uint8List(5242881)),
      );
      expect((await oversized.choose()).failure, AvatarFailure.tooLarge);
    },
  );
}
