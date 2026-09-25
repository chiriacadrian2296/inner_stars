import 'dart:math' as math;
import 'dart:ui';

/// One star as the label layout sees it: where it sits on screen, how much
/// room its button (rings included) takes up, and how urgently it needs a
/// good spot for its label.
class MapNode {
  const MapNode({
    required this.id,
    required this.center,
    required this.radius,
    this.priority = 0,
  });

  /// Whatever the caller uses to tell its stars apart (an index into its own
  /// list) — the layout only hands it back.
  final int id;
  final Offset center;

  /// The button's outer radius, decoration rings included: nothing else may
  /// be placed inside it.
  final double radius;

  /// Higher goes first when the labels are laid out one by one, so the
  /// hardest-to-place stars get first pick of the free space.
  final double priority;
}

/// Where one label ended up, and the line that ties it to its star.
class LabelPlacement {
  const LabelPlacement({
    required this.id,
    required this.rect,
    required this.lineStart,
    required this.lineEnd,
    required this.horizontal,
    required this.candidate,
  });

  final int id;
  final Rect rect;

  /// The leader line's two ends: [lineStart] a little away from the star's
  /// outer ring, [lineEnd] a little short of the label's edge.
  final Offset lineStart;
  final Offset lineEnd;

  /// Whether the line runs out of the star sideways (the label then sits to
  /// its left/right) rather than up/down. Decides which way the S bends.
  final bool horizontal;

  /// Which of the candidate slots this is — fed back into the next layout
  /// (see [layoutConstellationLabels]'s `previous`) so a label doesn't hop
  /// between equally good spots while the zoom changes.
  final int candidate;

  /// The leader line: a cubic S that leaves the star and enters the label
  /// along the same axis, so it reads as a smooth "S" rather than a stick.
  Path get path {
    final path = Path()..moveTo(lineStart.dx, lineStart.dy);
    if (horizontal) {
      final half = (lineEnd.dx - lineStart.dx) / 2;
      path.cubicTo(
        lineStart.dx + half,
        lineStart.dy,
        lineEnd.dx - half,
        lineEnd.dy,
        lineEnd.dx,
        lineEnd.dy,
      );
    } else {
      final half = (lineEnd.dy - lineStart.dy) / 2;
      path.cubicTo(
        lineStart.dx,
        lineStart.dy + half,
        lineEnd.dx,
        lineEnd.dy - half,
        lineEnd.dx,
        lineEnd.dy,
      );
    }
    return path;
  }
}

class LabelLayout {
  const LabelLayout({
    required this.placements,
    required this.labelScale,
    required this.overlaps,
  });

  final Map<int, LabelPlacement> placements;

  /// Which of the tried label scales this layout was made at (1 unless the
  /// labels had to shrink to fit).
  final double labelScale;

  /// How many label/label or label/star overlaps are left. Zero means every
  /// label sits in clear space.
  final int overlaps;
}

const double _kStartGap = 5;
const double _kEndGap = 4;
const int _kAngles = 16;
const List<double> _kLengths = [22, 40, 62, 90, 130];

/// Places one label per node that has a size, in free space around its star.
///
/// A greedy point-feature label placement: every star tries [_kAngles] ×
/// [_kLengths] candidate spots and takes the cheapest one — a label sitting on
/// another label or on a star button is prohibitively expensive, one crossing
/// a constellation line or another leader is mildly so, and a spot pointing
/// away from the constellation's [anchor], close to its star, and where the
/// label already was is cheaper. A couple of refinement passes then re-place
/// each label with everyone else's final position known.
///
/// [labelSize] answers "how big is this star's label at this scale" (null: no
/// label — a nascent star). The whole thing is retried at each of
/// [labelScales] in turn until one leaves no overlap, so a crowded
/// constellation gets slightly smaller labels rather than piled-up ones.
///
/// Pure geometry in one shared coordinate space — no widgets, no zoom of its
/// own — so it's deterministic and easy to test.
LabelLayout layoutConstellationLabels({
  required List<MapNode> nodes,
  required Size? Function(int id, double labelScale) labelSize,
  List<(Offset, Offset)> edges = const [],
  Offset? anchor,
  Map<int, int> previous = const {},
  List<double> labelScales = const [1, 0.9, 0.8],
}) {
  LabelLayout? best;
  for (final scale in labelScales) {
    final layout = _layoutAtScale(
      nodes: nodes,
      labelSize: (id) => labelSize(id, scale),
      edges: edges,
      anchor: anchor,
      previous: previous,
      labelScale: scale,
    );
    if (best == null || layout.overlaps < best.overlaps) best = layout;
    if (layout.overlaps == 0) break;
  }
  return best ??
      const LabelLayout(placements: {}, labelScale: 1, overlaps: 0);
}

class _Candidate {
  const _Candidate(this.placement, this.length, this.outward);
  final LabelPlacement placement;
  final double length;

  /// 1 when pointing straight away from the constellation's center, -1 when
  /// straight into it.
  final double outward;
}

LabelLayout _layoutAtScale({
  required List<MapNode> nodes,
  required Size? Function(int id) labelSize,
  required List<(Offset, Offset)> edges,
  required Offset? anchor,
  required Map<int, int> previous,
  required double labelScale,
}) {
  final labeled = <MapNode>[];
  final sizes = <int, Size>{};
  for (final node in nodes) {
    final size = labelSize(node.id);
    if (size == null) continue;
    labeled.add(node);
    sizes[node.id] = size;
  }
  if (labeled.isEmpty) {
    return LabelLayout(
      placements: const {},
      labelScale: labelScale,
      overlaps: 0,
    );
  }
  labeled.sort((a, b) {
    final byPriority = b.priority.compareTo(a.priority);
    return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
  });

  final candidates = {
    for (final node in labeled)
      node.id: _candidatesFor(node, sizes[node.id]!, anchor),
  };
  final chosen = <int, _Candidate>{};

  // The first pass fills `chosen` one label at a time; the next two revisit
  // every label with the others already in place.
  for (var pass = 0; pass < 3; pass++) {
    for (final node in labeled) {
      chosen.remove(node.id);
      var bestCost = double.infinity;
      _Candidate? bestCandidate;
      for (final candidate in candidates[node.id]!) {
        final cost = _cost(
          candidate,
          node: node,
          nodes: nodes,
          chosen: chosen,
          edges: edges,
          previous: previous[node.id],
        );
        if (cost < bestCost) {
          bestCost = cost;
          bestCandidate = candidate;
        }
      }
      chosen[node.id] = bestCandidate!;
    }
  }

  var overlaps = 0;
  final placements = <int, LabelPlacement>{};
  for (final node in labeled) {
    final placement = chosen[node.id]!.placement;
    placements[node.id] = placement;
    for (final other in labeled) {
      if (other.id <= node.id) continue;
      if (placement.rect.overlaps(chosen[other.id]!.placement.rect)) {
        overlaps++;
      }
    }
    for (final other in nodes) {
      if (_rectHitsCircle(placement.rect, other.center, other.radius)) {
        overlaps++;
      }
    }
  }
  return LabelLayout(
    placements: placements,
    labelScale: labelScale,
    overlaps: overlaps,
  );
}

List<_Candidate> _candidatesFor(MapNode node, Size size, Offset? anchor) {
  var outwardDirection = Offset.zero;
  if (anchor != null) {
    final away = node.center - anchor;
    if (away.distance > 4) outwardDirection = away / away.distance;
  }
  final result = <_Candidate>[];
  var index = 0;
  for (final length in _kLengths) {
    for (var i = 0; i < _kAngles; i++) {
      final angle = 2 * math.pi * i / _kAngles;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = node.center + direction * (node.radius + _kStartGap);
      final end = start + direction * length;
      final horizontal = direction.dx.abs() >= direction.dy.abs();
      final Rect rect;
      if (horizontal) {
        final left = direction.dx > 0 ? end.dx + _kEndGap : end.dx - _kEndGap - size.width;
        rect = Rect.fromLTWH(left, end.dy - size.height / 2, size.width, size.height);
      } else {
        final top = direction.dy > 0 ? end.dy + _kEndGap : end.dy - _kEndGap - size.height;
        rect = Rect.fromLTWH(end.dx - size.width / 2, top, size.width, size.height);
      }
      result.add(
        _Candidate(
          LabelPlacement(
            id: node.id,
            rect: rect,
            lineStart: start,
            lineEnd: end,
            horizontal: horizontal,
            candidate: index++,
          ),
          length,
          direction.dx * outwardDirection.dx + direction.dy * outwardDirection.dy,
        ),
      );
    }
  }
  return result;
}

// Any of these dwarfs the soft terms below, so a label only ever sits on a
// label or a star button when there is genuinely nowhere else to go.
const double _kHardOverlap = 5000;
const double _kEdgeCrossing = 220;
const double _kLeaderCrossing = 260;
const double _kLeaderEdgeCrossing = 40;

double _cost(
  _Candidate candidate, {
  required MapNode node,
  required List<MapNode> nodes,
  required Map<int, _Candidate> chosen,
  required List<(Offset, Offset)> edges,
  required int? previous,
}) {
  final rect = candidate.placement.rect;
  final start = candidate.placement.lineStart;
  final end = candidate.placement.lineEnd;
  var cost = candidate.length * 0.6 - candidate.outward * 25;
  if (previous == candidate.placement.candidate) cost -= 20;

  for (final other in nodes) {
    if (_rectHitsCircle(rect, other.center, other.radius)) {
      cost += _kHardOverlap;
    }
    // The leader must not run through some other star's button either.
    if (other.id != node.id &&
        _segmentHitsCircle(start, end, other.center, other.radius)) {
      cost += _kHardOverlap / 2;
    }
  }
  for (final entry in chosen.entries) {
    final other = entry.value.placement;
    if (rect.overlaps(other.rect.inflate(2))) cost += _kHardOverlap;
    if (_segmentsCross(start, end, other.lineStart, other.lineEnd)) {
      cost += _kLeaderCrossing;
    }
    // ...nor a placed leader through this label.
    if (_segmentHitsRect(other.lineStart, other.lineEnd, rect)) {
      cost += _kLeaderCrossing;
    }
  }
  for (final (a, b) in edges) {
    if (_segmentHitsRect(a, b, rect)) cost += _kEdgeCrossing;
    if (_segmentsCross(start, end, a, b)) cost += _kLeaderEdgeCrossing;
  }
  return cost;
}

bool _rectHitsCircle(Rect rect, Offset center, double radius) {
  final nearestX = center.dx.clamp(rect.left, rect.right);
  final nearestY = center.dy.clamp(rect.top, rect.bottom);
  final dx = center.dx - nearestX;
  final dy = center.dy - nearestY;
  return dx * dx + dy * dy < radius * radius;
}

bool _segmentHitsCircle(Offset a, Offset b, Offset center, double radius) {
  final ab = b - a;
  final lengthSq = ab.distanceSquared;
  final t = lengthSq == 0
      ? 0.0
      : (((center - a).dx * ab.dx + (center - a).dy * ab.dy) / lengthSq).clamp(
          0.0,
          1.0,
        );
  final nearest = a + ab * t;
  return (center - nearest).distanceSquared < radius * radius;
}

double _orient(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
  final d1 = _orient(a, b, c);
  final d2 = _orient(a, b, d);
  final d3 = _orient(c, d, a);
  final d4 = _orient(c, d, b);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

bool _segmentHitsRect(Offset a, Offset b, Rect rect) {
  if (rect.contains(a) || rect.contains(b)) return true;
  final topLeft = rect.topLeft;
  final topRight = rect.topRight;
  final bottomLeft = rect.bottomLeft;
  final bottomRight = rect.bottomRight;
  return _segmentsCross(a, b, topLeft, topRight) ||
      _segmentsCross(a, b, topRight, bottomRight) ||
      _segmentsCross(a, b, bottomRight, bottomLeft) ||
      _segmentsCross(a, b, bottomLeft, topLeft);
}
