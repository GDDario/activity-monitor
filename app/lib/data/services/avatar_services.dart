import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:app/domain/models/local_profile.dart';

class AvatarSource {
  const AvatarSource({required this.length, required this.read});
  final int length;
  final Future<Uint8List> Function() read;
}

Future<AvatarSource?> selectLocalAvatar() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'JPEG / PNG',
        extensions: ['jpg', 'jpeg', 'png'],
        mimeTypes: ['image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
      ),
    ],
  );
  if (file == null) return null;
  return AvatarSource(length: await file.length(), read: file.readAsBytes);
}

class AvatarCodec {
  Future<AvatarSelection> normalize(Uint8List bytes) async {
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      return const AvatarSelection.failed(AvatarFailure.unsupportedFormat);
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        1024 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return const AvatarSelection.failed(AvatarFailure.invalidImage);
      }
      final result = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (result.length > 5242880) {
        return const AvatarSelection.failed(AvatarFailure.tooLarge);
      }
      return AvatarSelection.selected(result);
    } catch (_) {
      return const AvatarSelection.failed(AvatarFailure.invalidImage);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
