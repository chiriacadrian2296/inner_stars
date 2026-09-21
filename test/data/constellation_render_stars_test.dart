import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_layout.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_kind.dart';

/// A tiny 3-point path — small enough that every slot can be accounted for
/// by hand in the expectations below.
const _shape = ConstellationShape(
  points: [Offset(0.1, 0.5), Offset(0.5, 0.2), Offset(0.9, 0.5)],
  edges: [(0, 1), (1, 2)],
);

Star _star({
  required int id,
  required int slotSequence,
  DateTime? achievedDate,
  bool dead = false,
}) {
  return Star(
    id: id,
    projectId: 1,
    slotSequence: slotSequence,
    title: 'Star $id',
    createdAt: DateTime(2024, 1, 1),
    achievedDate: achievedDate,
    intensity: achievedDate == null ? null : 3,
    dead: dead,
  );
}

Habit _habit({required int id, bool dead = false}) {
  return Habit(
    id: id,
    projectId: 1,
    title: 'Pulsar $id',
    createdAt: DateTime(2024, 1, 1),
    dead: dead,
  );
}

void main() {
  group('buildConstellationRenderStars', () {
    test('an empty constellation is still drawn whole — one nascent star per '
        'slot, and every edge', () {
      final built = buildConstellationRenderStars(
        stars: const [],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );

      expect(built.stars, hasLength(3));
      expect(built.stars.every((s) => s.kind == StarKind.nascent), isTrue);
      expect(built.stars.map((s) => s.slotSequence), [1, 2, 3]);
      expect(built.stars.map((s) => s.position), _shape.points);
      expect(built.edges, _shape.edges);
    });

    test('a star sits on its own slotSequence, and only the slots left over '
        'stay nascent', () {
      final built = buildConstellationRenderStars(
        // Deliberately the middle slot, and deliberately not the first star
        // created — placement follows the slot, never list order.
        stars: [_star(id: 7, slotSequence: 2)],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );

      final placed = built.stars.singleWhere((s) => s.entityId == 7);
      expect(placed.kind, StarKind.unlit);
      expect(placed.position, _shape.points[1]);

      final nascent = built.stars.where((s) => s.kind == StarKind.nascent);
      expect(nascent.map((s) => s.slotSequence), [1, 3]);
    });

    test('configuring a nascent slot never moves the stars already placed', () {
      final before = buildConstellationRenderStars(
        stars: [_star(id: 7, slotSequence: 2)],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );
      final after = buildConstellationRenderStars(
        stars: [
          _star(id: 7, slotSequence: 2),
          _star(id: 9, slotSequence: 1, achievedDate: DateTime(2024, 2, 1)),
        ],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );

      expect(
        after.stars.singleWhere((s) => s.entityId == 7).position,
        before.stars.singleWhere((s) => s.entityId == 7).position,
      );
    });

    test('lit, unlit and dead stars each report their own kind', () {
      final built = buildConstellationRenderStars(
        stars: [
          _star(id: 1, slotSequence: 1, achievedDate: DateTime(2024, 2, 1)),
          _star(id: 2, slotSequence: 2),
          _star(id: 3, slotSequence: 3, dead: true),
        ],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );

      expect(
        {for (final s in built.stars) s.entityId: s.kind},
        {1: StarKind.lit, 2: StarKind.unlit, 3: StarKind.dead},
      );
      expect(built.stars.any((s) => s.kind == StarKind.nascent), isFalse);
    });

    test('a pulsar scatters off the shape — no slot, so it can never shift '
        'the shape\'s own edge indexing', () {
      final built = buildConstellationRenderStars(
        stars: const [],
        habits: [_habit(id: 42)],
        shape: _shape,
        completionsByHabit: const {},
      );

      final pulsar = built.stars.singleWhere((s) => s.entityId == 42);
      expect(pulsar.kind, StarKind.pulsar);
      expect(pulsar.slotSequence, isNull);
      // Unbroken today, so it isn't burning.
      expect(pulsar.lit, isFalse);
    });

    test('a deleted pulsar becomes a dead star that still keeps no slot', () {
      final built = buildConstellationRenderStars(
        stars: const [],
        habits: [_habit(id: 42, dead: true)],
        shape: _shape,
        completionsByHabit: const {},
      );

      final pulsar = built.stars.singleWhere((s) => s.entityId == 42);
      expect(pulsar.kind, StarKind.dead);
      expect(pulsar.lit, isFalse);
      expect(pulsar.slotSequence, isNull);
    });

    test('a slot past the shape\'s own points grows the graph without leaving '
        'a hole behind it', () {
      final built = buildConstellationRenderStars(
        stars: [_star(id: 1, slotSequence: 5)],
        habits: const [],
        shape: _shape,
        completionsByHabit: const {},
      );

      // Slots 1-3 are the shape's own and stay nascent; 4 exists only
      // because the graph had to grow to reach 5, so nothing is drawn there.
      expect(
        built.stars.where((s) => s.kind == StarKind.nascent).map(
          (s) => s.slotSequence,
        ),
        [1, 2, 3],
      );
      expect(built.stars.singleWhere((s) => s.entityId == 1).slotSequence, 5);
      expect(built.edges.length, greaterThan(_shape.edges.length));
    });
  });
}
