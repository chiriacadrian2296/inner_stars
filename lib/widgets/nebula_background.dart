import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../models/galaxy_quality.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import 'constellation_field.dart';
import 'sky_clock.dart';

/// A fullscreen animated nebula/starfield, rendered entirely on the GPU by
/// `shaders/nebula_particles.frag` — no image assets, no 3D engine, just a
/// procedural fragment shader repainted every frame. Purely presentational:
/// [camera]/[zoom] are owned by the caller (see `NebulaScreen`), which also
/// drives a scattered field of constellations over the same camera — both
/// need to move together, so there's one shared source of truth for the
/// gesture rather than this widget tracking its own.
///
/// The clouds (the gas, the supernovas' light on it, the dust) are by far
/// the heaviest part of the sky and drift very slowly, so while the camera
/// stands still they're not recomputed every frame: a snapshot of them is
/// taken a few times a second and the two latest are crossfaded, with the
/// stars and everything else still computed fresh on top every frame. The
/// dust doesn't drift at all, so its darkness is snapshotted once. While
/// the camera moves, the whole sky is computed live, as before. Both paths
/// draw the same picture (see the shader's own notes on its dither).
///
/// In the lighter [quality] modes the clouds are always taken from
/// snapshots drawn at a fraction of the screen's resolution (and smoothly
/// stretched over it) — every frame while the camera moves.
class NebulaBackground extends StatefulWidget {
  const NebulaBackground({
    super.key,
    required this.camera,
    required this.zoom,
    required this.clock,
    this.quality = GalaxyQuality.quality,
    this.showGrid = false,
    this.supernovaLight = 0,
    this.supernovaLevels = const [0, 0, 0, 0, 0, 0, 0, 0],
  });

  /// Drives the shader's animation — see [SkyClock].
  final SkyClock clock;
  final SkyCamera camera;
  final double zoom;

  /// How much the sky may spend — see [GalaxyQuality].
  final GalaxyQuality quality;

  /// Debug aid: overlays meridian/parallel lines on the sky sphere so
  /// pole proximity and field of view can be gauged by eye — see
  /// `NebulaScreen`'s own toggle for this.
  final bool showGrid;

  /// How strongly the supernovas light the nebula around them (0 for not
  /// at all — e.g. while they are hidden).
  final double supernovaLight;

  /// Each area's intensity level (see `supernovaIntensityLevel`), in
  /// [LifeArea] order: the higher, the wider and warmer its supernova's
  /// light on the gas.
  final List<double> supernovaLevels;

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

/// The shader's `uMode` values.
const double _kModeLive = 0;
const double _kModeClouds = 1;
const double _kModeComposite = 2;
const double _kModeDarkness = 3;
const double _kModeStars = 4;

/// How often the cloud snapshot is retaken while the camera stands still.
/// The two latest are crossfaded over this same interval, so the clouds'
/// drift stays smooth.
const double _kCloudInterval = 0.15;

/// Each cloud snapshot is drawn a band at a time over this many ticks, so
/// no single frame pays for the whole of it.
const int _kCloudBands = 4;

/// The cloud snapshots and what they were taken for. Read by the painter at
/// paint time, written by the state on clock ticks.
class _CloudCache {
  ui.Image? cloudsA;
  ui.Image? cloudsB;
  ui.Image? darkness;

  /// When [cloudsB] was taken (clock seconds).
  double takenAt = 0;

  /// The next cloud snapshot while it's being drawn, [pendingBands] of
  /// its bands so far, all at [pendingTime].
  ui.Image? pending;
  int pendingBands = 0;
  double pendingTime = 0;

  /// The stars snapshots, taken alongside the clouds' when [starDepth]
  /// asks for them (see the shader's `uStarDepth`).
  ui.Image? starsA;
  ui.Image? starsB;
  ui.Image? pendingStars;

  /// What the snapshots show: the camera and the light settings.
  SkyCamera? camera;
  double zoom = 0;
  Size size = Size.zero;
  double pixelRatio = 1;
  double cloudScale = 1;
  int starDepth = 0;
  double supernovaLight = 0;
  List<double> supernovaLevels = const [];

  /// The size and pixel ratio of the last paint — the snapshots match it.
  Size paintSize = Size.zero;
  double paintPixelRatio = 1;

  bool matches(NebulaBackground widget) =>
      cloudsB != null &&
      darkness != null &&
      identical(camera, widget.camera) &&
      zoom == widget.zoom &&
      size == paintSize &&
      pixelRatio == paintPixelRatio &&
      cloudScale == widget.quality.cloudScale &&
      starDepth == widget.quality.starDepth &&
      supernovaLight == widget.supernovaLight &&
      listEquals(supernovaLevels, widget.supernovaLevels);

  void clear() {
    cloudsA?.dispose();
    if (!identical(cloudsA, cloudsB)) cloudsB?.dispose();
    darkness?.dispose();
    pending?.dispose();
    starsA?.dispose();
    if (!identical(starsA, starsB)) starsB?.dispose();
    pendingStars?.dispose();
    starsA = null;
    starsB = null;
    pendingStars = null;
    pending = null;
    pendingBands = 0;
    cloudsA = null;
    cloudsB = null;
    darkness = null;
    camera = null;
  }
}

class _NebulaBackgroundState extends State<NebulaBackground> {
  _SkyShaders? _fullShaders;
  _SkyShaders? _liteShaders;

  /// Stands in for the snapshots while the sky is drawn live (every
  /// sampler must hold some image).
  ui.Image? _blank;
  final _cache = _CloudCache();

  /// The camera at the previous clock tick: the snapshots are only taken
  /// once it has stood still for a tick.
  SkyCamera? _lastCamera;
  double _lastZoom = 0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    widget.clock.addListener(_onTick);
  }

  @override
  void didUpdateWidget(NebulaBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.clock, widget.clock)) {
      oldWidget.clock.removeListener(_onTick);
      widget.clock.addListener(_onTick);
    }
  }

  Future<void> _loadShader() async {
    final (full, lite) = await (
      ui.FragmentProgram.fromAsset('shaders/nebula_particles.frag'),
      ui.FragmentProgram.fromAsset('shaders/nebula_particles_lite.frag'),
    ).wait;
    if (!mounted) return;
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = Colors.black);
    final picture = recorder.endRecording();
    _blank = picture.toImageSync(1, 1);
    picture.dispose();
    setState(() {
      _fullShaders = _SkyShaders(full);
      _liteShaders = _SkyShaders(lite);
    });
  }

  /// Takes the snapshots the painter needs when the camera has stood still
  /// since the last tick: the darkness and a first cloud snapshot for a new
  /// view, then a fresh cloud snapshot every [_kCloudInterval], drawn a
  /// band per tick in the meantime.
  void _onTick() {
    final shader = _fullShaders?.snapshot;
    final starsShader = _liteShaders?.snapshot;
    final blank = _blank;
    final steady =
        identical(_lastCamera, widget.camera) && _lastZoom == widget.zoom;
    _lastCamera = widget.camera;
    _lastZoom = widget.zoom;
    if (shader == null || starsShader == null || blank == null || !steady) {
      return;
    }
    final cache = _cache;
    final size = cache.paintSize;
    if (size.isEmpty) return;
    final now = widget.clock.seconds;

    if (!cache.matches(widget)) {
      _snapshotView();
      return;
    }
    if (cache.pendingBands < _kCloudBands) {
      if (cache.pendingBands == 0) cache.pendingTime = now;
      final previous = cache.pending;
      cache.pending = _snapshot(
        shader,
        blank,
        _kModeClouds,
        cache.pendingTime,
        band: cache.pendingBands,
        below: previous,
      );
      previous?.dispose();
      if (cache.starDepth > 0) {
        final previousStars = cache.pendingStars;
        cache.pendingStars = _snapshot(
          starsShader,
          blank,
          _kModeStars,
          cache.pendingTime,
          scale: 1,
          band: cache.pendingBands,
          below: previousStars,
        );
        previousStars?.dispose();
      }
      cache.pendingBands++;
    } else if (now - cache.takenAt >= _kCloudInterval) {
      if (!identical(cache.cloudsA, cache.cloudsB)) cache.cloudsA?.dispose();
      cache.cloudsA = cache.cloudsB;
      cache.cloudsB = cache.pending;
      final stars = cache.pendingStars;
      if (stars != null) {
        if (!identical(cache.starsA, cache.starsB)) cache.starsA?.dispose();
        // The very first stars snapshot stands in for both.
        cache.starsA = cache.starsB ?? stars;
        cache.starsB = stars;
      }
      cache.takenAt = now;
      cache.pending = null;
      cache.pendingStars = null;
      cache.pendingBands = 0;
    }
  }

  /// Starts the snapshots over for the current view: its darkness and a
  /// first cloud snapshot, both at once. Returns whether it could.
  bool _snapshotView() {
    final shader = _fullShaders?.snapshot;
    final blank = _blank;
    final cache = _cache;
    if (shader == null || blank == null || cache.paintSize.isEmpty) {
      return false;
    }
    final now = widget.clock.seconds;
    cache.clear();
    cache
      ..camera = widget.camera
      ..zoom = widget.zoom
      ..size = cache.paintSize
      ..pixelRatio = cache.paintPixelRatio
      ..cloudScale = widget.quality.cloudScale
      ..starDepth = widget.quality.starDepth
      ..supernovaLight = widget.supernovaLight
      ..supernovaLevels = List.of(widget.supernovaLevels);
    cache.darkness = _snapshot(shader, blank, _kModeDarkness, now);
    cache.cloudsB = _snapshot(shader, blank, _kModeClouds, now);
    cache.cloudsA = cache.cloudsB;
    cache.takenAt = now;
    return true;
  }

  /// Renders the shader in [mode] for the current view into an image of
  /// the screen's pixels — or the fraction of them [scale] asks for (by
  /// default the clouds' own) — or, given a [band], just that band of it
  /// over the image [below].
  ui.Image _snapshot(
    ui.FragmentShader shader,
    ui.Image blank,
    double mode,
    double time, {
    double? scale,
    int? band,
    ui.Image? below,
  }) {
    final cache = _cache;
    final size = cache.paintSize;
    final ratio = cache.paintPixelRatio * (scale ?? cache.cloudScale);
    _setUniforms(
      shader,
      size: size,
      time: time,
      camera: widget.camera,
      zoom: widget.zoom,
      showGrid: false,
      supernovaLight: widget.supernovaLight,
      supernovaLevels: widget.supernovaLevels,
      mode: mode,
      blend: 0,
      starDepth: cache.starDepth.toDouble(),
      cloudsA: blank,
      cloudsB: blank,
      darkness: blank,
      starsA: blank,
      starsB: blank,
      lite: mode == _kModeStars,
    );
    final recorder = ui.PictureRecorder();
    final width = (size.width * ratio).ceil();
    final height = (size.height * ratio).ceil();
    final canvas = Canvas(recorder);
    if (below != null) canvas.drawImage(below, Offset.zero, Paint());
    if (band != null) {
      // Whole device pixels, so the bands meet without a seam.
      final top = (height * band / _kCloudBands).floorToDouble();
      final bottom = (height * (band + 1) / _kCloudBands).floorToDouble();
      canvas.clipRect(
        Rect.fromLTRB(0, top, width.toDouble(), bottom),
        doAntiAlias: false,
      );
    }
    canvas
      ..scale(ratio)
      ..drawRect(Offset.zero & size, Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onTick);
    _cache.clear();
    _blank?.dispose();
    _fullShaders?.dispose();
    _liteShaders?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final full = _fullShaders;
    final lite = _liteShaders;
    final blank = _blank;
    if (full == null || lite == null || blank == null) {
      // Plain fallback while the shader compiles/loads — a flash of the
      // wrong color would be more jarring than a beat of solid night.
      return ColoredBox(color: colors.night);
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _NebulaPainter(
        full: full.paint,
        lite: lite.paint,
        blank: blank,
        cache: _cache,
        snapshotView: _snapshotView,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        background: widget,
      ),
    );
  }
}

void _setUniforms(
  ui.FragmentShader shader, {
  required Size size,
  required double time,
  required SkyCamera camera,
  required double zoom,
  required bool showGrid,
  required double supernovaLight,
  required List<double> supernovaLevels,
  required double mode,
  required double blend,
  required ui.Image cloudsA,
  required ui.Image cloudsB,
  required ui.Image darkness,
  required double starDepth,
  required ui.Image starsA,
  required ui.Image starsB,
  required bool lite,
  FilterQuality filterQuality = FilterQuality.none,
}) {
  shader
    ..setFloat(0, size.width)
    ..setFloat(1, size.height)
    ..setFloat(2, time)
    ..setFloat(3, camera.forward.$1)
    ..setFloat(4, camera.forward.$2)
    ..setFloat(5, camera.forward.$3)
    ..setFloat(6, camera.right.$1)
    ..setFloat(7, camera.right.$2)
    ..setFloat(8, camera.right.$3)
    ..setFloat(9, camera.up.$1)
    ..setFloat(10, camera.up.$2)
    ..setFloat(11, camera.up.$3)
    ..setFloat(12, zoom)
    ..setFloat(13, showGrid ? 1.0 : 0.0)
    ..setFloat(14, supernovaLight);
  // Where each area's supernova sits, so the nebula can glow around it.
  for (var i = 0; i < LifeArea.values.length; i++) {
    final (x, y, z) = supernovaVisualDirection(LifeArea.values[i]);
    shader
      ..setFloat(15 + i * 3, x)
      ..setFloat(16 + i * 3, y)
      ..setFloat(17 + i * 3, z);
  }
  for (var i = 0; i < 8; i++) {
    shader.setFloat(
      39 + i,
      i < supernovaLevels.length ? supernovaLevels[i] : 0,
    );
  }
  shader
    ..setFloat(47, mode)
    ..setFloat(48, blend)
    ..setImageSampler(0, cloudsA, filterQuality: filterQuality)
    ..setImageSampler(1, cloudsB, filterQuality: filterQuality)
    ..setImageSampler(2, darkness, filterQuality: filterQuality);
  // Only the lighter modes' shader has the stars snapshots.
  if (lite) {
    shader
      ..setFloat(49, starDepth)
      // Full resolution, one texel per pixel: no filtering needed.
      ..setImageSampler(3, starsA)
      ..setImageSampler(4, starsB);
  }
}

/// One of the sky's two compiled shaders (see `nebula_particles.glsl`):
/// one instance to paint the screen with and one to take the snapshots.
class _SkyShaders {
  _SkyShaders(ui.FragmentProgram program)
    : paint = program.fragmentShader(),
      snapshot = program.fragmentShader();

  final ui.FragmentShader paint;
  final ui.FragmentShader snapshot;

  void dispose() {
    paint.dispose();
    snapshot.dispose();
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.full,
    required this.lite,
    required this.blank,
    required this.cache,
    required this.snapshotView,
    required this.pixelRatio,
    required this.background,
  }) : super(repaint: background.clock);

  /// The full sky's shader and the lighter modes' one (see
  /// [_SkyShaders]): the latter only while it has stars snapshots to show.
  final ui.FragmentShader full;
  final ui.FragmentShader lite;
  final ui.Image blank;
  final _CloudCache cache;

  /// Retakes the snapshots for the current view — see
  /// `_NebulaBackgroundState._snapshotView`.
  final bool Function() snapshotView;
  final double pixelRatio;
  final NebulaBackground background;

  @override
  void paint(Canvas canvas, Size size) {
    cache
      ..paintSize = size
      ..paintPixelRatio = pixelRatio;
    final now = background.clock.seconds;
    final reduced = background.quality.cloudScale < 1;
    // The lighter modes never compute the clouds live: a moving camera gets
    // fresh low-resolution snapshots every frame instead.
    final cached = cache.matches(background) || (reduced && snapshotView());
    final starsCached = cached && cache.starsB != null;
    final shader = starsCached ? lite : full;
    _setUniforms(
      shader,
      size: size,
      time: now,
      camera: background.camera,
      zoom: background.zoom,
      showGrid: background.showGrid,
      supernovaLight: background.supernovaLight,
      supernovaLevels: background.supernovaLevels,
      mode: cached ? _kModeComposite : _kModeLive,
      blend: cached
          ? ((now - cache.takenAt) / _kCloudInterval).clamp(0.0, 1.0)
          : 0,
      cloudsA: cached ? cache.cloudsA! : blank,
      cloudsB: cached ? cache.cloudsB! : blank,
      darkness: cached ? cache.darkness! : blank,
      // Until the first stars snapshot is done they're drawn live.
      starDepth: starsCached ? cache.starDepth.toDouble() : 0,
      starsA: starsCached ? cache.starsA! : blank,
      starsB: starsCached ? cache.starsB! : blank,
      lite: starsCached,
      filterQuality: reduced ? FilterQuality.low : FilterQuality.none,
    );
    // Screen (rather than the plain opaque fill this always used to be) —
    // a 2026-09-19 test: SkyAreaBackdrop was moved to sit *behind* this
    // layer in NebulaScreen's own Stack, to see whether it reads as more
    // blended with the sky's own stars/nebula that way instead of sitting
    // on top of them. This shader always outputs alpha 1.0 (fully opaque)
    // for every pixel — normal `BlendMode.srcOver` would have painted
    // straight over whatever SkyAreaBackdrop drew underneath it,
    // completely hiding it, so some non-opaque blend is required for that
    // to show at all. Screen (`1 - (1-src)*(1-dst)`) rather than
    // `BlendMode.plus` (`src+dst`, tried first): both let light through,
    // but plus clips straight to white the moment two bright layers
    // overlap, while screen's multiplicative falloff keeps bright-on-bright
    // areas glowing rather than blowing out — asked for explicitly, "un
    // blending mode che da più influenza alla luce" than the flat-clipping
    // additive did. Since this is normally the very first thing painted
    // (nothing behind it to begin with, most of the time), switching its
    // blend mode changes nothing about its own everyday look.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      !identical(oldDelegate.background.camera, background.camera) ||
      oldDelegate.background.zoom != background.zoom ||
      oldDelegate.background.showGrid != background.showGrid ||
      oldDelegate.background.supernovaLight != background.supernovaLight ||
      !listEquals(
        oldDelegate.background.supernovaLevels,
        background.supernovaLevels,
      ) ||
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.background.quality != background.quality;
}
