import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/star_kind.dart';

/// The colors the five [StarKind]s are drawn in — passed in as one object
/// rather than read from a static palette, since a [CustomPainter] has no
/// [BuildContext] of its own. See [AppColors] for what each one means; the
/// Sky tab overrides them with slightly warmer/brighter variants so a
/// constellation still reads from far away.
class StarPalette {
  const StarPalette({
    required this.lit,
    required this.core,
    required this.nascent,
    required this.unlit,
    required this.dead,
  });

  /// Gold — the shape's connecting lines and the tint of anything burning
  /// (a lit star, a pulsar on a day it's been kept).
  final Color lit;

  /// The small bright mark drawn on top of a glow, so a burning star still
  /// has a crisp point at its center instead of one soft blob.
  final Color core;

  /// Neutral white: a slot that exists but hasn't been given a meaning yet.
  final Color nascent;

  /// Blue, no light: an unlit star, and a pulsar whose rhythm is broken.
  final Color unlit;

  /// Dimmer blue: a dead star's spent husk.
  final Color dead;

  // Value equality, not identity: callers build a palette inline in their
  // own build() (it's derived from `context.colors`), so without this
  // [ConstellationPainter.shouldRepaint] would see a "new" palette on every
  // single rebuild and never be able to skip a repaint.
  @override
  bool operator ==(Object other) {
    return other is StarPalette &&
        other.lit == lit &&
        other.core == core &&
        other.nascent == nascent &&
        other.unlit == unlit &&
        other.dead == dead;
  }

  @override
  int get hashCode => Object.hash(lit, core, nascent, unlit, dead);
}

/// One star: which entity it represents, where it sits in the
/// constellation's normalized (0..1) coordinate space, its [kind], and
/// whether it's currently burning.
class ConstellationStar {
  const ConstellationStar({
    required this.entityId,
    required this.position,
    required this.kind,
    required this.lit,
    required this.label,
    this.slotSequence,
  });

  /// The [Star]/[Habit] this stands for. Always 0 for a
  /// [StarKind.nascent] star — there's no entity behind an empty slot yet,
  /// which is exactly what makes it nascent; [slotSequence] identifies it
  /// instead.
  final int entityId;

  final Offset position;
  final StarKind kind;

  /// Whether this star is currently giving light. Always true for
  /// [StarKind.lit], always false for [StarKind.unlit]/[StarKind.nascent]/
  /// [StarKind.dead], and the live "kept the rhythm?" answer for
  /// [StarKind.pulsar] — the one kind that flips between the gold and the
  /// no-light family day by day.
  final bool lit;

  /// The underlying [Star]/[Habit]'s own title — only actually drawn by
  /// the Sky tab (see `ConstellationFieldPainter`'s star-name labels);
  /// `ConstellationScreen`'s own single-project view doesn't use it, but
  /// every [ConstellationStar] carries it since both share the exact same
  /// `buildConstellationRenderStars`. Empty for a nascent star, which has
  /// no title to show yet.
  final String label;

  /// Which slot on the constellation's shape this occupies (1-based, see
  /// [Star.slotSequence]) — set for every star that sits on the shape,
  /// nascent ones included, and null only for a pulsar (scattered around
  /// the shape rather than part of it). Tapping a nascent star hands this
  /// straight to [StarRepository.add], so the new star lands on the exact
  /// slot that was tapped.
  final int? slotSequence;
}

/// Compiles `shaders/constellation_flare.frag` once — callers hold the
/// returned [ui.FragmentProgram] (not a [ui.FragmentShader]) and call
/// [ui.FragmentProgram.fragmentShader] fresh each time they actually draw
/// with it (see [ConstellationPainter._drawGlowAndSparkle]): a `.frag`
/// asset only needs compiling once, but each draw needs its *own* shader
/// instance so its uniforms (this group's star positions) can't be
/// overwritten by another draw's before the canvas actually gets
/// rasterized.
Future<ui.FragmentProgram> buildConstellationFlareProgram() {
  return ui.FragmentProgram.fromAsset('shaders/constellation_flare.frag');
}

class ConstellationPainter extends CustomPainter {
  const ConstellationPainter({
    required this.stars,
    required this.flareProgram,
    required this.revision,
    required this.palette,
    this.edges = const [],
    this.lineWidthScale = 1,
    this.lineAlpha = 0.35,
    this.sparkleScale = 1,
    this.glowScale = 1,
    this.time = 0,
  });

  final List<ConstellationStar> stars;

  /// See [buildConstellationFlareProgram] — the compiled
  /// `constellation_flare.frag` a lit star's flare is drawn with. Null
  /// (or a group with too many stars for a single shader pass — see
  /// [_drawGlowAndSparkle]'s own `kMaxFlareStars`) just skips the flare,
  /// leaving the star's identity icon on its own.
  final ui.FragmentProgram? flareProgram;

  /// Seconds, free-running — drives the flare's flicker (see
  /// [_drawGlowAndSparkle]) with the same 2-sine-product formula
  /// `nebula_particles.frag`'s own `flareStarLayer()` uses, so a lit star
  /// here pulses in sync with the same formula the background flare stars
  /// use rather than sitting static. Defaults to 0 (a fixed, non-animated
  /// flicker phase) so any caller that doesn't thread a real clock through
  /// still renders correctly, just without the pulse.
  final double time;

  /// One color per [StarKind] family — see [StarPalette].
  final StarPalette palette;

  /// Which pairs of [stars] (by [ConstellationStar.slotSequence] order —
  /// i.e. index into the shape's own slots, pulsars excluded) get a
  /// connecting line, built by `buildConstellationLayout`. Can branch (a
  /// figure's arms and legs, a teapot's handle) instead of being a single
  /// path or loop.
  ///
  /// Always drawn in full, from the constellation's very first frame: the
  /// shape exists as soon as it's created, its slots simply start out
  /// nascent (see [StarKind.nascent]) rather than absent, so there's no
  /// "enough stars yet?" threshold left to gate the lines on.
  final List<(int, int)> edges;

  /// Multiply the connecting-line stroke width/alpha and the star/glow
  /// sizes below — all default to 1/0.35 (i.e. no change from before this
  /// existed), leaving `ConstellationScreen`'s own single-project view
  /// untouched. Added for the Sky (see `ConstellationFieldPainter`),
  /// where constellations sit small and far away in a wide field of view —
  /// making the shape itself much bigger there turned out to look
  /// distorted near the screen edges, so instead these make the same
  /// small shape read clearly through bolder strokes/icons/glow.
  final double lineWidthScale;
  final double lineAlpha;
  final double sparkleScale;
  final double glowScale;

  /// Bumped by the caller whenever [stars] actually changes in a way that
  /// affects rendering (a star added/achieved/deleted/resurrected, a habit
  /// completed) — deliberately NOT a deep list comparison, so pan/zoom
  /// gesture frames never trigger a repaint. Since a star's [ConstellationStar.lit]
  /// can now flip without [stars.length] changing at all (an achieved goal,
  /// a tombstoned star, a habit's streak breaking), correctness here depends
  /// entirely on the caller bumping this — the painter has no cheap way to
  /// detect that change itself.
  final int revision;

  // Tuned against ConstellationScreen's own fixed 1000x1000 canvas — every
  // fixed-pixel size below (sparkle radius, glow sprite scale, line width)
  // is expressed relative to it via [_sizeScale], so this class draws
  // identically there (size is always exactly 1000) while actually
  // shrinking/growing with the Sky's zoom (where `size` is
  // `localSizePx`, which does vary — see ConstellationFieldPainter). Without
  // this, a star's glow stayed a fixed screen-pixel blob regardless of zoom
  // there, quickly looking wildly oversized on a zoomed-out constellation or
  // undersized on a zoomed-in one, while everything else about the shape
  // (star positions, via [_toCanvas]) scaled correctly.
  static const _referenceSize = 1000.0;
  static const _sparkleRadius = 5.5;
  static const _pulsarSparkleRadius = 3.5;

  /// Per-family opacity. An unlit star is dim but plainly *there* (it's a
  /// commitment you've made); a nascent one is fainter still (a slot, not
  /// yet a commitment); a dead one is the faintest, a husk you have to look
  /// for. All three sit well below a lit star's own full-brightness flare.
  static const _unlitAlpha = 0.75;
  static const _nascentAlpha = 0.4;
  static const _deadAlpha = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty) return;
    final sizeScale = size.width / _referenceSize;

    // Drawn unconditionally: a constellation's shape is its identity, and
    // it's fully there from the moment it's created — the slots along it
    // just start out nascent. [edges] index into the shape's own slots in
    // order, so the same ordering is rebuilt here (pulsars scatter around
    // the shape and are never part of it).
    if (edges.isNotEmpty) {
      final linePaint = Paint()
        ..color = palette.lit.withValues(alpha: lineAlpha)
        ..strokeWidth = 1.2 * sizeScale * lineWidthScale
        ..style = PaintingStyle.stroke;
      // Sitting on a slot is what makes a star part of the shape — not its
      // kind. A deleted pulsar is a dead star too, but it keeps its own
      // scattered spot and no slot, so it must never shift this indexing.
      final shapeStars =
          stars.where((s) => s.slotSequence != null).toList()
            ..sort((a, b) => a.slotSequence!.compareTo(b.slotSequence!));
      for (final (a, b) in edges) {
        if (a >= shapeStars.length || b >= shapeStars.length) continue;
        canvas.drawLine(
          _toCanvas(shapeStars[a].position, size),
          _toCanvas(shapeStars[b].position, size),
          linePaint,
        );
      }
    }

    final burning = stars.where((s) => s.kind == StarKind.lit).toList();
    final burningPulsars = stars
        .where((s) => s.kind == StarKind.pulsar && s.lit)
        .toList();
    final nascent = stars.where((s) => s.kind == StarKind.nascent).toList();
    final unlit = stars.where((s) => s.kind == StarKind.unlit).toList();
    final dead = stars.where((s) => s.kind == StarKind.dead).toList();
    final coldPulsars = stars
        .where((s) => s.kind == StarKind.pulsar && !s.lit)
        .toList();

    // A lit star and a kept pulsar burn with the same gold — they differ
    // only in size (a pulsar is the smaller, scattered kind) and in how
    // easily they go out again.
    _drawGlowAndSparkle(canvas, size, burning, flareRadius: size.width * 0.42);
    _drawGlowAndSparkle(
      canvas,
      size,
      burningPulsars,
      flareRadius: size.width * 0.42 * 0.55,
    );
    // A hollow ring, not a filled twinkle: nothing has been placed here
    // yet, so it reads as an outline waiting to be filled in.
    _drawSparkleOnly(
      canvas,
      size,
      nascent,
      color: palette.nascent.withValues(alpha: _nascentAlpha),
      radius: _sparkleRadius * sizeScale * sparkleScale,
      outlineOnly: true,
    );
    _drawSparkleOnly(
      canvas,
      size,
      unlit,
      color: palette.unlit.withValues(alpha: _unlitAlpha),
      radius: _sparkleRadius * sizeScale * sparkleScale,
    );
    _drawSparkleOnly(
      canvas,
      size,
      coldPulsars,
      color: palette.unlit.withValues(alpha: _unlitAlpha),
      radius: _pulsarSparkleRadius * sizeScale * sparkleScale,
    );
    _drawSparkleOnly(
      canvas,
      size,
      dead,
      color: palette.dead.withValues(alpha: _deadAlpha),
      radius: _sparkleRadius * sizeScale * sparkleScale,
      outlineOnly: true,
    );
  }

  // Comfortably above any real constellation's star count — must match
  // `constellation_flare.frag`'s own `kMaxStars` exactly (positions
  // beyond however many stars actually exist are padded with (-1, -1),
  // which the shader skips).
  static const _kMaxFlareStars = 24;

  void _drawGlowAndSparkle(
    Canvas canvas,
    Size size,
    List<ConstellationStar> group, {
    // A fraction of [size.width] (the caller always passes
    // size.width * someFraction), not of [_sparkleRadius] — that constant
    // is scaled for a small icon and, tied to
    // `kSkyConstellationAngularSpan`'s own tiny sky patch, comes out to a
    // fraction of a pixel at the Sky's typical zoom, nowhere near
    // big enough for a flare meant to read as one of the bright stars in
    // the sky. [size] itself (a constellation's own on-screen footprint —
    // `localSizePx` in the Sky, a fixed 1000 in `ConstellationScreen`)
    // scales with zoom the same way the bg's own flare stars do, so tying
    // this to it keeps the ratio between the two roughly constant across
    // zoom levels instead of needing a hand-tuned multiplier per case.
    required double flareRadius,
  }) {
    if (group.isEmpty) return;

    final program = flareProgram;
    if (program == null) return;

    // `constellation_flare.frag` — the exact same glow/spike/core math
    // `nebula_particles.frag`'s own `flareStarLayer()` computes per pixel
    // for the bg stars, just evaluated live against this group's actual
    // star positions instead of a procedural lattice (see that shader's
    // own doc comment for why this replaced two earlier, visibly weaker
    // attempts: a pre-baked sprite stamped via drawAtlas, then a
    // Canvas gradient+Path approximation). One shader pass covers every
    // star in [group] at once — cheaper than one draw call per star, and
    // avoids needing per-star canvas transforms (rotation is computed
    // inside the shader, from each star's own position hash).
    // [positions] are absolute canvas pixels (where to actually draw each
    // star) — these shift continuously as the camera pans/zooms, since
    // [size] itself (a constellation's own on-screen footprint) does.
    // [seeds] are each star's *normalized* 0..1 position within its own
    // constellation's local shape space instead — never affected by the
    // camera at all — used only to seed the shader's per-star hash
    // (flicker phase, rotation). Feeding that hash [positions] instead (an
    // earlier version did) meant its own input value drifted continuously
    // with the camera too, so every star's rotation angle jumped to a
    // essentially new random value on every single pan/zoom frame instead
    // of staying fixed between a star's own occasional flicker.
    final positions = Float32List(_kMaxFlareStars * 2);
    final seeds = Float32List(_kMaxFlareStars * 2);
    for (var i = 0; i < _kMaxFlareStars; i++) {
      if (i < group.length) {
        final center = _toCanvas(group[i].position, size);
        positions[i * 2] = center.dx;
        positions[i * 2 + 1] = center.dy;
        seeds[i * 2] = group[i].position.dx;
        seeds[i * 2 + 1] = group[i].position.dy;
      } else {
        positions[i * 2] = -1;
        positions[i * 2 + 1] = -1;
      }
    }

    // A fresh shader instance per draw, from the already-compiled
    // [program] (cheap — no recompilation) — not one shared instance
    // reused across draws, since this same [program] gets a new shader
    // for every group of every constellation, all within one frame, and
    // sharing a single instance would risk a later draw's `setFloat`
    // calls landing on an earlier draw's uniforms before the canvas is
    // actually rasterized.
    final shader = program.fragmentShader();
    shader.setFloat(0, time);
    shader.setFloat(1, flareRadius);
    for (var i = 0; i < positions.length; i++) {
      shader.setFloat(2 + i, positions[i]);
    }
    for (var i = 0; i < seeds.length; i++) {
      shader.setFloat(2 + positions.length + i, seeds[i]);
    }
    // BlendMode.plus, not the default srcOver — this is the actual
    // structural difference from the bg's own flare stars, not a tuning
    // knob: nebula_particles.frag never has a transparent pixel at all
    // (its main() always writes vec4(color, 1.0) — the flare stars are
    // just added straight into that one always-opaque color before the
    // single write), so real alpha-blend compositing never happens for
    // them. This shader, drawn as its own separate layer over the sky/
    // constellation content beneath it, *does* have to composite through
    // real alpha at its low-alpha edges — and whatever the exact mismatch
    // was (straight vs. premultiplied output, most likely), it kept
    // reading as a dark/rough edge no matter how the falloff curve itself
    // was retuned. Plus mode sidesteps the question entirely: it just
    // adds this shader's (already alpha-weighted) color onto whatever's
    // beneath, the same "pure addition into something already there"
    // relationship the bg stars have with their own nebula backdrop —
    // nothing for a blend-mode mismatch to darken.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawSparkleOnly(
    Canvas canvas,
    Size size,
    List<ConstellationStar> group, {
    required Color color,
    required double radius,
    bool outlineOnly = false,
  }) {
    if (group.isEmpty) return;
    final sparkle = sparklePath(radius);
    final paint = outlineOnly
        ? (Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1)
        : (Paint()..color = color);
    for (final star in group) {
      final center = _toCanvas(star.position, size);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawPath(sparkle, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) {
    return revision != oldDelegate.revision ||
        flareProgram != oldDelegate.flareProgram ||
        palette != oldDelegate.palette ||
        stars.length != oldDelegate.stars.length ||
        time != oldDelegate.time;
  }
}

/// A small four-pointed "twinkle" sparkle (like ✦), pinched to a narrow
/// waist at the center — reads clearly at star size, unlike a filled
/// diamond or a rounder shape which just blurs into a dot. Public because
/// `nightlight_starfield.dart` and `nightlight_star_glow.dart` reuse the same
/// shape for their own white, non-constellation stars.
Path sparklePath(double radius) {
  final waist = radius * 0.28;
  return Path()
    ..moveTo(0, -radius)
    ..quadraticBezierTo(waist, -waist, radius, 0)
    ..quadraticBezierTo(waist, waist, 0, radius)
    ..quadraticBezierTo(-waist, waist, -radius, 0)
    ..quadraticBezierTo(-waist, -waist, 0, -radius)
    ..close();
}

Offset _toCanvas(Offset normalized, Size size) {
  return Offset(normalized.dx * size.width, normalized.dy * size.height);
}

/// Finds the star nearest a tap, within [hitRadius] logical pixels, in the
/// same normalized-to-canvas coordinate space [ConstellationPainter] paints
/// in. Works regardless of [ConstellationStar.kind]/[ConstellationStar.lit] —
/// every kind opens something useful when tapped: a nascent star opens the
/// form that configures it, a dead one the flow that reignites it, an unlit
/// one "light this star", and a lit one simply itself.
ConstellationStar? hitTestStar(
  Offset localPosition,
  Size canvasSize,
  List<ConstellationStar> stars, {
  double hitRadius = 24,
}) {
  ConstellationStar? closest;
  var closestDistanceSq = hitRadius * hitRadius;
  for (final star in stars) {
    final distanceSq =
        (_toCanvas(star.position, canvasSize) - localPosition).distanceSquared;
    if (distanceSq < closestDistanceSq) {
      closestDistanceSq = distanceSq;
      closest = star;
    }
  }
  return closest;
}

/// The bounding box of a set of normalized points, used to frame a
/// constellation's initial pan/zoom view and to size its min/max scale.
Rect boundingBoxOf(List<Offset> points) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
