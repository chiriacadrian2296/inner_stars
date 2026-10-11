import 'package:flutter/material.dart';

/// Renders the in-progress shape inside `StarsShapeEditorScreen`: plain
/// dots and connecting lines, with a ring around whichever point is
/// currently armed (about to be connected) or being dragged. Deliberately
/// not a reuse of `ConstellationPainter` — that one is tuned for the
/// read-only viewer's lit/dim/dead/habit sparkle-and-glow states via
/// `drawAtlas`, a poor fit for "always-visible plain point + live drag"
/// editing semantics.
///
/// Unlike [ConstellationPainter], [points] are plain canvas-pixel
/// coordinates, not normalized 0..1 — the editor works directly in its own
/// fixed canvas space and only normalizes once, at save time.
class ConstellationEditorPainter extends CustomPainter {
  const ConstellationEditorPainter({
    required this.points,
    required this.edges,
    required this.highlightedIndex,
    required this.pointColor,
    required this.highlightColor,
    required this.lineColor,
    this.pointRadius = 6.0,
    this.ringRadius = 11.0,
    this.lineWidth = 1.5,
  });

  final List<Offset> points;
  final List<(int, int)> edges;
  final int? highlightedIndex;
  final Color pointColor;
  final Color highlightColor;
  final Color lineColor;

  /// Defaults tuned for the full-size editor canvas. Small preview
  /// thumbnails (see `_StarsShapeOption` in `new_project_screen.dart`)
  /// pass a smaller [pointRadius] — otherwise, with several stars packed
  /// into ~100 logical pixels, the dots themselves overlap each other and
  /// hide the connecting lines between them.
  final double pointRadius;
  final double ringRadius;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;
    for (final (a, b) in edges) {
      if (a >= points.length || b >= points.length) continue;
      canvas.drawLine(points[a], points[b], linePaint);
    }

    final pointPaint = Paint()..color = pointColor;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], pointRadius, pointPaint);
    }

    final highlighted = highlightedIndex;
    if (highlighted != null && highlighted < points.length) {
      final ringPaint = Paint()
        ..color = highlightColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(points[highlighted], ringRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationEditorPainter oldDelegate) {
    return points != oldDelegate.points ||
        edges != oldDelegate.edges ||
        highlightedIndex != oldDelegate.highlightedIndex ||
        pointColor != oldDelegate.pointColor ||
        highlightColor != oldDelegate.highlightColor ||
        lineColor != oldDelegate.lineColor ||
        pointRadius != oldDelegate.pointRadius ||
        lineWidth != oldDelegate.lineWidth ||
        ringRadius != oldDelegate.ringRadius;
  }
}

/// Finds the point nearest [localPosition], within [hitRadius] logical
/// pixels — the editor's own hit-testing, working directly in canvas-pixel
/// space (no normalized-to-canvas conversion needed, unlike the viewer's
/// `hitTestStar`).
int? hitTestEditorPoint(
  Offset localPosition,
  List<Offset> points, {
  double hitRadius = 28,
}) {
  int? closest;
  var closestDistanceSq = hitRadius * hitRadius;
  for (var i = 0; i < points.length; i++) {
    final distanceSq = (points[i] - localPosition).distanceSquared;
    if (distanceSq < closestDistanceSq) {
      closestDistanceSq = distanceSq;
      closest = i;
    }
  }
  return closest;
}

/// Rounds [position] to the nearest vertex of a square grid [spacing]
/// pixels apart — the editor's snap-to-grid behavior, factored out as a
/// plain pure function so it's unit-testable without pumping a widget.
/// [spacing] of 0 or less is treated as "no grid" and returns [position]
/// unchanged, rather than dividing by zero.
Offset snapToGrid(Offset position, double spacing) {
  if (spacing <= 0) return position;
  return Offset(
    (position.dx / spacing).round() * spacing,
    (position.dy / spacing).round() * spacing,
  );
}

/// Removes the point at [index] from [points], along with every edge that
/// referenced it, and shifts every remaining edge endpoint above [index]
/// down by one so edge indices stay valid — [ConstellationShape.edges] are
/// positional indices into [ConstellationShape.points], not stable ids, so
/// deleting a point always requires reindexing whatever's left. Returns a
/// new `(points, edges)` pair rather than mutating in place, so it's a plain
/// pure function callers can unit-test without pumping a widget.
(List<Offset>, List<(int, int)>) removeEditorPoint(
  List<Offset> points,
  List<(int, int)> edges,
  int index,
) {
  final newPoints = List<Offset>.from(points)..removeAt(index);
  final newEdges = <(int, int)>[];
  for (final (a, b) in edges) {
    if (a == index || b == index) continue;
    newEdges.add((a > index ? a - 1 : a, b > index ? b - 1 : b));
  }
  return (newPoints, newEdges);
}

/// Normalizes raw canvas-pixel [points] into the 0..1 box every
/// [ConstellationShape] is stored in — scales to fit the longest axis with
/// [pad] fractional margin on every side, then centers. A direct
/// transliteration of `normalize()` in
/// `tools/constellation-astralarium/from_astralarium.py` (which does the
/// same thing in a 0..100 box with an absolute-pixel `pad`), reusing the
/// same "scale to fit, then re-center" convention the rest of the
/// constellation-shape pipeline already relies on.
List<Offset> normalizeEditorPoints(List<Offset> points, {double pad = 0.1}) {
  if (points.isEmpty) return const [];

  var minX = points.first.dx, maxX = points.first.dx;
  var minY = points.first.dy, maxY = points.first.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }

  final width = maxX - minX == 0 ? 1.0 : maxX - minX;
  final height = maxY - minY == 0 ? 1.0 : maxY - minY;
  final scale = (1.0 - 2 * pad) / (width > height ? width : height);
  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;

  return points
      .map(
        (p) => Offset(
          0.5 + (p.dx - centerX) * scale,
          0.5 + (p.dy - centerY) * scale,
        ),
      )
      .toList();
}
