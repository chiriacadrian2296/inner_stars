import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/photo_storage.dart';

/// Displays a star's photo from [photoPath] — whatever [PhotoStorage] used to
/// save it (a real file path on native, a [SharedPreferences]-backed key on
/// web) — behind one async read, so every photo display site works the same
/// on both platforms instead of assuming a real filesystem. Renders nothing
/// while loading or if the photo is missing; callers that need a fallback
/// (e.g. a background gradient) already layer one behind this.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.photoPath,
    required this.fit,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.cacheWidth,
  });

  final String photoPath;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Decode the photo no wider than this many pixels — for a small display
  /// of a full-size photo, so it doesn't sit in memory at camera resolution.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final cached = PhotoStorage.cachedBytes(photoPath);
    if (cached != null) return _image(cached);

    return FutureBuilder<Uint8List?>(
      future: PhotoStorage.readBytes(photoPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return SizedBox(width: width, height: height);
        return _image(bytes);
      },
    );
  }

  Widget _image(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
    );
  }
}
