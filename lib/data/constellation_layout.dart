import 'dart:math' as math;
import 'dart:ui';

import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../utils/habit_stats.dart';
import '../widgets/constellation_painter.dart';
import 'constellation_shape.dart';

/// A shape's graph grows this large before overflow stars stop being woven
/// into the constellation and start scattering instead (see
/// [seededOverflowPosition]) — a guard against the O(n²) longest-edge search
/// below getting expensive for a project with an implausible number of wins.
const int maxChainedStars = 600;

/// How many stars (every kind that sits on the shape, dead ones included —
/// they keep their slot) one constellation can hold. Matches the editor's cap
/// on a shape's own points, so a shape can be drawn and then filled
/// completely, but never grown past what Cosmo can render legibly.
const int kMaxConstellationStars = 15;

/// How many pulsars one constellation can hold. Counted apart from
/// [kMaxConstellationStars]: pulsars scatter around the shape instead of
/// sitting on it, and are drawn as smaller points.
const int kMaxConstellationPulsars = 5;

/// Thrown by `StarRepository.add` / `HabitRepository.add` when the target
/// constellation is already at its cap. The star form checks first and shows
/// a message, so this is only the safety net behind it.
class ConstellationFullException implements Exception {
  const ConstellationFullException({required this.pulsar});

  final bool pulsar;

  @override
  String toString() =>
      'ConstellationFullException(${pulsar ? 'pulsars' : 'stars'})';
}

/// The result of growing a [ConstellationShape] to a target star count:
/// every star's position, and every line segment (as index pairs into
/// [points]) that should connect them.
class ConstellationLayout {
  const ConstellationLayout({required this.points, required this.edges});

  final List<Offset> points;
  final List<(int, int)> edges;
}

/// Grows [shape]'s fixed graph up to [count] stars by repeatedly finding
/// whichever edge in the current graph is longest, and splitting it in two
/// with a new star at its midpoint.
///
/// This is what replaces sequential placement along a precomputed dense
/// outline: because the *longest remaining edge* is always the one split
/// next, the pattern thickens evenly across every branch as wins are
/// logged, instead of concentrating new stars along whichever stretch
/// happens to come next in a fixed list. Works the same whether the shape's
/// base graph is a simple path, a closed loop, or — as with a figure's arms
/// and legs, or a teapot's handle — branches. The result is deterministic
/// for a given [count]: recomputing it from scratch always reproduces the
/// same positions, so a star's place in the sky never shifts as more are
/// added.
ConstellationLayout buildConstellationLayout(
  ConstellationShape shape,
  int count,
) {
  final basePoints = shape.points;
  if (count <= 0 || basePoints.isEmpty) {
    return const ConstellationLayout(points: [], edges: []);
  }
  if (count <= basePoints.length) {
    return ConstellationLayout(
      points: basePoints.sublist(0, count),
      edges: shape.edges,
    );
  }
  if (shape.edges.isEmpty) {
    // Nothing to grow by splitting — a shape with two or more points but no
    // connections between them at all (the editor allows saving one, with
    // only a non-blocking warning; a deliberate "scattered" style is a
    // legitimate constellation to want). The loop below always indexes
    // into edges' longest entry, which would throw a RangeError here since
    // there's no edge to find at all. Stopping at the shape's own points
    // instead doesn't lose a star: buildConstellationRenderStars already
    // scatters any star beyond what a layout returns, the same fallback it
    // uses past maxChainedStars, it just also covers this shape never
    // "growing" past its own points.
    return ConstellationLayout(points: basePoints, edges: const []);
  }

  final points = List<Offset>.from(basePoints);
  final edges = List<(int, int)>.from(shape.edges);
  final target = math.min(count, maxChainedStars);

  while (points.length < target) {
    var longestIndex = 0;
    var longestDistanceSq = -1.0;
    for (var i = 0; i < edges.length; i++) {
      final (a, b) = edges[i];
      final distanceSq = (points[a] - points[b]).distanceSquared;
      if (distanceSq > longestDistanceSq) {
        longestDistanceSq = distanceSq;
        longestIndex = i;
      }
    }
    final (a, b) = edges[longestIndex];
    final midpoint = Offset(
      (points[a].dx + points[b].dx) / 2,
      (points[a].dy + points[b].dy) / 2,
    );
    final newIndex = points.length;
    points.add(midpoint);
    edges[longestIndex] = (a, newIndex);
    edges.add((newIndex, b));
  }
  return ConstellationLayout(points: points, edges: edges);
}

Offset _seededScatter(
  int seed, {
  required double minRadius,
  required double maxRadius,
}) {
  final random = math.Random(seed);
  final angle = random.nextDouble() * 2 * math.pi;
  final radius = minRadius + random.nextDouble() * (maxRadius - minRadius);
  // The scatter radius reaches past the local 0..1 square toward its
  // corners, where a star's glow gets cut off by the constellation's own
  // paint bounds — so every scattered spot is kept [_kScatterPadding] clear
  // of the square's edge.
  return Offset(
    (0.5 + radius * math.cos(angle)).clamp(
      _kScatterPadding,
      1 - _kScatterPadding,
    ),
    (0.5 + radius * math.sin(angle)).clamp(
      _kScatterPadding,
      1 - _kScatterPadding,
    ),
  );
}

const _kScatterPadding = 0.1;

/// Deterministic placement for a star beyond [maxChainedStars] — vanishingly
/// rare, but must never crash or lose a star. Seeded by the star's own
/// immutable id (never by its position in the list), so a star's position
/// can't shift if the list is ever reordered.
Offset seededOverflowPosition(int seed) =>
    _seededScatter(seed, minRadius: 0.55, maxRadius: 1.0);

/// How far a pulsar must stay from every star and line of its constellation's
/// shape (as a fraction of the constellation's footprint), and from the other
/// pulsars. Large enough that a pulsar always reads as its own point of light
/// rather than part of the figure.
const double kPulsarShapeClearance = 0.14;
const double _kPulsarPulsarClearance = 0.1;

/// Pulsars may sit closer to the edge of the footprint than other scattered
/// stars: a shape already fills 0.1..0.9 along its longest axis, so the free
/// room is mostly out there.
const double _kPulsarPadding = 0.05;

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSq = ab.distanceSquared;
  if (lengthSq == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSq).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

double _clearanceFromShape(Offset p, ConstellationShape shape) {
  var nearest = double.infinity;
  for (final point in shape.points) {
    nearest = math.min(nearest, (p - point).distance);
  }
  for (final (a, b) in shape.edges) {
    if (a >= shape.points.length || b >= shape.points.length) continue;
    nearest = math.min(
      nearest,
      _distanceToSegment(p, shape.points[a], shape.points[b]),
    );
  }
  return nearest;
}

/// Deterministic placement for a pulsar's own small, scattered star, seeded
/// by the habit's own immutable id. It is kept at least
/// [kPulsarShapeClearance] from every star and line of [shape] and
/// [_kPulsarPulsarClearance] from the pulsars already placed ([avoid]):
/// candidates are drawn from the seed in order and the first one that clears
/// both wins; if none does (a shape that fills the whole footprint), the
/// candidate with the most room is used instead. Only the shape's own graph
/// counts, not the stars grown onto it later — those sit on its lines — so
/// a pulsar never moves as stars are added.
Offset seededPulsarPosition(
  int seed, {
  ConstellationShape? shape,
  List<Offset> avoid = const [],
}) {
  final random = math.Random(seed);
  Offset? best;
  var bestRoom = -1.0;
  for (var attempt = 0; attempt < 80; attempt++) {
    final candidate = Offset(
      _kPulsarPadding + random.nextDouble() * (1 - 2 * _kPulsarPadding),
      _kPulsarPadding + random.nextDouble() * (1 - 2 * _kPulsarPadding),
    );
    if (shape == null && avoid.isEmpty) return candidate;
    final fromShape = shape == null
        ? double.infinity
        : _clearanceFromShape(candidate, shape);
    var fromPulsars = double.infinity;
    for (final other in avoid) {
      fromPulsars = math.min(fromPulsars, (candidate - other).distance);
    }
    if (fromShape >= kPulsarShapeClearance &&
        fromPulsars >= _kPulsarPulsarClearance) {
      return candidate;
    }
    // Shape clearance matters most; pulsar spacing only breaks ties.
    final room =
        math.min(fromShape / kPulsarShapeClearance, 1.0) * 2 +
        math.min(fromPulsars / _kPulsarPulsarClearance, 1.0);
    if (room > bestRoom) {
      bestRoom = room;
      best = candidate;
    }
  }
  return best!;
}

/// Turns one project's raw [stars]/[habits] into everything
/// [ConstellationPainter] needs to draw it: every slot on the shape's grown
/// graph filled either by a real star or by a *nascent* one, every pulsar
/// scattered around/inside/outside that graph, and the edge list to connect
/// them. Shared by `ConstellationScreen` (one project, framed to fill the
/// screen) and the Sky tab (every project at once, scattered across a
/// pannable world) — same star-to-shape mapping either way, so a star's
/// place in its own constellation never depends on which screen is looking
/// at it.
///
/// A brand-new constellation therefore already renders as its full shape:
/// every line, and one nascent star per slot waiting to be configured. As
/// stars get created they *replace* nascent ones — nothing moves, because a
/// star is placed by its own permanent [Star.slotSequence], not by its
/// position in [stars].
({List<ConstellationStar> stars, List<(int, int)> edges})
buildConstellationRenderStars({
  required List<Star> stars,
  required List<Habit> habits,
  required ConstellationShape? shape,
  required Map<int, List<HabitCompletion>> completionsByHabit,
}) {
  if (shape == null) {
    return (stars: const [], edges: const []);
  }

  // The shape is always grown to at least its own point count (so every
  // slot exists from day one, nascent until claimed), and beyond it only as
  // far as the highest slot actually in use.
  final highestSlot = stars.fold<int>(
    0,
    (max, s) => s.slotSequence > max ? s.slotSequence : max,
  );
  final layout = buildConstellationLayout(
    shape,
    math.max(shape.points.length, highestSlot),
  );

  final renderStars = <ConstellationStar>[];
  final claimedSlots = <int>{};
  for (final star in stars) {
    final index = star.slotSequence - 1;
    claimedSlots.add(index);
    renderStars.add(
      ConstellationStar(
        entityId: star.id,
        position: index >= 0 && index < layout.points.length
            ? layout.points[index]
            : seededOverflowPosition(star.id),
        kind: star.kind,
        lit: star.isLit,
        label: star.title,
        slotSequence: star.slotSequence,
        intensity: star.intensity,
        photoPath: star.photoPath,
      ),
    );
  }

  // Only the shape's *own* slots go nascent. Anything past them exists
  // solely because a star was put there, so there's nothing to leave empty.
  for (var index = 0; index < shape.points.length; index++) {
    if (claimedSlots.contains(index)) continue;
    renderStars.add(
      ConstellationStar(
        entityId: 0,
        position: layout.points[index],
        kind: StarKind.nascent,
        lit: false,
        label: '',
        slotSequence: index + 1,
      ),
    );
  }

  // By id, not list order: a new pulsar lands at the front of the stored
  // list, and each placement avoids the ones before it, so placing in list
  // order would move existing pulsars whenever another was added.
  final placedPulsars = <Offset>[];
  final orderedHabits = [...habits]..sort((a, b) => a.id.compareTo(b.id));
  for (final habit in orderedHabits) {
    final pulsarPosition = seededPulsarPosition(
      habit.id,
      shape: shape,
      avoid: placedPulsars,
    );
    placedPulsars.add(pulsarPosition);
    final countsByDay = habitCompletionCountsByDay(
      completionsByHabit[habit.id] ?? const <HabitCompletion>[],
    );
    renderStars.add(
      ConstellationStar(
        entityId: habit.id,
        position: pulsarPosition,
        // A deleted pulsar keeps its scattered spot and becomes a dead
        // star, the same way a deleted star does — see [Habit.dead].
        kind: habit.dead ? StarKind.dead : StarKind.pulsar,
        lit: !habit.dead && isHabitLit(habit, countsByDay),
        label: habit.title,
        intensity: habit.intensity,
      ),
    );
  }

  return (stars: renderStars, edges: layout.edges);
}
