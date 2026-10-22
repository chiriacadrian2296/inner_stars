import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/life_area.dart';
import '../utils/area_hero_art.dart';
import '../utils/area_hero_art_tint.dart';
import 'constellation_field.dart';

/// An early look at using every [kAreaHeroArt] area's own hero art (see
/// assets/images) as part of the sky itself, not just its detail page — a
/// huge, faint wash of each area's image sitting behind its own supernova.
/// Painted before [SkyAreaSigils]/[SkySupernova] in `NebulaScreen`'s Stack
/// so both sit on top of it, additively (`BlendMode.plus`, the same glow
/// blend those two widgets already use for their own painting) so only the
/// image's own bright nebula/figure pixels ever show at all — its black
/// background contributes nothing under that blend, so it never reads as a
/// rectangle sitting on the sky.
///
/// Only areas listed in [kAreaHeroArt] have art of their own so far, so
/// this paints nothing for any other area.
class SkyAreaBackdrop extends StatefulWidget {
  const SkyAreaBackdrop({
    super.key,
    required this.camera,
    required this.zoom,
    this.opacity = 0.5,
    this.blendMode = BlendMode.plus,
    this.scale = 1,
    this.color = kAreaHeroArtTintHue,
  });

  final SkyCamera camera;
  final double zoom;

  /// 0..1 strength of the artwork wash, and how it composites onto the sky
  /// (see `ArtworkBlend`) — the defaults are the original fixed look.
  final double opacity;
  final BlendMode blendMode;
  final double scale;
  final Color color;

  @override
  State<SkyAreaBackdrop> createState() => _SkyAreaBackdropState();
}

class _SkyAreaBackdropState extends State<SkyAreaBackdrop> {
  Map<LifeArea, ui.Image>? _images;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final entries = await Future.wait(
      kAreaHeroArt.entries.map((entry) async {
        final bytes = await rootBundle.load(entry.value.skyAsset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        return MapEntry(entry.key, frame.image);
      }),
    );
    if (!mounted) return;
    setState(() => _images = Map.fromEntries(entries));
  }

  @override
  void dispose() {
    for (final image in _images?.values ?? const <ui.Image>[]) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images == null) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _SkyAreaBackdropPainter(
        images: images,
        camera: widget.camera,
        zoom: widget.zoom,
        opacity: widget.opacity,
        blendMode: widget.blendMode,
        scale: widget.scale,
        color: widget.color,
      ),
    );
  }
}

typedef _Vec3 = (double x, double y, double z);

double _dot3(_Vec3 a, _Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

/// Same forward projection as `sky_supernova.dart`'s own private
/// `_projectDirection`/`sky_area_sigils.dart`'s own copy of it — see either
/// file's doc comment for why this is duplicated rather than shared.
(Offset, double)? _projectDirection(
  _Vec3 dir,
  SkyCamera camera,
  double zoom,
  Size size,
) {
  final z = _dot3(dir, camera.forward);
  if (z < -0.5) return null;
  final scale = 2 / (1 + z);
  final x = _dot3(dir, camera.right) * scale;
  final y = _dot3(dir, camera.up) * scale;
  return (
    Offset(
      size.width / 2 + x * zoom * size.height,
      size.height / 2 - y * zoom * size.height,
    ),
    scale,
  );
}

class _SkyAreaBackdropPainter extends CustomPainter {
  const _SkyAreaBackdropPainter({
    required this.images,
    required this.camera,
    required this.zoom,
    required this.opacity,
    required this.blendMode,
    required this.scale,
    required this.color,
  });

  final Map<LifeArea, ui.Image> images;
  final SkyCamera camera;
  final double zoom;
  final double opacity;
  final BlendMode blendMode;
  final double scale;
  final Color color;

  // Well past the supernova's own light-ring (world radius 0.0405, see
  // sky_area_sigils.dart) but nowhere near the 0.42 first tried — that read
  // as far too large on screen. 0.1, then 0.2, both read a little small.
  static const _worldRadius = 0.15;

  // Where the circular vignette (see [_paintOne]) starts fading from fully
  // visible toward transparent, as a fraction of the image's own radius —
  // the fade itself runs from here out to 1.0 (the edge of the inscribed
  // circle, see that gradient's own comment).
  static const _vignetteStart = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in images.entries) {
      final direction = supernovaDirection(
        entry.key.index,
        LifeArea.values.length,
      );
      _paintOne(canvas, size, direction, entry.value);
    }
  }

  void _paintOne(Canvas canvas, Size size, _Vec3 direction, ui.Image image) {
    final projected = _projectDirection(direction, camera, zoom, size);
    if (projected == null) return;
    final (center, _) = projected;
    // The centre follows the spherical projection, but the large artwork is
    // a screen-facing backdrop rather than geometry on that sphere. Keeping
    // its visual size and orientation stable prevents the web viewport's
    // wider corners from stretching and spinning it independently of the
    // supernova it belongs to.
    final diameter = _worldRadius * scale * 2 * zoom * size.height;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(center.dx, center.dy);

    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: diameter,
      height: diameter,
    );

    // Drawn into its own layer first — rather than straight onto the sky —
    // so the vignette below can mask *this image's own* alpha (via
    // BlendMode.dstIn) before the whole thing is composited onto the sky
    // additively in one go, instead of the vignette fading to whatever
    // happened to already be painted underneath.
    canvas.saveLayer(
      localRect,
      Paint()
        ..blendMode = blendMode
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      localRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = areaHeroArtTint(color),
    );

    if (!kUseRoyalArtworkPreview) {
      // Original art needs a circular fade to erase its square corners.
      canvas.drawRect(
        localRect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            Offset.zero,
            diameter / 2,
            const [Colors.white, Colors.white, Colors.transparent],
            const [0.0, _vignetteStart, 1.0],
          ),
      );
    }
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkyAreaBackdropPainter oldDelegate) =>
      !identical(oldDelegate.images, images) ||
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom ||
      oldDelegate.opacity != opacity ||
      oldDelegate.blendMode != blendMode ||
      oldDelegate.scale != scale ||
      oldDelegate.color != color;
}
