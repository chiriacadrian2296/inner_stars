import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Camera photos are commonly stored with their sensor's native (often
/// landscape) pixel layout plus an EXIF orientation tag saying how to
/// rotate them for display — but `dart:ui`'s own JPEG decoder doesn't apply
/// that tag, so decoding the raw bytes directly would report width/height
/// that don't match how the photo is meant to look, throwing off both this
/// screen's "cover" scale math and (via [RawImage]'s [BoxFit.fill]) the
/// photo's own proportions. Baking the rotation into the pixels first,
/// off the UI thread since it's real decode/re-encode work, avoids both.
Uint8List _bakeOrientation(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return img.encodeJpg(img.bakeOrientation(decoded), quality: 92);
}

/// The rendered crop frame's raw RGBA pixels (from [RenderRepaintBoundary]),
/// bundled into one payload so [_encodeJpeg] can run through [compute] —
/// which takes a single argument.
typedef _RawFrame = ({int width, int height, Uint8List rgba});

/// Re-encodes the cropped frame as JPEG rather than keeping the PNG
/// [RenderRepaintBoundary.toImage] naturally produces — PNG is lossless but
/// far bigger for a photo, and on web every saved photo lives as a
/// base64-encoded [SharedPreferences] entry (see `PhotoStorage`), where
/// [SharedPreferences]'s underlying localStorage has only a few MB of quota
/// for the *entire* app to share.
Uint8List _encodeJpeg(_RawFrame frame) {
  final image = img.Image.fromBytes(
    width: frame.width,
    height: frame.height,
    bytes: frame.rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 85);
}

/// Forces every star photo through the same 9:16 crop before it's saved —
/// whether it came from the camera or an arbitrarily-shaped gallery photo —
/// since a win's photo is always used as a full-bleed background (see
/// win_reader_screen.dart), and matching the phone's own portrait screen
/// shape there matters more than preserving whatever shape the source photo
/// happened to have.
///
/// Pops with the cropped image's encoded JPEG bytes, or null if the user
/// backed out without confirming.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.imageFile});

  // XFile (not dart:io's File) so this works on web too — its readAsBytes
  // reads from the picker's blob URL there, where File is a non-functional
  // stub.
  final XFile imageFile;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const _aspectRatio = 9 / 16;
  // Smaller on web: every photo there is a base64 string sharing a few MB of
  // total localStorage quota with the rest of the app's data (see
  // `PhotoStorage`), so it needs to be far more frugal than native's own
  // filesystem, which has no such shared cap.
  static const _outputWidth = kIsWeb ? 800.0 : 1600.0;
  // On a phone the crop frame is meant to span the full (narrow) screen
  // width. On a wide PC/web window, sizing it off the full window width
  // would make the 9:16 frame far taller than the window itself — capped
  // to a phone-like width instead, so the frame stays fully visible and
  // still crops to the same shape the photo will actually be shown in.
  static const _maxFrameWidthWide = 420.0;

  double _frameWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return isWideLayout(context) ? math.min(width, _maxFrameWidthWide) : width;
  }

  final _boundaryKey = GlobalKey();
  final _transformController = TransformationController();
  ui.Image? _image;
  double _minScale = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    // Not framework-managed like an ImageProvider's — this one was decoded
    // directly via instantiateImageCodec, so it's on us to release its
    // native memory.
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final rawBytes = await widget.imageFile.readAsBytes();
    final bytes = await compute(_bakeOrientation, rawBytes);
    if (!mounted) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }

    final image = frame.image;
    final width = _frameWidth(context);
    final height = width / _aspectRatio;
    // The minimum zoom that still lets the image fully cover the crop
    // frame — also its starting scale, so the photo opens centered and
    // already covering the frame rather than at some arbitrary zoom.
    final scale = math.max(width / image.width, height / image.height);
    final dx = (width - image.width * scale) / 2;
    final dy = (height - image.height * scale) / 2;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);

    setState(() {
      _image = image;
      _minScale = scale;
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Rendered at a fixed output width regardless of the crop frame's own
      // on-screen pixel size, so the saved photo has consistent resolution
      // across devices.
      final pixelRatio = _outputWidth / boundary.size.width;
      final rendered = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted) return;
      if (byteData == null) throw StateError('toByteData returned null');
      final jpegBytes = await compute(_encodeJpeg, (
        width: rendered.width,
        height: rendered.height,
        rgba: byteData.buffer.asUint8List(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(jpegBytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.strings.photoPickError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final image = _image;
    final width = _frameWidth(context);
    final height = width / _aspectRatio;

    return Scaffold(
      backgroundColor: colors.night,
      appBar: AppBar(
        backgroundColor: colors.night,
        foregroundColor: colors.text,
        title: Text(strings.cropPhotoTitle),
        actions: [
          TextButton(
            onPressed: image == null || _saving ? null : _confirm,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.gold),
                  )
                : Text(strings.cropPhotoConfirm, style: TextStyle(color: colors.gold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: image == null
          ? Center(child: CircularProgressIndicator(color: colors.gold))
          // The app bar already clears the top inset; this only needs to
          // protect the hint text from the bottom system bar — on edge-to-
          // edge Android (gesture nav or a translucent button bar), body
          // content otherwise renders underneath it.
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ClipRect(
                          child: SizedBox(
                            width: width,
                            height: height,
                            // boundaryMargin: zero plus minScale set to the
                            // exact "cover" scale keeps the image edges from
                            // ever panning past the frame, so the frame is
                            // always fully covered no matter how the user
                            // drags or pinches. constrained: false is what
                            // lets the child actually lay out at its own
                            // (much larger) natural size instead of being
                            // squashed down to this frame's — without it,
                            // InteractiveViewer applies our zoom on top of
                            // an already-shrunk child, leaving the photo a
                            // tiny fragment stuck in one corner.
                            child: InteractiveViewer(
                              transformationController: _transformController,
                              constrained: false,
                              minScale: _minScale,
                              maxScale: _minScale * 4,
                              boundaryMargin: EdgeInsets.zero,
                              child: SizedBox(
                                width: image.width.toDouble(),
                                height: image.height.toDouble(),
                                child: RawImage(image: image, fit: BoxFit.fill),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      strings.cropPhotoHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
