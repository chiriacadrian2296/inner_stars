import 'dart:math' as math;

import '../models/habit.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import 'constellation_shape.dart';
import 'custom_constellation_repository.dart';
import 'habit_repository.dart';
import 'star_repository.dart';

/// One page of the star reader: any kind of star it can show. Real stars
/// ([StarEntry] — lit, unlit or dead), pulsars ([PulsarEntry] — alive or
/// dead), and empty slots on a constellation's shape ([NascentEntry]) all
/// browse together, so prev/next walks the whole constellation.
sealed class ReaderEntry {
  const ReaderEntry();

  /// The project (constellation) this belongs to.
  int get projectId;

  /// Which slot on the shape this sits on (1-based), or null for a pulsar,
  /// which scatters around the shape instead of being part of it.
  int? get slot;

  /// A stable identity across refreshes.
  String get key;

  StarKind get kind;
}

class StarEntry extends ReaderEntry {
  const StarEntry(this.star);

  final Star star;

  @override
  int get projectId => star.projectId;

  @override
  int? get slot => star.slotSequence;

  @override
  String get key => 's${star.id}';

  @override
  StarKind get kind => star.kind;
}

class PulsarEntry extends ReaderEntry {
  const PulsarEntry(this.habit);

  final Habit habit;

  @override
  int get projectId => habit.projectId;

  @override
  int? get slot => null;

  @override
  String get key => 'p${habit.id}';

  /// A deleted pulsar is a dead star, same as everywhere else.
  @override
  StarKind get kind => habit.dead ? StarKind.dead : StarKind.pulsar;
}

class NascentEntry extends ReaderEntry {
  const NascentEntry({required this.projectId, required this.slot});

  @override
  final int projectId;

  @override
  final int slot;

  @override
  String get key => 'n$projectId-$slot';

  @override
  StarKind get kind => StarKind.nascent;
}

/// Wraps plain [stars] as reader entries — for the flows that only ever
/// browse real stars (search, the nightlight, the stats lists).
List<ReaderEntry> starEntries(Iterable<Star> stars) => [
  for (final star in stars) StarEntry(star),
];

/// Everything in one constellation, in the order the reader walks it: every
/// slot on the shape from first to last (the star sitting on it, or a
/// nascent entry where it's still empty), then the pulsars.
///
/// Mirrors `buildConstellationRenderStars`' own slot rules: the shape has at
/// least its own point count of slots, more only as far as the highest slot
/// a star actually occupies, and only the shape's own slots go nascent.
List<ReaderEntry> buildReaderEntries({
  required int projectId,
  required List<Star> stars,
  required List<Habit> habits,
  required ConstellationShape? shape,
}) {
  final bySlot = {for (final star in stars) star.slotSequence: star};
  final shapeSlots = shape?.points.length ?? 0;
  final highest = stars.fold<int>(
    0,
    (max, s) => math.max(max, s.slotSequence),
  );
  final entries = <ReaderEntry>[];
  for (var slot = 1; slot <= math.max(shapeSlots, highest); slot++) {
    final star = bySlot[slot];
    if (star != null) {
      entries.add(StarEntry(star));
    } else if (slot <= shapeSlots) {
      entries.add(NascentEntry(projectId: projectId, slot: slot));
    }
  }
  for (final habit in habits) {
    entries.add(PulsarEntry(habit));
  }
  return entries;
}

/// [buildReaderEntries] straight from the repositories, for one [project] —
/// also what a reader calls to refresh itself after something changed.
List<ReaderEntry> projectReaderEntries({
  required Project project,
  required StarRepository starRepository,
  required HabitRepository habitRepository,
  required StarsShapeRepository starsShapeRepository,
}) {
  final shapeId = project.starsShapeId;
  return buildReaderEntries(
    projectId: project.id,
    stars: starRepository.getAllForProject(project.id),
    habits: habitRepository.getAllForProject(project.id),
    shape: shapeId == null
        ? null
        : starsShapeRepository.getById(shapeId)?.shape,
  );
}
