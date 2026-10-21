import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/photo_storage.dart';
import '../sync/media/media_hooks.dart';

/// Displays a star's photo from [photoPath] — either a remote placeholder used
/// by sample data or whatever [PhotoStorage] used to save a user-picked photo.
/// Renders nothing while loading or if the photo is missing; callers that need
/// a fallback (e.g. a background gradient) already layer one behind this.
///
/// A photo another device just added can be missing at first: the star's
/// record reaches this device a moment before the file reaches the cloud. So
/// while the cloud sync is on, a missing photo is looked for again a few times
/// (see [photoRetryDelays]) instead of staying blank until the screen is
/// rebuilt.
class PhotoImage extends StatefulWidget {
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

  /// How long to wait before each new look for a missing photo. Visible for
  /// tests.
  static List<Duration> photoRetryDelays = const [
    Duration(seconds: 4),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 90),
  ];

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  Future<Uint8List?>? _future;
  Timer? _retry;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) {
      _retry?.cancel();
      _attempt = 0;
      _load();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _load() {
    final path = widget.photoPath;
    if (PhotoStorage.isRemote(path) || PhotoStorage.cachedBytes(path) != null) {
      _future = null;
      return;
    }
    _future = PhotoStorage.readBytes(path).then((bytes) {
      final delays = PhotoImage.photoRetryDelays;
      if (bytes == null &&
          mounted &&
          MediaHooks.instance != null &&
          _attempt < delays.length) {
        _retry = Timer(delays[_attempt++], () {
          if (mounted) setState(_load);
        });
      }
      return bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.photoPath;
    if (PhotoStorage.isRemote(path)) {
      return Image.network(
        path,
        fit: widget.fit,
        alignment: widget.alignment,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            SizedBox(width: widget.width, height: widget.height),
      );
    }

    final cached = PhotoStorage.cachedBytes(path);
    if (cached != null) return _image(cached);

    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return _image(bytes);
      },
    );
  }

  Widget _image(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: widget.fit,
      alignment: widget.alignment,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
    );
  }
}
