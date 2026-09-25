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
  return Offset(0.5 + radius * math.cos(angle), 0.5 + radius * math.sin(angle));
}

/// Deterministic placement for a star beyond [maxChainedStars] — vanishingly
/// rare, but must never crash or lose a star. Seeded by the star's own
/// immutable id (never by its position in the list), so a star's position
/// can't shift if the list is ever reordered.
Offset seededOverflowPosition(int seed) =>
    _seededScatter(seed, minRadius: 0.55, maxRadius: 1.0);

/// Deterministic placement for a pulsar's own small, scattered star — a
/// closer band that overlaps the constellation's own footprint (pulsars sit
/// "around/inside/outside" the shape, not past its edge like overflow
/// stars), seeded by the habit's own immutable id.
Offset seededPulsarPosition(int seed) =>
    _seededScatter(seed, minRadius: 0.15, maxRadius: 0.65);

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

  for (final habit in habits) {
    final countsByDay = habitCompletionCountsByDay(
      completionsByHabit[habit.id] ?? const <HabitCompletion>[],
    );
    renderStars.add(
      ConstellationStar(
        entityId: habit.id,
        position: seededPulsarPosition(habit.id),
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
