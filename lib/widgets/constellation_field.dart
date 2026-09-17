import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/constellation_shape.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'constellation_painter.dart';

/// One project's constellation, already built (see
/// `buildConstellationRenderStars`) and given a stable spot in the shared
/// pannable/zoomable world the Sky scatters every constellation
/// across.
class PlacedConstellation {
  const PlacedConstellation({
    required this.project,
    required this.shape,
    required this.worldPosition,
    required this.stars,
    required this.habits,
    required this.renderStars,
    required this.edges,
  });

  final Project project;
  final ConstellationShape? shape;

  /// Center of this constellation's own local unit square, in world-space
  /// units (see [worldToScreen]) — stable across sessions as long as
  /// [index] (the value this was built from, via [constellationWorldPosition])
  /// doesn't change, which it won't for an existing project since newer
  /// ones are always appended after it.
  final Offset worldPosition;

  /// Project-scoped, kept alongside [renderStars] so tapping a star can
  /// look its full [Star]/[Habit] back up by id without needing to search
  /// every other constellation's list too.
  final List<Star> stars;
  final List<Habit> habits;

  final List<ConstellationStar> renderStars;
  final List<(int, int)> edges;
}

/// The Sky's world is a sky sphere — the camera (see [SkyCamera])
/// sits at its center, like a viewer inside an HDRI environment map.
/// Content (a constellation's spot in the sky) is still placed with a
/// fixed (azimuth, elevation) pair in turns — [Offset.dx]/[Offset.dy] —
/// since content never rotates and a stable, world-referenced coordinate
/// is exactly what it needs; only the *camera* uses a full free
/// orientation with no such reference (see [SkyCamera] for why).
///
/// [PlacedConstellation.worldPosition] can land anywhere on that sphere,
/// including near one of *this* fixed coordinate system's own poles (the
/// camera has none, but content still does) — see [constellationWorldPosition]
/// for why that's safe here: it never offsets a pole-adjacent position by
/// azimuth/elevation directly, only ever by a 3D geodesic step, which has
/// no singularity there.

/// How much of the sky sphere one constellation's own local 0..1 space
/// covers, in radians — independent of [zoom], so shrinking this is what
/// makes every constellation read as one small patch of a much bigger sky
/// instead of ballooning to fill the screen at any zoom level. Tried much
/// larger (0.8) first to make constellations easier to spot in the
/// now-farther-feeling sky, but a shape that big started looking visibly
/// distorted near the edges of a wide field of view (the flat-patch
/// approximation this class draws each constellation as breaks down at
/// that size) — kept small instead, and made findable through
/// `ConstellationFieldPainter`'s own bolder line/icon/glow sizing instead
/// of through sheer size. Shrunk again since (was 0.15) so constellations
/// read as sitting farther out in the sky rather than parked right up
/// close — everything about how big one renders (line width, sparkle
/// size, glow sprite scale) is already proportional to this, via
/// `_projectConstellationTransform`'s own `localSizePx`, so lowering it
/// alone is enough to push the whole shape farther away without also
/// having to retune those multipliers by hand.
const double kSkyConstellationAngularSpan = 0.10;

/// The direction (as a raw unit vector) of the [index]-th of [count] evenly
/// spread points on the sky sphere — a Fibonacci/golden-angle spiral, the
/// same formula `sky_supernova.frag` independently reimplements in GLSL for
/// the glow itself (a shader has no way to share Dart code, so that copy is
/// kept in sync with this one by hand) and [SkySupernova]'s own icon
/// painter uses this exact function for, so every icon lands squarely on
/// the star the shader already drew. [areaWorldPosition] below is what lets
/// [constellationWorldPosition] place a project's constellation around its
/// own [LifeArea]'s star using this same layout.
(double x, double y, double z) supernovaDirection(int index, int count) {
  final goldenAngle = math.pi * (3.0 - math.sqrt(5.0));
  final y = 1.0 - (index / (count - 1)) * 2.0;
  final radius = math.sqrt(math.max(0.0, 1.0 - y * y));
  final theta = goldenAngle * index;
  return (math.cos(theta) * radius, y, math.sin(theta) * radius);
}

/// Where [area]'s own supernova sits on the sky sphere, in the same
/// (azimuthTurns, elevationTurns) space every other piece of sky content
/// uses — the inverse of [_directionOn] applied to [supernovaDirection],
/// since [LifeArea] fixes both the index (its own [LifeArea.index]) and the
/// total count ([LifeArea.values.length], matching `kSupernovaCount` in
/// `sky_supernova.dart`) that formula needs.
Offset areaWorldPosition(LifeArea area) {
  final (x, y, z) = supernovaDirection(area.index, LifeArea.values.length);
  final elevationTurns = math.asin(y.clamp(-1.0, 1.0)) / _twoPi;
  final azimuthTurns = math.atan2(z, x) / _twoPi;
  return Offset(azimuthTurns, elevationTurns);
}

/// How far (in radians of true angular separation on the sky sphere) a
/// project's constellation must clear its own life area's supernova by —
/// bigger than the supernova's own visible glow (its bright core/ring/spike
/// reach dies off well before this — see `sky_supernova.frag`'s `supernova`
/// function), so no constellation ever reads as parked on top of the light
/// itself. Also reused as the minimum gap kept between any two same-area
/// constellations' own centers (see [constellationWorldPosition]) — one
/// spacing value doing both jobs, since "far enough from the supernova" and
/// "far enough from a sibling constellation" are the same kind of
/// requirement here. The closest any two of the 8 supernovas ever get to
/// each other (computed offline from [supernovaDirection]) is about 0.775
/// radians (44.4°); this spacing is small enough that several rings' worth
/// of same-area constellations still fit well inside half that before
/// risking a neighboring area's own safe zone.
const double _kAreaConstellationSpacing = 0.18;

/// The golden angle, in radians — see [constellationWorldPosition]'s own
/// per-ring stagger for why.
const double _kGoldenAngle = 2.399963229728653;

/// Where the [indexInArea]-th constellation belonging to [area] (by stable
/// creation order *within that area* — see `NebulaScreen._loadData`) sits
/// on the sky sphere: packed into concentric rings around [area]'s own
/// supernova, starting [_kAreaConstellationSpacing] out (the safe zone) and
/// stepping outward by that same spacing ring by ring, rather than a free
/// scatter — a Kronecker/golden-angle scatter (tried first) spreads points
/// evenly *on average* but has no guaranteed minimum distance between any
/// two of them, so two same-area projects could still land close enough to
/// visibly overlap. Packing rings instead gives that guarantee outright:
/// each ring only ever holds as many evenly-spaced slots as fit at its own
/// radius without any two neighbors on it closer than
/// [_kAreaConstellationSpacing] (`slotsInRing` below), so every placement
/// this returns is at least that far from every other one, in the same
/// area or the ring in or out from it. Successive rings are staggered by
/// the golden angle rather than all starting at angle 0, so filled rings
/// don't line up into visible spokes radiating from the supernova.
///
/// Deterministic and index-within-area-only (not id-based), so an existing
/// project's spot never moves as more are added, whether to its own area or
/// another one — indices fill ring 0 first, then ring 1, and so on, so a
/// later addition only ever extends the pattern outward.
///
/// Built directly in 3D (around [area]'s own direction vector, using the
/// same canonical tangent-frame trick [_projectConstellationTransform]
/// uses) rather than by offsetting azimuth/elevation directly, since a flat
/// offset in that 2D space distorts however close [area]'s own star sits to
/// a pole — a 3D geodesic offset reads as a uniform ring around the star
/// regardless of where on the sphere it is.
Offset constellationWorldPosition(LifeArea area, int indexInArea) {
  final center = areaWorldPosition(area);

  // Finds which ring [indexInArea] falls into by filling each ring's own
  // slots (as many as fit its circumference at [_kAreaConstellationSpacing]
  // apart) before spilling into the next one outward.
  var remaining = indexInArea;
  var ring = 0;
  var radius = _kAreaConstellationSpacing;
  var slotsInRing = math.max(
    1,
    (_twoPi * radius / _kAreaConstellationSpacing).floor(),
  );
  while (remaining >= slotsInRing) {
    remaining -= slotsInRing;
    ring++;
    radius = _kAreaConstellationSpacing * (ring + 1);
    slotsInRing = math.max(
      1,
      (_twoPi * radius / _kAreaConstellationSpacing).floor(),
    );
  }
  final angle = (remaining / slotsInRing) * _twoPi + ring * _kGoldenAngle;

  return offsetWorldPosition(center, radius, angle);
}

/// A point [radiusRadians] from [center] (true angular distance along the
/// sky sphere's own great circle), toward [angleRadians] — the same 3D
/// geodesic step [constellationWorldPosition]'s own per-ring stagger uses,
/// pulled out standalone so a caller that needs a single fixed offset (not
/// a whole packed ring of them) doesn't have to duplicate the tangent-frame
/// math. See [constellationWorldPosition] for why this is done in 3D
/// rather than by offsetting azimuth/elevation directly.
Offset offsetWorldPosition(Offset center, double radiusRadians, double angleRadians) {
  final centerDir = _directionOn(center.dx, center.dy);
  final azimuth = center.dx * _twoPi;
  final canonicalRight = (-math.sin(azimuth), 0.0, math.cos(azimuth));
  final canonicalUp = _cross(canonicalRight, centerDir);

  final offsetAxis = _normalized(
    _add(
      _scaled(canonicalRight, math.cos(angleRadians)),
      _scaled(canonicalUp, math.sin(angleRadians)),
    ),
  );
  // centerDir and offsetAxis are already perpendicular unit vectors, so
  // this is exactly the point [radiusRadians] from centerDir along the
  // great circle toward offsetAxis — no explicit rotation axis/matrix
  // needed (see [SkyCamera.rolled] for the general Rodrigues version of
  // the same idea).
  final scattered = _add(
    _scaled(centerDir, math.cos(radiusRadians)),
    _scaled(offsetAxis, math.sin(radiusRadians)),
  );

  final elevationTurns = math.asin(scattered.$2.clamp(-1.0, 1.0)) / _twoPi;
  final azimuthTurns = math.atan2(scattered.$3, scattered.$1) / _twoPi;
  return Offset(azimuthTurns, elevationTurns);
}

/// A fixed point near [area]'s own supernova that no real constellation can
/// ever land on: every real ring [constellationWorldPosition] packs sits at
/// a radius that's a whole multiple of [_kAreaConstellationSpacing] from
/// the center, and this sits deliberately between the first two rings.
/// Used by the sky-navigation tutorial for its own placeholder "house"
/// constellation, which never touches the project/star repositories and
/// therefore has no real `indexInArea` of its own.
Offset tutorialDemoWorldPosition(LifeArea area) => offsetWorldPosition(
  areaWorldPosition(area),
  _kAreaConstellationSpacing * 1.5,
  0,
);

/// The true angular separation (radians, along the sky sphere's own great
/// circle) between two world positions — what `NebulaScreen`'s "take me
/// there" zoom-to-fit needs to measure how far a supernova's farthest
/// constellation sits from it, since plain [Offset] arithmetic on
/// (azimuth, elevation) pairs doesn't mean actual sky distance (it breaks
/// down near a pole the same way any 2-angle parameterization does — see
/// [SkyCamera]'s own doc comment on why).
double angularDistanceBetween(Offset a, Offset b) {
  final directionA = _directionOn(a.dx, a.dy);
  final directionB = _directionOn(b.dx, b.dy);
  return math.acos(_dot(directionA, directionB).clamp(-1.0, 1.0));
}

const double _twoPi = 2 * math.pi;

/// A plain (x, y, z) vector — deliberately not a class: every use below is
/// short-lived (built, dotted/crossed/rotated a few times, then either
/// discarded or folded into a [SkyCamera]), so a record avoids the
/// ceremony of a whole vector-math type for that. Structural, not
/// nominal, so it never causes a "private type in public API" problem
/// even where it flows out through [SkyCamera]'s own public fields.
typedef _Vec3 = (double x, double y, double z);

double _dot(_Vec3 a, _Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

_Vec3 _cross(_Vec3 a, _Vec3 b) => (
  a.$2 * b.$3 - a.$3 * b.$2,
  a.$3 * b.$1 - a.$1 * b.$3,
  a.$1 * b.$2 - a.$2 * b.$1,
);

_Vec3 _scaled(_Vec3 v, double s) => (v.$1 * s, v.$2 * s, v.$3 * s);

_Vec3 _minus(_Vec3 a, _Vec3 b) => (a.$1 - b.$1, a.$2 - b.$2, a.$3 - b.$3);

_Vec3 _add(_Vec3 a, _Vec3 b) => (a.$1 + b.$1, a.$2 + b.$2, a.$3 + b.$3);

_Vec3 _normalized(_Vec3 v) {
  final length = math.sqrt(_dot(v, v));
  return (v.$1 / length, v.$2 / length, v.$3 / length);
}

/// Rotates [v] by [angle] radians around [axis] (must already be unit
/// length) via Rodrigues' rotation formula — the one piece of vector math
/// [SkyCamera] actually needs, since rotating around an arbitrary
/// (camera-relative, not world-fixed) axis is what lets it turn freely
/// with no poles.
_Vec3 _rotateAroundAxis(_Vec3 v, _Vec3 axis, double angle) {
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final crossAV = _cross(axis, v);
  final axisDotV = _dot(axis, v);
  return (
    v.$1 * cosA + crossAV.$1 * sinA + axis.$1 * axisDotV * (1 - cosA),
    v.$2 * cosA + crossAV.$2 * sinA + axis.$2 * axisDotV * (1 - cosA),
    v.$3 * cosA + crossAV.$3 * sinA + axis.$3 * axisDotV * (1 - cosA),
  );
}

/// The point on the unit sky sphere at [azimuthTurns]/[elevationTurns] —
/// y is "up", matching the nebula shader's own spherical-to-Cartesian
/// convention exactly, so a constellation's rendered position and the
/// animated background it sits over always agree. Only ever used for
/// fixed *content* (a constellation's spot) and once, to seed a
/// [SkyCamera]'s starting orientation — the camera itself never touches
/// azimuth/elevation again after that, only relative rotations.
_Vec3 _directionOn(double azimuthTurns, double elevationTurns) {
  final azimuth = azimuthTurns * _twoPi;
  final elevation = elevationTurns * _twoPi;
  final cosEl = math.cos(elevation);
  return (
    cosEl * math.cos(azimuth),
    math.sin(elevation),
    cosEl * math.sin(azimuth),
  );
}

/// A free-orientation camera at the center of the sky sphere — no fixed
/// "world up" reference, so there's nothing that plays the role of a pole
/// at all, the same way spinning a globe with your hand has no direction
/// that's special. [forward] is where it's looking; [right]/[up] span the
/// flat tangent plane [worldToScreen] projects onto.
///
/// An earlier version of this pinned orientation to two fixed angles
/// (azimuth around world-up, elevation above/below it) — simple, but
/// *any* such 2-angle parameterization has poles by construction (the
/// points where azimuth stops mattering), and every fix attempted for the
/// artifacts that caused — clamping elevation, letting it wrap, patching
/// the sign flip in the "right" vector right at a pole crossing — was
/// chasing the same root cause instead of removing it. [rotated] is what
/// actually removes it: every drag rotates the *current* basis around its
/// *own* [right]/[up] axes rather than re-deriving from world-fixed
/// angles, exactly how any trackball/arcball control (spinning a 3D
/// object by hand, e.g. in Blender) avoids gimbal issues entirely.
class SkyCamera {
  const SkyCamera._(this.forward, this.right, this.up);

  /// Builds a starting orientation looking toward a fixed
  /// (azimuth, elevation) — the *only* place this class still touches
  /// world-fixed angles, since some starting point has to come from
  /// somewhere (see `NebulaScreen`'s "open centered on Love" logic). Every
  /// [rotated] call afterward moves on from here relative to itself, never
  /// referencing azimuth/elevation again.
  factory SkyCamera.lookingAt({
    required double azimuthTurns,
    required double elevationTurns,
  }) {
    final forward = _directionOn(azimuthTurns, elevationTurns);
    final azimuth = azimuthTurns * _twoPi;
    final right = (-math.sin(azimuth), 0.0, math.cos(azimuth));
    final up = _cross(right, forward);
    return SkyCamera._(forward, right, up);
  }

  final (double, double, double) forward;
  final (double, double, double) right;
  final (double, double, double) up;

  /// A new camera turned by a screen-drag-style delta, in turns —
  /// [horizontalTurns] rotates around the camera's *own current* [up]
  /// axis, [verticalTurns] around its (just-updated) [right] axis. Signed
  /// so a positive [horizontalTurns] looks left and a positive
  /// [verticalTurns] looks up — see `NebulaScreen._rotateCamera`, the only
  /// caller, for where those signs are actually chosen from drag input.
  SkyCamera rotated({
    required double horizontalTurns,
    required double verticalTurns,
  }) {
    final horizontalAngle = horizontalTurns * _twoPi;
    final verticalAngle = verticalTurns * _twoPi;

    var newForward = _rotateAroundAxis(forward, up, horizontalAngle);
    var newRight = _rotateAroundAxis(right, up, horizontalAngle);
    // `up` itself is unchanged by this step — it's the rotation axis.

    newForward = _rotateAroundAxis(newForward, newRight, verticalAngle);
    var newUp = _rotateAroundAxis(up, newRight, verticalAngle);
    // `newRight` itself is unchanged by this step, for the same reason.

    // Re-orthonormalize against floating-point drift accumulating over a
    // long session of small rotations — cheap, and keeps forward/right/up
    // an exact orthonormal basis indefinitely instead of only
    // approximately.
    newForward = _normalized(newForward);
    newRight = _normalized(
      _minus(newRight, _scaled(newForward, _dot(newRight, newForward))),
    );
    newUp = _cross(newRight, newForward);

    return SkyCamera._(newForward, newRight, newUp);
  }

  /// A new camera rotated so that whatever was in direction [from]
  /// (typically wherever the cursor started a drag — see
  /// [screenToDirection]) now lies exactly in direction [to] (typically
  /// the cursor's current position) — an exact "grab and drag" alignment,
  /// via the single rotation (found through [from] × [to] as its axis,
  /// their angle between as its angle) that maps one straight onto the
  /// other, rather than [rotated]'s screen-pixels-to-turns approximation.
  /// `NebulaScreen` uses this exclusively for live dragging (recomputed
  /// from the *drag's starting* camera every frame, not accumulated
  /// step-by-step, so tiny per-frame errors can never build up over a
  /// long drag) and [rotated] only for the momentum glide afterward,
  /// where there's no cursor position left to align to.
  SkyCamera rotatedToAlign(
    (double, double, double) from,
    (double, double, double) to,
  ) => rotatedToAlignFraction(from, to, 1.0);

  /// [rotatedToAlign], stopped [t] of the way there (0 = no movement, 1 =
  /// the same result [rotatedToAlign] itself gives) — what `NebulaScreen`'s
  /// "take me there" fly-to animation steps through frame by frame, via the
  /// same single-axis rotation an exact drag alignment uses, so an
  /// animated jump to a search result sweeps smoothly across the sky
  /// instead of cutting straight there, and — since [right]/[up] are
  /// carried along by that same rotation rather than re-derived from
  /// scratch — never introduces any extra roll of its own along the way.
  SkyCamera rotatedToAlignFraction(
    (double, double, double) from,
    (double, double, double) to,
    double t,
  ) {
    final axisRaw = _cross(from, to);
    final axisLength = math.sqrt(_dot(axisRaw, axisRaw));
    // Already (anti)parallel — either no rotation is needed, or [from] and
    // [to] are exact opposites, a degenerate case with no single
    // well-defined axis that a drag gesture wouldn't realistically produce
    // anyway (it would mean the cursor jumped to the exact antipode of
    // where it started).
    if (axisLength < 1e-9) return this;

    final axis = _scaled(axisRaw, 1 / axisLength);
    final fullAngle = math.acos(_dot(from, to).clamp(-1.0, 1.0));
    final angle = fullAngle * t.clamp(0.0, 1.0);

    var newForward = _normalized(_rotateAroundAxis(forward, axis, angle));
    var newRight = _rotateAroundAxis(right, axis, angle);
    newRight = _normalized(
      _minus(newRight, _scaled(newForward, _dot(newRight, newForward))),
    );
    final newUp = _cross(newRight, newForward);

    return SkyCamera._(newForward, newRight, newUp);
  }

  /// A new camera twisted so the *rendered sky* turns by [angle] radians
  /// clockwise (positive = clockwise, matching `ScaleUpdateDetails.rotation`
  /// and `_RollKnob`'s own convention) around its *own* [forward] axis — a
  /// two-finger rotate gesture, the roll pan/zoom never touch. [forward]
  /// itself never changes: rolling only spins what's already in view, the
  /// way tilting a photo in a viewer doesn't change what's centered in it.
  ///
  /// Note the *negated* angle below: rotating the [right]/[up] basis
  /// vectors clockwise by θ makes everything projected through them (see
  /// [worldToScreen]) appear to spin counterclockwise instead — the same
  /// inversion a camera pan has versus the content it looks at. Passing
  /// `-angle` to the actual basis rotation is what makes a clockwise finger
  /// twist produce a clockwise-*looking* sky, which is the contract every
  /// caller relies on (empirically confirmed backwards before this fix —
  /// see NebulaScreen's roll handling).
  SkyCamera rolled(double angle) {
    if (angle == 0) return this;
    final newRight = _normalized(_rotateAroundAxis(right, forward, -angle));
    final newUp = _cross(newRight, forward);
    return SkyCamera._(forward, newRight, newUp);
  }
}

/// The result of [worldToScreen]: where [world] lands on screen, plus how
/// much the stereographic projection has magnified things there relative
/// to dead-center (1 there, growing gently past 1 toward the edge of a
/// wide field of view) — used only to size a constellation's own sprite
/// consistently with the projection itself (see [ConstellationFieldPainter])
/// instead of every one rendering at a flat fixed size regardless of how
/// far off-center it is.
class ScreenProjection {
  const ScreenProjection(this.position, this.perspectiveScale);
  final Offset position;
  final double perspectiveScale;
}

/// Projects [world] (azimuth, elevation in turns) through [camera] — 1
/// world unit of tangent-plane distance is 1 screen height at [zoom] 1,
/// same convention the old flat-plane version of this function used.
/// Returns null if [world] is far enough behind the camera that the
/// projection breaks down — there's nothing sensible to draw there.
///
/// Stereographic, not the simpler gnomonic (plain divide-by-depth)
/// projection a first pass at this used: gnomonic keeps straight lines
/// straight but stretches anything away from dead-center into ellipses at
/// a wide field of view — the classic "wide-angle lens" look, which reads
/// as an oblong/football-shaped world instead of a sphere once the camera
/// pulls back far enough to matter. Stereographic is conformal (it
/// doesn't stretch circles into ellipses, at any field of view up to
/// nearly 180°), which is what actually looks like a sphere from the
/// inside — the same projection "little planet" panorama viewers use.
///
/// Unlike the flat/wrapped-plane math this replaced, a real camera has no
/// seam and no "second copy" of anything to worry about: within a field
/// of view under 180°, at most one direction in the whole sky can ever
/// land at a given screen position, by construction — so, unlike before,
/// zooming out further can never make a constellation repeat or jump.
ScreenProjection? worldToScreen(
  Offset world,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  final direction = _directionOn(world.dx, world.dy);
  final z = _dot(direction, camera.forward);
  if (z < -0.5) return null;
  final scale = 2 / (1 + z);
  final x = _dot(direction, camera.right) * scale;
  final y = _dot(direction, camera.up) * scale;
  return ScreenProjection(
    Offset(
      screenSize.width / 2 + x * zoom * screenSize.height,
      screenSize.height / 2 - y * zoom * screenSize.height,
    ),
    scale,
  );
}

/// The inverse of [worldToScreen]'s projection: the 3D direction that
/// [screen] corresponds to, for [camera]/[zoom]/[screenSize] — inverting
/// the exact same stereographic math, not an approximation, so it's what
/// makes `NebulaScreen`'s "grab and drag" tracking (see
/// [SkyCamera.rotatedToAlign]) exact rather than the small-angle guess a
/// flat pixel delta would be. Never returns null (unlike the forward
/// direction) — every screen point has a well-defined direction to invert
/// back to, even ones a real camera wouldn't ever render (there's no
/// analogous "behind the camera" case running this backwards).
(double, double, double) screenToDirection(
  Offset screen,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  final tx = (screen.dx - screenSize.width / 2) / zoom / screenSize.height;
  final ty = -(screen.dy - screenSize.height / 2) / zoom / screenSize.height;
  final rho2 = tx * tx + ty * ty;
  final denom = 4 + rho2;
  return _normalized((
    camera.right.$1 * (4 * tx / denom) +
        camera.up.$1 * (4 * ty / denom) +
        camera.forward.$1 * ((4 - rho2) / denom),
    camera.right.$2 * (4 * tx / denom) +
        camera.up.$2 * (4 * ty / denom) +
        camera.forward.$2 * ((4 - rho2) / denom),
    camera.right.$3 * (4 * tx / denom) +
        camera.up.$3 * (4 * ty / denom) +
        camera.forward.$3 * ((4 - rho2) / denom),
  ));
}

/// The zoom that puts something [angularRadius] radians off dead-center
/// (once the camera is already looking straight at its own center — see
/// `NebulaScreen._flyTo`) at [fraction] of the screen's shorter half, e.g.
/// 0.42 sits comfortably inside the frame rather than right at the edge —
/// the zoom-to-fit half of "take me there"'s Maps-style fly-to, the
/// inverse of [worldToScreen]'s own stereographic projection.
///
/// [worldToScreen] projects a point at angle θ off-center to tangent-plane
/// distance sin(θ) · 2/(1+cos θ) = 2·tan(θ/2) (the half-angle identity),
/// before [zoom] and the screen-height scale factor are applied — so
/// solving that same equation for [zoom] given a desired screen distance
/// is this function's entire job.
double zoomToFit({
  required double angularRadius,
  required Size screenSize,
  double fraction = 0.42,
}) {
  final targetPixels = math.min(screenSize.width, screenSize.height) * fraction;
  final tangentUnits = 2 * math.tan(angularRadius / 2);
  if (tangentUnits <= 0) return kSkyMaxZoom;
  return targetPixels / (screenSize.height * tangentUnits);
}

/// The lowest [NebulaScreen] should ever let its camera zoom out to — a
/// real perspective camera (see [worldToScreen]) has no structural reason
/// to cap this the way the old flat-plane math needed a
/// repeat-avoidance floor, so this is just picked for how wide a field of
/// view still feels like a "big sky" rather than a shrunk-down, distant
/// one. Halved from an original 0.6 (which put the screen's near edge at
/// roughly atan(0.5 / 0.6) ≈ 40° off-axis, ~80° of vertical field of
/// view) so max zoom-out reaches a noticeably wider ~118° instead — part
/// of pushing the *entire* zoom range farther back, see
/// `NebulaScreen._maxZoom`'s own comment.
const double minZoomWithoutRepeats = 0.3;

/// The highest `NebulaScreen` ever lets its camera zoom in to — picked
/// freely, not tied to any hard geometric limit the way
/// [minZoomWithoutRepeats] is. Shared here (rather than kept private to
/// `NebulaScreen`) since [ConstellationFieldPainter] also needs it, to
/// turn the raw [zoom] it's given into the same 0..100 "how far into the
/// zoom range" reading `_ZoomSlider`'s own percent label shows — see its
/// use in [ConstellationFieldPainter.paint] for the label fade-in that
/// reading drives.
///
/// `0.3 * (30.0 / 0.3) ^ 0.7` — the zoom value that used to sit at 70% of
/// the old range (whose top end was a plain 30.0), now pulled down to be
/// the new 100%: zooming in past that point read as "too close to be
/// useful" rather than actually helpful, so instead of leaving dead,
/// unused range past it, the whole top end of the range is squeezed down
/// to end exactly there. [minZoomWithoutRepeats] (the range's other end)
/// is untouched — only the max-zoom-in side shrinks.
const double kSkyMaxZoom = 7.5357;

/// Where [zoom] currently sits in the whole [minZoomWithoutRepeats]..
/// [kSkyMaxZoom] range, as a 0..100 reading (unclamped — out of range if
/// [zoom] itself is, which callers needing it clamped do themselves) —
/// shared by `_ZoomSlider`'s own percent label, [ConstellationFieldPainter]'s
/// star/constellation label crossfade, and `NebulaScreen`'s "only
/// individually tappable once zoomed in this far" gate on stars, so all
/// three always agree on what a given percentage means.
double zoomPercent(double zoom) {
  final logZoom = math.log(zoom);
  return (logZoom - math.log(minZoomWithoutRepeats)) /
      (math.log(kSkyMaxZoom) - math.log(minZoomWithoutRepeats)) *
      100;
}

/// The inverse of [zoomPercent] — the raw [zoom] that reads as [percent] on
/// its 0..100 scale. Lets a caller pin a zoom *level* (e.g. `NebulaScreen`'s
/// own "tap a constellation, land exactly at the zoom stars become
/// individually tappable at" pairing) to the same percent scale
/// [zoomPercent] already reports everywhere else, rather than a raw zoom
/// number that means nothing on its own.
double zoomFromPercent(double percent) {
  final logZoom =
      math.log(minZoomWithoutRepeats) +
      percent / 100 * (math.log(kSkyMaxZoom) - math.log(minZoomWithoutRepeats));
  return math.exp(logZoom);
}

/// How far [camera] has rolled away from "level" (its own zero-roll,
/// [SkyCamera.lookingAt]-style orientation) at wherever it's currently
/// looking — a compass-style reading independent of which way it's
/// panned, used to drive the roll knob's orbiting indicator dot (see
/// `_RollKnob` in `nebula_screen.dart`) so there's a way to actually see
/// how far you've rolled instead of just feeling it.
double cameraRollAngle(SkyCamera camera) =>
    _rollAngleAt(camera.forward, camera.up);

/// Shared by [_projectConstellationTransform] and [cameraRollAngle]: how
/// far [cameraUp] has rotated, around [direction], away from the canonical
/// (zero-roll) tangent frame at that exact spot on the sphere — see
/// [_projectConstellationTransform]'s own doc comment for the related full
/// derivation (this is the same "canonical tangent frame" idea, just
/// measuring rotation alone rather than the full transform).
double _rollAngleAt(_Vec3 direction, _Vec3 cameraUp) {
  final azimuth = math.atan2(direction.$3, direction.$1);
  final canonicalRight = (-math.sin(azimuth), 0.0, math.cos(azimuth));
  final canonicalUp = _cross(canonicalRight, direction);

  final upAlongDirection = _dot(cameraUp, direction);
  final upTangent = _normalized(
    _minus(cameraUp, _scaled(direction, upAlongDirection)),
  );

  // Negated: canvas.rotate() turns *clockwise* for a positive angle in
  // Flutter's canvas coordinate space, which is the opposite sense from
  // this angle's own atan2(x, y) convention — confirmed backwards
  // on-screen (constellation shape rotating opposite the background grid)
  // before this negation.
  return -math.atan2(
    _dot(upTangent, canonicalRight),
    _dot(upTangent, canonicalUp),
  );
}

/// The on-screen affine transform (rotation, non-uniform scale, *and*
/// skew all at once) that carries [worldPosition]'s own local 0..1
/// constellation space into screen pixels — the single source of truth
/// [ConstellationFieldPainter.paint] and [hitTestField] both build on.
///
/// A constellation dead-center in view, facing the camera square-on,
/// reads as a plain flat square — same as the old rotation-only version
/// of this. But toward the edge of a wide field of view, a flat patch
/// tangent to the sphere is being looked at *from an angle*, the same way
/// a picture hung on a wall looks like a parallelogram, not a rectangle,
/// once you're not standing square in front of it — and the background
/// sky already renders that way for free, per-pixel, in the shader. A
/// constellation drawn as a plain rotated square right next to it looked
/// wrong specifically for missing that skew/foreshortening — this fixes
/// it by using the *actual* local transform, not just its rotation.
///
/// Computed as the numerical derivative of the exact same stereographic
/// projection [worldToScreen] itself uses, evaluated at [worldPosition]
/// via two points nudged by [_epsilon] along its own canonical (zero-roll)
/// tangent frame — the same "true north/east" convention
/// [SkyCamera.lookingAt] and [_rollAngleAt] both use. [_epsilon] is a
/// small angle in radians, not a pixel count — small enough that the
/// derivative is accurate, nowhere near small enough to lose precision
/// against a direction vector's own unit length.
class _ConstellationTransform {
  const _ConstellationTransform(this.center, this.right, this.up);

  /// Where [worldPosition]'s own center lands on screen — matches
  /// [worldToScreen]'s own `position` exactly.
  final Offset center;

  /// Where a step of one full local-space unit (0..1) along the
  /// constellation's own canonical "right" axis ends up, in screen
  /// pixels *relative to [center]* — the transform's first column.
  final Offset right;

  /// Same as [right], for the canonical "up" axis — the transform's
  /// second column.
  final Offset up;
}

const double _epsilon = 0.01;

_ConstellationTransform? _projectConstellationTransform(
  Offset worldPosition,
  SkyCamera camera,
  double zoom,
  Size screenSize,
  double angularSpan,
) {
  final direction = _directionOn(worldPosition.dx, worldPosition.dy);
  final azimuth = worldPosition.dx * _twoPi;
  final canonicalRight = (-math.sin(azimuth), 0.0, math.cos(azimuth));
  final canonicalUp = _cross(canonicalRight, direction);

  Offset? projectOffset(_Vec3 dir) {
    final z = _dot(dir, camera.forward);
    if (z < -0.5) return null;
    final scale = 2 / (1 + z);
    final x = _dot(dir, camera.right) * scale;
    final y = _dot(dir, camera.up) * scale;
    return Offset(x * zoom * screenSize.height, -y * zoom * screenSize.height);
  }

  final centerOffset = projectOffset(direction);
  final rightOffset = projectOffset(
    _normalized(_add(direction, _scaled(canonicalRight, _epsilon))),
  );
  final upOffset = projectOffset(
    _normalized(_add(direction, _scaled(canonicalUp, _epsilon))),
  );
  if (centerOffset == null || rightOffset == null || upOffset == null) {
    return null;
  }

  // Per radian of tangent-plane angle so far — scaled down to per local
  // 0..1 unit (matching how every other size in this file already treats
  // kSkyConstellationAngularSpan) by multiplying by angularSpan below.
  final rightVec = (rightOffset - centerOffset) / _epsilon * angularSpan;
  final upVec = (upOffset - centerOffset) / _epsilon * angularSpan;

  return _ConstellationTransform(
    Offset(
      screenSize.width / 2 + centerOffset.dx,
      screenSize.height / 2 + centerOffset.dy,
    ),
    rightVec,
    upVec,
  );
}

/// Where [screenPos] lands in [constellation]'s own local unit space —
/// [w]/[h], roughly -0.5..0.5 from center for an on-shape tap, the same
/// convention [ConstellationStar.position] uses (offset by (0.5, 0.5)) —
/// plus [localSizePx] (pixels per local unit, see [starWorldPosition]'s
/// own use of the same [_ConstellationTransform]), or null if the
/// constellation isn't on-screen at all right now (behind the camera, or
/// its own transform can't be projected). Doesn't decide by itself
/// whether that counts as a "hit" — every caller applies its own test on
/// the returned `(w, h)`: [hitTestField]'s flat [_starFieldMargin] box,
/// or [hitTestConstellations]'s [_nearConstellationShape] ribbon around
/// the actual drawn lines.
(double w, double h, double localSizePx)? _localFieldPosition(
  PlacedConstellation constellation,
  Offset screenPos,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  final transform = _projectConstellationTransform(
    constellation.worldPosition,
    camera,
    zoom,
    screenSize,
    kSkyConstellationAngularSpan,
  );
  if (transform == null) return null;

  // Undo the same skew/rotation `ConstellationFieldPainter.paint` draws
  // with (see [_projectConstellationTransform]) by inverting its 2x2
  // basis, so the tap lands in the shape's own flat local space — a plain
  // axis-aligned check against the still-transformed [screenPos] would
  // miss taps once the camera's off dead-center or rolled.
  final relative = screenPos - transform.center;
  final det =
      transform.right.dx * transform.up.dy -
      transform.up.dx * transform.right.dy;
  if (det.abs() < 1e-9) return null;
  final w = (relative.dx * transform.up.dy - transform.up.dx * relative.dy) / det;
  final h = (transform.right.dx * relative.dy - relative.dx * transform.right.dy) / det;

  final localSizePx = (transform.right.distance + transform.up.distance) / 2;
  return (w, h, localSizePx);
}

/// Where [star] itself currently sits on the sky sphere, in
/// (azimuthTurns, elevationTurns) — unlike [constellation]'s own
/// [PlacedConstellation.worldPosition] (the constellation's shared
/// anchor, the same for every star in it), this is [star]'s own
/// sub-position within the shape, via the same local transform
/// [_localFieldPosition] inverts for hit-testing. Needed so flying the camera
/// to a *specific tapped star* (see `SkyScreen._openStarQuickLook`)
/// actually lands on that star rather than just "somewhere in its
/// constellation" — which is all [SkyStarTarget] ever promised (see its
/// own doc comment), fine for a search result but not for "the exact
/// star I just tapped, wherever it sits in the shape."
///
/// Null if [constellation] isn't on-screen at all right now under
/// [camera]/[zoom]/[screenSize] (matches [_localFieldPosition]'s own null
/// case) — shouldn't happen right after tapping a star in it, but there's
/// no sensible position to hand back if it somehow does.
Offset? starWorldPosition(
  PlacedConstellation constellation,
  ConstellationStar star,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) => constellationLocalWorldPosition(
  constellation,
  star.position,
  camera,
  zoom,
  screenSize,
);

/// Where local point [localPosition] currently sits on the sky sphere, in
/// (azimuthTurns, elevationTurns) — [localPosition] is normalized 0..1
/// with (0.5, 0.5) at [constellation]'s own center, the same convention
/// [ConstellationStar.position]/[_localFieldPosition]'s own `w`/`h` use.
/// The general form [starWorldPosition] itself is built from — pulled out
/// standalone for a caller that wants some other point within the shape,
/// not one specific star's (see the sky-navigation tour's own use, to
/// spotlight a shape's actual visual middle rather than its bounding-box
/// center — [PlacedConstellation.worldPosition] itself, see
/// `shapeVertexCentroid`'s own doc comment for why those two can differ).
///
/// Null if [constellation] isn't on-screen at all right now under
/// [camera]/[zoom]/[screenSize].
Offset? constellationLocalWorldPosition(
  PlacedConstellation constellation,
  Offset localPosition,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  final transform = _projectConstellationTransform(
    constellation.worldPosition,
    camera,
    zoom,
    screenSize,
    kSkyConstellationAngularSpan,
  );
  if (transform == null) return null;

  final localOffset = localPosition - const Offset(0.5, 0.5);
  final pointScreen =
      transform.center +
      transform.right * localOffset.dx +
      transform.up * localOffset.dy;

  final direction = screenToDirection(pointScreen, camera, zoom, screenSize);
  final elevationTurns = math.asin(direction.$2.clamp(-1.0, 1.0)) / _twoPi;
  final azimuthTurns = math.atan2(direction.$3, direction.$1) / _twoPi;
  return Offset(azimuthTurns, elevationTurns);
}

/// The plain average of [shape]'s own points, in the same local 0..1
/// space [ConstellationStar.position]/[boundingBoxOf] use.
///
/// [PlacedConstellation.worldPosition] anchors a shape's *bounding-box*
/// center instead (`normalizeEditorPoints`, at authoring time, centers a
/// shape's bbox on local (0.5, 0.5) — see that function's own doc
/// comment) — fine for placement and camera framing, but a shape whose
/// points aren't evenly spread around that box (a roof peak pulling one
/// end to a point, a wide base at the other, say) can read as visibly
/// off-center once actually spotlighted there: the box's own center
/// isn't the same point as where the drawn shape's own "weight" sits.
/// Used by the sky-navigation tour to target its own demo "house"
/// constellation's spotlight hole at somewhere that reads as the middle
/// of the shape itself, not the middle of its box.
Offset shapeVertexCentroid(ConstellationShape shape) {
  if (shape.points.isEmpty) return const Offset(0.5, 0.5);
  var sum = Offset.zero;
  for (final point in shape.points) {
    sum += point;
  }
  return sum / shape.points.length.toDouble();
}

/// [_localFieldPosition]'s margin for [hitTestField] — wider than the shape's
/// own 0..1 footprint since overflow/habit stars can sit up to radius 1.0
/// from center, and this margin has to reach them too or they'd never be
/// tappable at all. Deliberately flat/global rather than shape-relative:
/// pulsar/overflow stars scatter around a constellation on purpose,
/// independent of its own shape's silhouette (see
/// `seededPulsarPosition`/`seededOverflowPosition` in
/// `constellation_layout.dart`), so there's no shape-derived quantity to
/// tie this to.
const double _starFieldMargin = 0.8;

/// Half-width, in the same local unit space [_localFieldPosition]'s own
/// `w`/`h` use, of the ribbon [_nearConstellationShape] hit-tests around
/// each of a constellation's own drawn edges — tared by eye against
/// [DebugSkyHitZones].
///
/// Tried a per-axis bounding-box margin here first (proportioned to
/// [ConstellationShape.points]' own bbox) — an improvement over one flat
/// number for every constellation, but still a *box*: a concave or
/// branching shape (an "L", a "V", a shape with a gap in the middle)
/// still got a hit zone spanning the gap, and it didn't visibly read as
/// "hugging the shape" the way actually tracing the drawn lines does.
/// This instead hit-tests distance to the nearest edge segment directly
/// (with a fallback per-star circle for a shape with no edges yet — a
/// freshly created single-star constellation), so the tap zone traces
/// whatever silhouette is actually on screen, gap or branch included.
const double _footprintRibbonHalfWidth = 0.125;

/// Whether local point ([w], [h]) — same convention as
/// [_localFieldPosition]'s own return, and as [ConstellationStar.position]
/// offset by (0.5, 0.5) — falls within [_footprintRibbonHalfWidth] of any
/// of [constellation]'s own drawn edges. [constellation.edges] index into
/// its *shape-slot* stars specifically (real + nascent, ordered by
/// [ConstellationStar.slotSequence]) — the exact same subset/ordering
/// `ConstellationFieldPainter.paint` itself rebuilds to draw those same
/// lines (see its own comment there) — never pulsar/overflow stars, which
/// have no `slotSequence` and were never part of the drawn shape to begin
/// with.
///
/// Falls back to a plain circle around each shape-slot star individually
/// when there are no valid edges at all yet (a brand new single-star
/// constellation) — nothing to trace a ribbon along, but that one star
/// still needs *some* comfortable tap zone of its own.
bool _nearConstellationShape(PlacedConstellation constellation, double w, double h) {
  final shapeStars =
      constellation.renderStars.where((s) => s.slotSequence != null).toList()
        ..sort((a, b) => a.slotSequence!.compareTo(b.slotSequence!));
  if (shapeStars.isEmpty) return false;

  final point = Offset(w, h);
  var sawEdge = false;
  for (final (a, b) in constellation.edges) {
    if (a >= shapeStars.length || b >= shapeStars.length) continue;
    sawEdge = true;
    final p1 = shapeStars[a].position - const Offset(0.5, 0.5);
    final p2 = shapeStars[b].position - const Offset(0.5, 0.5);
    if (_distanceToSegment(point, p1, p2) <= _footprintRibbonHalfWidth) {
      return true;
    }
  }
  if (sawEdge) return false;

  for (final star in shapeStars) {
    final p = star.position - const Offset(0.5, 0.5);
    if ((point - p).distance <= _footprintRibbonHalfWidth) return true;
  }
  return false;
}

/// Shortest distance from [p] to the segment `[a, b]` — clamping the
/// projection parameter to `[0, 1]` naturally rounds each segment's own
/// ends into a capsule shape rather than an infinite line, which is
/// exactly the "comfortable circle around each star, ribbon along each
/// edge" look [_nearConstellationShape] wants.
double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (abLengthSquared < 1e-12) return (p - a).distance;
  final ap = p - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(0.0, 1.0);
  final closest = a + ab * t;
  return (p - closest).distance;
}

/// Finds whichever constellation (if any) has a star under [screenPos] —
/// checks each constellation whose own on-screen footprint could plausibly
/// contain the tap before reusing [hitTestStar] unmodified, in that
/// constellation's own local pixel space, to find the actual star.
(PlacedConstellation, ConstellationStar)? hitTestField(
  Offset screenPos,
  List<PlacedConstellation> placed,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  for (final constellation in placed) {
    final local = _localFieldPosition(
      constellation,
      screenPos,
      camera,
      zoom,
      screenSize,
    );
    if (local == null) continue;
    final (w, h, localSizePx) = local;
    if (w.abs() > _starFieldMargin || h.abs() > _starFieldMargin) continue;
    final localTap = Offset((w + 0.5) * localSizePx, (h + 0.5) * localSizePx);
    final star = hitTestStar(
      localTap,
      Size.square(localSizePx),
      constellation.renderStars,
    );
    if (star != null) return (constellation, star);
  }
  return null;
}

/// Finds whichever constellation (if any) has [screenPos] within its own
/// general on-screen footprint — not necessarily on one of its stars (see
/// [hitTestField], checked first and taking priority in `NebulaScreen`, so
/// a tap that lands on both a star and its constellation's own footprint
/// still opens the star) — an invisible zone the same way
/// [hitTestSupernovas] is, so tapping a constellation's shape opens its
/// own `ConstellationScreen`. See [_nearConstellationShape] for what
/// counts as "on" it.
PlacedConstellation? hitTestConstellations(
  Offset screenPos,
  List<PlacedConstellation> placed,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  for (final constellation in placed) {
    final local = _localFieldPosition(
      constellation,
      screenPos,
      camera,
      zoom,
      screenSize,
    );
    if (local == null) continue;
    final (w, h, _) = local;
    if (_nearConstellationShape(constellation, w, h)) return constellation;
  }
  return null;
}

/// How far (already-zoomed screen pixels) a tap can land from a
/// supernova's own projected center and still count as hitting it — see
/// [hitTestSupernovas]. [_minSupernovaHitRadius] is a floor, not the
/// radius itself: [_supernovaHitWorldRadius] scales the same way
/// `SkySupernova`'s own icon does (bigger the more zoomed in, via
/// [ScreenProjection.perspectiveScale]), so the invisible zone still
/// feels attached to a visibly-larger icon once zoomed in, while the
/// floor keeps it comfortably tappable even zoomed out far enough that
/// the icon itself has shrunk to a speck.
///
/// [_supernovaHitWorldRadius] reaches out to the visible ring of light
/// around each icon, not just the icon glyph itself — matching
/// `sky_supernova.frag`'s own `ringRadius` (0.09, in that shader's local
/// `uv` space, itself `(angular offset in radians) / 0.45`): solving
/// 0.09 = θ / 0.45 gives θ ≈ 0.0405 radians, the same "world" unit
/// [_iconWorldRadius] in `sky_supernova.dart` already uses for the icon.
const double _minSupernovaHitRadius = 28.0;
const double _supernovaHitWorldRadius = 0.0405;

/// Finds whichever [LifeArea] (if any) has its own supernova under
/// [screenPos] — an invisible hit zone over the same spot `SkySupernova`
/// draws each area's icon, so tapping a supernova opens that area's own
/// detail page ([AreaDetailScreen]) without adding any new visible
/// element to the (otherwise untouched) supernova artwork itself.
LifeArea? hitTestSupernovas(
  Offset screenPos,
  SkyCamera camera,
  double zoom,
  Size screenSize,
) {
  for (final area in LifeArea.values) {
    final projection = worldToScreen(
      areaWorldPosition(area),
      camera,
      zoom,
      screenSize,
    );
    if (projection == null) continue;
    final radius = math.max(
      _minSupernovaHitRadius,
      _supernovaHitWorldRadius * zoom * screenSize.height * projection.perspectiveScale,
    );
    if ((screenPos - projection.position).distanceSquared <= radius * radius) {
      return area;
    }
  }
  return null;
}

// ---------------------------------------------------------------------
// DEBUG ONLY — below this line is a temporary tool, not a feature. Paints
// the exact hit-test zones [hitTestSupernovas], [hitTestConstellations]/
// [hitTestField], and each star's own [hitTestStar] radius use, as
// translucent green shapes built from the *same* private geometry those
// functions themselves hit-test against — not a redrawn approximation,
// so what's on screen is exactly where a tap does and doesn't land on
// something. Added to help tune the sky-navigation tour's own "empty
// sky" double-tap spot by eye; drop this whole block and its call site
// in `sky_screen.dart` once that's settled.
// ---------------------------------------------------------------------

/// See the block comment above. Drop into the same `Stack` the sky's own
/// content paints into (same coordinate space [hitTestSupernovas]/
/// [hitTestConstellations]/[hitTestField] use) — `IgnorePointer`ed, so it
/// never affects real hit-testing, only shows it.
class DebugSkyHitZones extends StatelessWidget {
  const DebugSkyHitZones({
    super.key,
    required this.placed,
    required this.camera,
    required this.zoom,
  });

  final List<PlacedConstellation> placed;
  final SkyCamera camera;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DebugSkyHitZonesPainter(
          placed: placed,
          camera: camera,
          zoom: zoom,
        ),
      ),
    );
  }
}

class _DebugSkyHitZonesPainter extends CustomPainter {
  _DebugSkyHitZonesPainter({
    required this.placed,
    required this.camera,
    required this.zoom,
  });

  final List<PlacedConstellation> placed;
  final SkyCamera camera;
  final double zoom;

  // Two shades of the same green: the tighter, actually-opens-it
  // [_nearConstellationShape] ribbon reads solid, the wider
  // [_starFieldMargin] a tap has to be within just to be *checked*
  // against individual stars reads much fainter — the two used to look
  // identical, which was confusing on its own.
  static final _supernovaFill = Paint()..color = const Color(0x5500FF66);
  static final _footprintStroke = Paint()
    ..color = const Color(0x5500FF66)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final _footprintFallbackFill = Paint()..color = const Color(0x5500FF66);
  static final _starFieldReachFill = Paint()..color = const Color(0x2200FF66);
  static final _starFill = Paint()..color = const Color(0x9900FF66);
  static final _outline = Paint()
    ..color = const Color(0xCC00FF66)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final area in LifeArea.values) {
      final projection = worldToScreen(
        areaWorldPosition(area),
        camera,
        zoom,
        size,
      );
      if (projection == null) continue;
      final radius = math.max(
        _minSupernovaHitRadius,
        _supernovaHitWorldRadius *
            zoom *
            size.height *
            projection.perspectiveScale,
      );
      canvas.drawCircle(projection.position, radius, _supernovaFill);
      canvas.drawCircle(projection.position, radius, _outline);
    }

    for (final constellation in placed) {
      final transform = _projectConstellationTransform(
        constellation.worldPosition,
        camera,
        zoom,
        size,
        kSkyConstellationAngularSpan,
      );
      if (transform == null) continue;

      _drawMarginParallelogram(
        canvas,
        transform,
        _starFieldMargin,
        _starFieldMargin,
        _starFieldReachFill,
        null,
      );
      _drawFootprintRibbon(canvas, transform, constellation);

      // Same forward local-to-screen mapping [starWorldPosition] uses —
      // [hitTestStar]'s own 24px `hitRadius` is in that same local pixel
      // space, which [_localFieldPosition] sizes 1:1 with screen pixels
      // (see its own `localSizePx`), so drawing it at face value here
      // matches closely enough for tuning by eye.
      for (final star in constellation.renderStars) {
        final localOffset = star.position - const Offset(0.5, 0.5);
        final starScreen =
            transform.center +
            transform.right * localOffset.dx +
            transform.up * localOffset.dy;
        canvas.drawCircle(starScreen, 24, _starFill);
      }
    }
  }

  /// Mirrors [_nearConstellationShape]'s own edge resolution exactly (same
  /// shape-slot filter/sort, same edge list, same fallback-to-circles when
  /// there are no valid edges yet) so this overlay never drifts from what
  /// the real hit-test actually does — draws a thick round-capped line per
  /// edge (a screen-space stroke, [_footprintRibbonHalfWidth] converted via
  /// [_ConstellationTransform.localSizePx]'s own scale) instead of the
  /// parallelogram [_drawMarginParallelogram] still draws for the flat
  /// [_starFieldMargin] pass above.
  void _drawFootprintRibbon(
    Canvas canvas,
    _ConstellationTransform transform,
    PlacedConstellation constellation,
  ) {
    final shapeStars =
        constellation.renderStars.where((s) => s.slotSequence != null).toList()
          ..sort((a, b) => a.slotSequence!.compareTo(b.slotSequence!));
    if (shapeStars.isEmpty) return;

    final localSizePx = (transform.right.distance + transform.up.distance) / 2;
    _footprintStroke.strokeWidth = _footprintRibbonHalfWidth * 2 * localSizePx;

    Offset toScreen(Offset localPosition) {
      final offset = localPosition - const Offset(0.5, 0.5);
      return transform.center +
          transform.right * offset.dx +
          transform.up * offset.dy;
    }

    var sawEdge = false;
    for (final (a, b) in constellation.edges) {
      if (a >= shapeStars.length || b >= shapeStars.length) continue;
      sawEdge = true;
      canvas.drawLine(
        toScreen(shapeStars[a].position),
        toScreen(shapeStars[b].position),
        _footprintStroke,
      );
    }
    if (sawEdge) return;

    final radius = _footprintRibbonHalfWidth * localSizePx;
    for (final star in shapeStars) {
      canvas.drawCircle(toScreen(star.position), radius, _footprintFallbackFill);
    }
  }

  void _drawMarginParallelogram(
    Canvas canvas,
    _ConstellationTransform transform,
    double marginW,
    double marginH,
    Paint fillPaint,
    Paint? strokePaint,
  ) {
    final corners = [
      transform.center + transform.right * marginW + transform.up * marginH,
      transform.center + transform.right * marginW - transform.up * marginH,
      transform.center - transform.right * marginW - transform.up * marginH,
      transform.center - transform.right * marginW + transform.up * marginH,
    ];
    final path = Path()..addPolygon(corners, true);
    canvas.drawPath(path, fillPaint);
    if (strokePaint != null) canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _DebugSkyHitZonesPainter old) => true;
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Star-name labels are implemented (see [ConstellationFieldPainter.paint])
/// but switched off for now — with many stars close together they piled up
/// and overlapped too much to read cleanly. Left in place, gated behind
/// this flag, rather than deleted, since the plan is to revisit the
/// crowding problem (spacing/collision-avoidance, most likely) and turn
/// them back on later.
const bool _kShowStarLabels = false;

/// Constellation-name labels — parked the same way, and for the same
/// reason (see [_kShowStarLabels]'s own comment): left in place, gated
/// behind this flag rather than deleted, so a later cleanup pass (or a
/// change of mind) is a one-line flip back, not a rewrite. See the
/// project's "TRB" (to-remember box) memory for the standing list of
/// things parked this way.
const bool _kShowConstellationLabels = false;

/// Where, on the log-zoom scale, constellation-name labels finish fading
/// out and star-name labels finish fading in (see [ConstellationFieldPainter]
/// — `_kLabelFadeLogRange` either side of this is the actual crossfade
/// width). Log rather than linear zoom since [SkyCamera]/`NebulaScreen`
/// zoom is inherently multiplicative (min 0.3 to max 30, a 100x span) —
/// a fixed linear threshold would land at a wildly different *relative*
/// zoom depending on where in that span it fell. Narrow range — the
/// crossfade itself should happen quickly, over a small zoom change, not
/// gradually over a huge one. Only matters while [_kShowStarLabels] is
/// back on — with it off, the constellation label just stays fully
/// visible at every zoom instead of ever handing off to anything.
const double _kLabelSwitchLogZoom = 0.9; // ln(zoom) ≈ zoom 2.5
const double _kLabelFadeLogRange = 0.25; // ≈ crossfades over a ~1.6x zoom span

/// Where, on the 0..100 "how far into the zoom range" reading described at
/// [kSkyMaxZoom], a constellation's own name label starts (and finishes)
/// fading in from fully invisible — see `ConstellationFieldPainter.paint`'s
/// own `zoomFadeAlpha`. Below [_kLabelZoomFadeStartPercent] there's little
/// room on screen to read a name anyway, at that zoomed-out a distance —
/// hiding it there is what keeps the fully-zoomed-out view from being
/// cluttered with a wall of labels the moment the tab opens.
const double _kLabelZoomFadeStartPercent = 20;
const double _kLabelZoomFadeEndPercent = 35;

/// Shared by both constellation- and star-name labels — a single size
/// (not a bigger one for one kind and a smaller one for the other, as
/// tried first) reads as more consistent switching between the two.
/// Slightly smaller now that the constellation label is the only one ever
/// on screen (see [_kShowStarLabels]) and stays up throughout, rather than
/// only briefly at the widest zoom-out.
const double _kLabelFontSize = 11;

/// The shared gold every part of the constellation layer that isn't a
/// star's own bright core is tinted with — the soft glow behind anything
/// burning (see [StarPalette.lit], which `SkyScreen` sets to this) and the
/// connecting lines between them, so the layer reads as one warm family
/// with `SkySupernova`'s own gold rather than clashing white against it. A
/// star's own core mark stays white ([StarPalette.core], set to plain
/// [Colors.white]) the same way a supernova's own icon is a white glyph
/// over a gold glow/border — not this same gold, which would wash the two
/// together into one flat blob with no bright point left to read as the
/// star itself. Fixed rather than pulled from the active theme, like
/// [_drawPillLabel]'s own colors below — the Sky tab is dark regardless of
/// light/dark mode.
const Color kConstellationGold = Color(0xFFF2C879);

/// The palette the Sky tab paints every constellation with. Fixed for the
/// same reason [kConstellationGold] is, and deliberately a touch brighter
/// than the app's own `context.colors` star colors: out here a star is a
/// few pixels across on a black sky, not an icon on a panel, so the same
/// values would read as barely-there rather than as "no light".
const StarPalette kSkyStarPalette = StarPalette(
  lit: kConstellationGold,
  core: Colors.white,
  nascent: Color(0xFFEFF3FF),
  unlit: Color(0xFF87A3EC),
  dead: Color(0xFF55689F),
);

/// A lighter, paler gold than [kConstellationGold] for a label's own pill
/// background (see [_drawPillLabel]) — the deeper gold used on
/// icons/glows/lines reads as too heavy at a label's small, solid-fill
/// size, where there's no glow beneath it to soften it the way there is
/// on a star.
const Color _kLabelGold = Color(0xFFFFE7B0);

/// A single small screen-space label: a pale-gold pill with dark-navy
/// text and its own soft glow behind it (the same blurred-shadow recipe
/// the app's gold buttons use elsewhere, just hand-drawn here since this
/// is a raw [Canvas] pill, not a widget) — centered on [anchor], always
/// horizontal, never affected by [_projectConstellationTransform]'s own
/// rotation/skew, so it stays readable no matter how the camera's turned.
/// Colors are fixed rather than pulled from the active theme — the Galaxy
/// tab's sky is dark regardless of light/dark mode, and these need to read
/// clearly against it either way.
/// Longer than this, a name gets cut short with a trailing ellipsis — a
/// long title otherwise made its own pill wide enough to overlap
/// neighboring labels, exactly what a short, fixed-width badge is meant
/// to avoid.
const int _kLabelMaxChars = 30;

String _truncateLabel(String text) {
  if (text.length <= _kLabelMaxChars) return text;
  return '${text.substring(0, _kLabelMaxChars - 1)}…';
}

void _drawPillLabel(
  Canvas canvas,
  Offset anchor,
  String text,
  double fontSize,
  double alpha,
) {
  if (alpha <= 0.01 || text.isEmpty) return;

  final textPainter = TextPainter(
    text: TextSpan(
      text: _truncateLabel(text),
      style: TextStyle(
        color: const Color(0xFF0D1220).withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final paddingH = fontSize * 0.55;
  final paddingV = fontSize * 0.3;
  final rect = Rect.fromCenter(
    center: anchor,
    width: textPainter.width + paddingH * 2,
    height: textPainter.height + paddingV * 2,
  );
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
  // The glow, wider and blurred, drawn first so the crisp pill sits on top
  // of it rather than the other way round.
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = kConstellationGold.withValues(alpha: alpha * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawRRect(rrect, Paint()..color = _kLabelGold.withValues(alpha: alpha * 0.85));
  textPainter.paint(
    canvas,
    Offset(anchor.dx - textPainter.width / 2, anchor.dy - textPainter.height / 2),
  );
}

/// Paints every [placed] constellation over the shared [camera]/[zoom] —
/// reuses [ConstellationPainter] completely unmodified, once per
/// constellation, inside a save/transform/restore block that maps its own
/// local 0..1 space onto wherever [_projectConstellationTransform] puts
/// it — including that transform's rotation/skew, not just its position.
class ConstellationFieldPainter extends CustomPainter {
  const ConstellationFieldPainter({
    required this.placed,
    required this.camera,
    required this.zoom,
    required this.flareProgram,
    required this.palette,
    required this.revision,
    this.time = 0,
  });

  final List<PlacedConstellation> placed;
  final SkyCamera camera;
  final double zoom;

  /// Forwarded straight through to [ConstellationPainter.flareProgram] —
  /// see its own doc comment.
  final ui.FragmentProgram? flareProgram;

  /// Forwarded straight through to [ConstellationPainter.palette] — see
  /// [StarPalette].
  final StarPalette palette;

  final int revision;

  /// Forwarded straight through to [ConstellationPainter.time] — see its
  /// own doc comment.
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    // A constellation near the edge of the sky view projects to a center
    // point outside this canvas's own bounds — expected, since only part
    // of it should be visible. But `Stack`'s default clip only catches a
    // *Positioned* child's box exceeding its bounds; it has no way to see
    // that a CustomPainter's own raw Canvas calls drew past its size, so
    // without this the overflow paints straight through into whatever
    // sits to this pane's own left (the sidebar, on wide layouts) instead
    // of just disappearing off-screen like a real off-center object would.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Shared by every constellation this frame — a crossfade between
    // constellation-name and star-name labels driven by [zoom] alone (see
    // `_kLabelSwitchLogZoom`'s own comment). Label *size* deliberately
    // doesn't vary with zoom at all right now (each kind just draws at
    // its own fixed size below) — simpler, and reads as more useful this
    // way; a zoom-scaled size may come back later.
    final logZoom = math.log(zoom);
    final starLabelAlpha = _kShowStarLabels
        ? _smoothstep(
            _kLabelSwitchLogZoom - _kLabelFadeLogRange,
            _kLabelSwitchLogZoom + _kLabelFadeLogRange,
            logZoom,
          )
        : 0.0;
    // Where [zoom] currently sits in the whole zoom range, as the same
    // 0..100 reading `_ZoomSlider`'s own percent label shows (see
    // [zoomPercent]) — labels start fully invisible at the bottom of the
    // range and fade in on the way up to [_kLabelZoomFadeEndPercent],
    // rather than being there (and cluttering the view) from the very
    // first, fully-zoomed-out frame.
    final zoomRangePercent = zoomPercent(zoom);
    final zoomFadeAlpha = _smoothstep(
      _kLabelZoomFadeStartPercent,
      _kLabelZoomFadeEndPercent,
      zoomRangePercent,
    );
    final constellationLabelAlpha = _kShowConstellationLabels
        ? (_kShowStarLabels ? 1 - starLabelAlpha : 1.0) * zoomFadeAlpha
        : 0.0;

    for (final constellation in placed) {
      final transform = _projectConstellationTransform(
        constellation.worldPosition,
        camera,
        zoom,
        size,
        kSkyConstellationAngularSpan,
      );
      if (transform == null) continue;
      final localSizePx =
          (transform.right.distance + transform.up.distance) / 2;

      canvas.save();
      // Maps this constellation's own local 0..localSizePx square (top-left
      // origin, same space ConstellationPainter always draws in) onto
      // wherever it actually belongs on screen — including the
      // rotation/skew/foreshortening [_projectConstellationTransform]
      // computed, not just a plain translate+uniform-scale, so it reads as
      // painted onto the sphere itself rather than pasted flat over it.
      canvas.transform(
        Float64List.fromList([
          transform.right.dx / localSizePx,
          transform.right.dy / localSizePx,
          0,
          0,
          transform.up.dx / localSizePx,
          transform.up.dy / localSizePx,
          0,
          0,
          0,
          0,
          1,
          0,
          transform.center.dx -
              (transform.right.dx + transform.up.dx) / 2,
          transform.center.dy -
              (transform.right.dy + transform.up.dy) / 2,
          0,
          1,
        ]),
      );
      ConstellationPainter(
        stars: constellation.renderStars,
        flareProgram: flareProgram,
        revision: revision,
        palette: palette,
        edges: constellation.edges,
        // Bolder than ConstellationScreen's own single-project defaults —
        // at kSkyConstellationAngularSpan's now much smaller size, a
        // constellation needs to read through thicker lines/icons/glow
        // rather than through sheer size (which, tried first, badly
        // distorted near the edges of a wide field of view).
        lineWidthScale: 3.5,
        lineAlpha: 0.9,
        sparkleScale: 2.2,
        glowScale: 1.8,
        time: time,
      ).paint(canvas, Size.square(localSizePx));
      canvas.restore();

      // Labels are drawn *outside* the save/transform block above —
      // plain screen space, deliberately never subjected to the same
      // rotation/skew as the constellation itself, so they stay
      // horizontal and readable no matter how the camera's turned.
      if (constellationLabelAlpha > 0.01) {
        _drawPillLabel(
          canvas,
          transform.center + Offset(0, localSizePx * 0.55 + 10),
          constellation.project.name,
          _kLabelFontSize,
          constellationLabelAlpha,
        );
      }
      if (_kShowStarLabels && starLabelAlpha > 0.01) {
        for (final star in constellation.renderStars) {
          // A nascent star has nothing to be called yet — an empty pill
          // floating next to it would read as a rendering bug.
          if (star.label.isEmpty) continue;
          final starScreenPos =
              transform.center +
              transform.right * (star.position.dx - 0.5) +
              transform.up * (star.position.dy - 0.5);
          // Pushed out *away from the constellation's own center*, along
          // the same direction the star already sits from it — the
          // connecting lines all run through/near that center, so
          // radiating outward keeps a label clear of them without
          // actually knowing where every line is. Falls back to straight
          // down only for a star sitting right on the center itself,
          // where that direction is meaningless.
          //
          // The *distance* is measured from the constellation's own
          // center, like the constellation label's own offset just above
          // — not a fixed step from the star's own position — so every
          // star label clears the whole shape's outer edge the same way,
          // rather than landing just past whichever one star happens to
          // be closest to (and possibly still well inside the shape's
          // overall footprint if that star sits near its center). Never
          // closer than the star's own actual distance either, in case an
          // overflow/habit star already sits past that edge itself.
          final fromCenter = starScreenPos - transform.center;
          final outward = fromCenter.distance > 4
              ? fromCenter / fromCenter.distance
              : const Offset(0, 1);
          final labelDistance = math.max(
            fromCenter.distance,
            localSizePx * 0.55,
          );
          _drawPillLabel(
            canvas,
            transform.center + outward * (labelDistance + 14),
            star.label,
            _kLabelFontSize,
            starLabelAlpha,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ConstellationFieldPainter oldDelegate) {
    return revision != oldDelegate.revision ||
        camera != oldDelegate.camera ||
        zoom != oldDelegate.zoom ||
        flareProgram != oldDelegate.flareProgram ||
        placed.length != oldDelegate.placed.length ||
        time != oldDelegate.time;
  }
}

/// A self-ticking wrapper around [ConstellationFieldPainter] — owns its own
/// [Ticker] (same pattern as `NebulaBackground`'s) so the flare rays on lit
/// stars (see [ConstellationPainter._drawGlowAndSparkle]) actually animate,
/// without making the whole host screen repaint every frame just to feed
/// this one painter a clock.
class AnimatedConstellationField extends StatefulWidget {
  const AnimatedConstellationField({
    super.key,
    required this.placed,
    required this.camera,
    required this.zoom,
    required this.flareProgram,
    required this.palette,
    required this.revision,
  });

  final List<PlacedConstellation> placed;
  final SkyCamera camera;
  final double zoom;
  final ui.FragmentProgram? flareProgram;
  final StarPalette palette;
  final int revision;

  @override
  State<AnimatedConstellationField> createState() =>
      _AnimatedConstellationFieldState();
}

class _AnimatedConstellationFieldState
    extends State<AnimatedConstellationField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ConstellationFieldPainter(
        placed: widget.placed,
        camera: widget.camera,
        zoom: widget.zoom,
        flareProgram: widget.flareProgram,
        palette: widget.palette,
        revision: widget.revision,
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      ),
    );
  }
}
