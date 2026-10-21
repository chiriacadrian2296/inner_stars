import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest side, in pixels, of a photo sent to the cloud. Photos are shown on
/// a phone screen, so more than this only costs storage and data.
const int kUploadPhotoMaxSide = 1600;
const int kUploadPhotoQuality = 82;

/// Shrinks [bytes] to at most [maxSide] pixels on the long side and re-encodes
/// it as JPEG. Returns the original bytes when they cannot be decoded (not an
/// image) or when the result would not be smaller, so a photo never gets worse
/// or bigger by being uploaded.
Uint8List compressPhoto(
  Uint8List bytes, {
  int maxSide = kUploadPhotoMaxSide,
  int quality = kUploadPhotoQuality,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longest > maxSide
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  return encoded.length < bytes.length ? encoded : bytes;
}
