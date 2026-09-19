import 'dart:math' as math;
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
  const SkyAreaBackdrop({super.key, required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

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
      ),
    );
  }
}

typedef _Vec3 = (double x, double y, double z);

double _dot3(_Vec3 a, _Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

_Vec3 _cross3(_Vec3 a, _Vec3 b) => (
  a.$2 * b.$3 - a.$3 * b.$2,
  a.$3 * b.$1 - a.$1 * b.$3,
  a.$1 * b.$2 - a.$2 * b.$1,
);

_Vec3 _add3(_Vec3 a, _Vec3 b) => (a.$1 + b.$1, a.$2 + b.$2, a.$3 + b.$3);

_Vec3 _scaled3(_Vec3 a, double s) => (a.$1 * s, a.$2 * s, a.$3 * s);

_Vec3 _normalized3(_Vec3 v) {
  final length = math.sqrt(_dot3(v, v));
  return (v.$1 / length, v.$2 / length, v.$3 / length);
}

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

/// Same local frame `sky_area_sigils.dart`'s own `_axisAFor` builds — see
/// that file's doc comment for the full derivation. Used here for the same
/// reason: without it, a backdrop would sit screen-aligned no matter how
/// the camera moves, rather than reading as pinned to the sky at its own
/// area's spot the way a real patch of nebula would be.
_Vec3 _axisAFor(_Vec3 center) {
  final reference = center.$2.abs() < 0.99 ? (0.0, 1.0, 0.0) : (1.0, 0.0, 0.0);
  return _normalized3(_cross3(reference, center));
}

/// Same small-offset technique as `sky_area_sigils.dart`'s own
/// `_rotationAngleFor` — the on-screen angle [axisA] itself projects to,
/// relative to [screenCenter].
double _rotationAngleFor(
  _Vec3 center,
  _Vec3 axisA,
  Offset screenCenter,
  SkyCamera camera,
  double zoom,
  Size size,
) {
  const epsilon = 0.01;
  final offsetDir = _normalized3(_add3(center, _scaled3(axisA, epsilon)));
  final offsetProjected = _projectDirection(offsetDir, camera, zoom, size);
  if (offsetProjected == null) return 0.0;
  final delta = offsetProjected.$1 - screenCenter;
  return math.atan2(delta.dy, delta.dx);
}

/// What [area]'s own backdrop's `rotation` (see
/// [_SkyAreaBackdropPainter._paintOne]) would read as under [camera] —
/// reusing [_rotationAngleFor] itself rather than a separately hand-derived
/// formula, at an arbitrary unit probe size (the angle it returns doesn't
/// depend on zoom/screen size, only on direction). `sky_screen.dart`'s own
/// hold-to-straighten flight (see `_holdArea`) calls this — once with the
/// camera as it will be *before* any roll correction, once as the target 0
/// — to work out how much roll would land the image reading straight, the
/// same way it already straightens a constellation's own shape via
/// `cameraRollAngle` (constellation_field.dart) targeting a different
/// canonical reading. Meaningless for any camera not already looking
/// dead-center at [area]'s own supernova — every caller only ever uses
/// this after a pan-only [SkyCamera.rotatedToAlign] onto that exact
/// direction.
double areaBackdropRollReading(LifeArea area, SkyCamera camera) {
  final direction = supernovaDirection(area.index, LifeArea.values.length);
  final axisA = _axisAFor(direction);
  const probeSize = Size(1, 1);
  return _rotationAngleFor(
    direction,
    axisA,
    const Offset(0.5, 0.5),
    camera,
    1.0,
    probeSize,
  );
}

class _SkyAreaBackdropPainter extends CustomPainter {
  const _SkyAreaBackdropPainter({
    required this.images,
    required this.camera,
    required this.zoom,
  });

  final Map<LifeArea, ui.Image> images;
  final SkyCamera camera;
  final double zoom;

  // Well past the supernova's own light-ring (world radius 0.0405, see
  // sky_area_sigils.dart) but nowhere near the 0.42 first tried — that read
  // as far too large on screen. 0.1, then 0.2, both read a little small.
  static const _worldRadius = 0.15;

  // Additive blend already turns each image's black background invisible;
  // this on top of it is the "un po' trasparente" ask — a faint wash
  // rather than the image at full strength.
  static const _opacity = 0.5;

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
    final (center, scale) = projected;
    final diameter = _worldRadius * 2 * zoom * size.height * scale;

    // The same axis a real patch of sky would keep facing as the camera
    // moves around it — see [_axisAFor]'s own doc comment. Rotating the
    // whole image by this angle (rather than just drawing it screen-up) is
    // what makes it read as pinned to the sky at this area's own spot
    // instead of a flat billboard that stays upright no matter where the
    // camera looks.
    final axisA = _axisAFor(direction);
    final rotation = _rotationAngleFor(
      direction,
      axisA,
      center,
      camera,
      zoom,
      size,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

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
        ..blendMode = BlendMode.plus
        ..color = const Color.fromRGBO(255, 255, 255, _opacity),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      localRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = kAreaHeroArtTint,
    );

    // A circular fade to fully transparent (not the usual vignette's fade
    // to black — additive blend already makes plain black invisible, so a
    // black vignette here would do nothing) — this is what actually erases
    // the image's own square corners rather than just dimming them, since
    // the gradient reaches transparent at [localRect]'s inscribed circle,
    // well inside where the corners sit.
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
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkyAreaBackdropPainter oldDelegate) =>
      !identical(oldDelegate.images, images) ||
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom;
}
