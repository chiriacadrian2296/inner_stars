import 'dart:math' as math;
import 'dart:ui';

import '../constellation_painter.dart';

/// Nudges the scattered stars — pulsars, alive or dead, the ones sitting on
/// no slot — apart from everything else, so two round buttons never sit on
/// top of each other.
///
/// A pulsar's home is a seeded random point (`seededPulsarPosition`), which
/// can land right on a shape star or on another pulsar; that was harmless
/// when both were a few pixels of light, but a button hides whatever is under
/// it. Slotted stars never move (their place *is* the shape); pulsars are
/// pushed until they clear each other by [minSeparation] canvas pixels.
/// Deterministic: the same input always gives the same output, and a pulsar
/// that's already clear of everything isn't touched at all.
List<ConstellationStar> spreadScatteredStars(
  List<ConstellationStar> stars, {
  required Size canvasSize,
  required double minSeparation,
}) {
  final points = [
    for (final star in stars)
      Offset(
        star.position.dx * canvasSize.width,
        star.position.dy * canvasSize.height,
      ),
  ];
  final movable = [
    for (var i = 0; i < stars.length; i++)
      if (stars[i].slotSequence == null) i,
  ];
  if (movable.isEmpty || minSeparation <= 0) return stars;

  var moved = false;
  for (var pass = 0; pass < 60; pass++) {
    var changed = false;
    for (final i in movable) {
      for (var j = 0; j < stars.length; j++) {
        if (i == j) continue;
        var delta = points[i] - points[j];
        var distance = delta.distance;
        if (distance >= minSeparation) continue;
        if (distance < 0.001) {
          // Exactly on top of each other: pick a direction from the stars'
          // own ids so the result is still deterministic.
          final angle = (stars[i].entityId * 2.399963) % (2 * math.pi);
          delta = Offset(math.cos(angle), math.sin(angle));
          distance = 1;
        }
        // A fixed star can't give way, so the pulsar takes the whole push;
        // between two pulsars each takes half.
        final share = stars[j].slotSequence == null ? 0.5 : 1.0;
        final push = (minSeparation - distance) * share;
        points[i] += delta / delta.distance * push;
        changed = true;
        moved = true;
      }
    }
    if (!changed) break;
  }
  if (!moved) return stars;

  return [
    for (var i = 0; i < stars.length; i++)
      if (stars[i].slotSequence != null)
        stars[i]
      else
        ConstellationStar(
          entityId: stars[i].entityId,
          position: Offset(
            points[i].dx / canvasSize.width,
            points[i].dy / canvasSize.height,
          ),
          kind: stars[i].kind,
          lit: stars[i].lit,
          label: stars[i].label,
          slotSequence: stars[i].slotSequence,
          intensity: stars[i].intensity,
          photoPath: stars[i].photoPath,
        ),
  ];
}
