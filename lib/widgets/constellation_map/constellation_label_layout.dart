import 'dart:math' as math;
import 'dart:ui';

/// One star as the label layout sees it: where it sits on screen, how much
/// room its button and visual effects take up, and how urgently it needs a
/// good spot for its label.
class MapNode {
  const MapNode({
    required this.id,
    required this.center,
    required this.radius,
    this.leaderRadius,
    this.priority = 0,
  });

  /// Whatever the caller uses to tell its stars apart (an index into its own
  /// list) — the layout only hands it back.
  final int id;
  final Offset center;

  /// The visual exclusion radius: nothing else may be placed inside it.
  final double radius;

  /// The radius a leader clears when leaving this node. It may be smaller
  /// than [radius] when the latter includes a decorative glow.
  final double? leaderRadius;

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

/// The editor's invisible square grid, expressed in layout coordinates.
/// Leader ends use its vertices when available, keeping the whole map on the
/// same spatial rhythm as the shape the person drew.
class LabelGrid {
  const LabelGrid({required this.origin, required this.spacing});

  final Offset origin;
  final double spacing;
}

const double _kStartGap = 4;
const double _kEndGap = 3;
const int _kAngles = 24;
// Short first choices keep annotations visually attached to their stars.
// The later candidates still let crowded constellations resolve cleanly.
const List<double> _kLengths = [14, 26, 42, 64, 92, 130, 180];

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
  double? symmetryAxisX,
  LabelGrid? grid,
  Map<int, int> previous = const {},
  Map<int, int> fixedCandidates = const {},
  List<double> labelScales = const [1, 0.9, 0.8],
  double leaderLengthScale = 1,
}) {
  LabelLayout? best;
  for (final scale in labelScales) {
    final layout = _layoutAtScale(
      nodes: nodes,
      labelSize: (id) => labelSize(id, scale),
      edges: edges,
      anchor: anchor,
      symmetryAxisX: symmetryAxisX ?? anchor?.dx,
      grid: grid,
      previous: previous,
      fixedCandidates: fixedCandidates,
      labelScale: scale,
      leaderLengthScale: leaderLengthScale * scale,
    );
    if (best == null || layout.overlaps < best.overlaps) best = layout;
    if (layout.overlaps == 0) break;
  }
  return best ??
      const LabelLayout(placements: {}, labelScale: 1, overlaps: 0);
}

class _Candidate {
  const _Candidate(this.placement, this.length, this.outward, this.direction);
  final LabelPlacement placement;
  final double length;
  final Offset direction;

  /// 1 when pointing straight away from the constellation's center, -1 when
  /// straight into it.
  final double outward;
}

LabelLayout _layoutAtScale({
  required List<MapNode> nodes,
  required Size? Function(int id) labelSize,
  required List<(Offset, Offset)> edges,
  required Offset? anchor,
  required double? symmetryAxisX,
  required LabelGrid? grid,
  required Map<int, int> previous,
  required Map<int, int> fixedCandidates,
  required double labelScale,
  required double leaderLengthScale,
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
      node.id: _candidatesFor(
        node,
        sizes[node.id]!,
        anchor,
        leaderLengthScale,
        grid,
        nodes,
      ),
  };
  // This is intentionally a global search, rather than assigning a card and
  // hoping later cards can work around it. A choice that looks best locally
  // may consume the only nearby slot of another star. Symmetric pairs are
  // represented as one atomic choice, so they stay mirrored unless that makes
  // a collision-free complete composition impossible.
  final chosen = _solveConstellationLabels(
    nodes: labeled,
    allNodes: nodes,
    candidates: candidates,
    edges: edges,
    symmetryAxisX: symmetryAxisX,
    fixedCandidates: fixedCandidates,
    previous: previous,
  );

  var overlaps = 0;
  final placements = <int, LabelPlacement>{};
  for (final node in labeled) {
    final selected = chosen[node.id];
    if (selected == null) continue;
    final placement = selected.placement;
    placements[node.id] = placement;
    for (final other in labeled) {
      if (other.id <= node.id) continue;
      final otherPlacement = chosen[other.id]?.placement;
      if (otherPlacement != null && placement.rect.overlaps(otherPlacement.rect)) {
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

List<_Candidate> _candidatesFor(
  MapNode node,
  Size size,
  Offset? anchor,
  double leaderLengthScale,
  LabelGrid? grid,
  List<MapNode> nodes,
) {
  var outwardDirection = Offset.zero;
  if (anchor != null) {
    final away = node.center - anchor;
    if (away.distance > 4) outwardDirection = away / away.distance;
  }
  if (grid != null && grid.spacing > 0) {
    return _gridCandidatesFor(node, size, outwardDirection, grid, nodes);
  }
  final result = <_Candidate>[];
  var index = 0;
  for (final length in _kLengths) {
    final scaledLength = length * leaderLengthScale;
    for (var i = 0; i < _kAngles; i++) {
      final angle = 2 * math.pi * i / _kAngles;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = node.center +
          direction * ((node.leaderRadius ?? node.radius) + _kStartGap);
      final end = start + direction * scaledLength;
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
          scaledLength,
          direction.dx * outwardDirection.dx + direction.dy * outwardDirection.dy,
          direction,
        ),
      );
    }
  }
  return result;
}

class _PlacementOption {
  const _PlacementOption(this.candidates, this.cost);

  final Map<int, _Candidate> candidates;
  final double cost;
}

class _PlacementGroup {
  const _PlacementGroup(this.options);

  final List<_PlacementOption> options;
}

class _SearchState {
  const _SearchState(this.chosen, this.cost);

  final Map<int, _Candidate> chosen;
  final double cost;
}

/// Finds a complete diagram with a bounded beam search. It is deliberately
/// not a greedy optimiser: every kept state is a different partial diagram,
/// which allows an earlier card to move aside if that frees a much nearer slot
/// for a later card.
Map<int, _Candidate> _solveConstellationLabels({
  required List<MapNode> nodes,
  required List<MapNode> allNodes,
  required Map<int, List<_Candidate>> candidates,
  required List<(Offset, Offset)> edges,
  required double? symmetryAxisX,
  required Map<int, int> fixedCandidates,
  required Map<int, int> previous,
}) {
  final pairs = _verticalMirrorPairs(nodes, symmetryAxisX);
  final groups = <_PlacementGroup>[];
  final used = <int>{};

  for (final node in nodes) {
    if (!used.add(node.id)) continue;
    final partnerId = pairs[node.id];
    MapNode? partner;
    if (partnerId != null) {
      for (final other in nodes) {
        if (other.id == partnerId) {
          partner = other;
          break;
        }
      }
    }
    if (partner != null && symmetryAxisX != null) {
      used.add(partner.id);
      final paired = _symmetricOptions(
        node,
        partner,
        candidates[node.id]!,
        candidates[partner.id]!,
        allNodes,
        symmetryAxisX,
      );
      if (paired.isNotEmpty) {
        groups.add(_PlacementGroup(paired));
        continue;
      }
      // Symmetry never authorizes an overlap. If the shape offers no clear
      // mirrored alternatives, solve the two labels independently.
      groups.add(_singleGroup(node, candidates[node.id]!, allNodes,
          fixedCandidates[node.id], previous[node.id]));
      groups.add(_singleGroup(partner, candidates[partner.id]!, allNodes,
          fixedCandidates[partner.id], previous[partner.id]));
      continue;
    }
    groups.add(_singleGroup(node, candidates[node.id]!, allNodes,
        fixedCandidates[node.id], previous[node.id]));
  }

  // The fewest alternatives first makes the beam spend its breadth on the
  // hard areas of a constellation instead of wasting it on unconstrained
  // outer stars.
  groups.sort((a, b) => a.options.length.compareTo(b.options.length));
  var states = <_SearchState>[const _SearchState({}, 0)];
  for (final group in groups) {
    final next = <_SearchState>[];
    for (final state in states) {
      for (final option in group.options) {
        if (_optionConflicts(option, state.chosen)) continue;
        final extra = _transitionCost(option, state.chosen, edges);
        next.add(_SearchState(
          {...state.chosen, ...option.candidates},
          state.cost + option.cost + extra,
        ));
      }
    }
    if (next.isEmpty) {
      // With the long grid lanes this should only occur for a pathological
      // input. Keep the best partial result rather than ever placing a card
      // over a star; the next scale can then offer more room.
      break;
    }
    next.sort((a, b) => a.cost.compareTo(b.cost));
    states = next.take(192).toList();
  }
  states.sort((a, b) => b.chosen.length != a.chosen.length
      ? b.chosen.length.compareTo(a.chosen.length)
      : a.cost.compareTo(b.cost));
  return states.first.chosen;
}

_PlacementGroup _singleGroup(
  MapNode node,
  List<_Candidate> raw,
  List<MapNode> allNodes,
  int? fixedCandidate,
  int? previousCandidate,
) {
  var clear = raw.where((candidate) => !_cardHitsAnyStar(candidate, allNodes));
  if (fixedCandidate != null) {
    final fixed = clear.where(
        (candidate) => candidate.placement.candidate == fixedCandidate);
    if (fixed.isNotEmpty) clear = fixed;
  }
  final options = clear
      .map((candidate) => _PlacementOption(
            {node.id: candidate},
            _candidateBaseCost(candidate, previousCandidate),
          ))
      .toList()
    ..sort((a, b) => a.cost.compareTo(b.cost));
  return _PlacementGroup(options.take(72).toList());
}

List<_PlacementOption> _symmetricOptions(
  MapNode first,
  MapNode second,
  List<_Candidate> firstRaw,
  List<_Candidate> secondRaw,
  List<MapNode> allNodes,
  double axisX,
) {
  final firstClear = firstRaw
      .where((candidate) => !_cardHitsAnyStar(candidate, allNodes))
      .take(96);
  final secondClear = secondRaw
      .where((candidate) => !_cardHitsAnyStar(candidate, allNodes))
      .take(96)
      .toList();
  final options = <_PlacementOption>[];
  for (final a in firstClear) {
    for (final b in secondClear) {
      if (!_areMirrored(a.placement, b.placement, axisX)) continue;
      if (a.placement.rect.overlaps(b.placement.rect.inflate(2))) continue;
      options.add(_PlacementOption(
        {first.id: a, second.id: b},
        _candidateBaseCost(a, null) + _candidateBaseCost(b, null),
      ));
    }
  }
  options.sort((a, b) => a.cost.compareTo(b.cost));
  return options.take(96).toList();
}

double _candidateBaseCost(_Candidate candidate, int? previousCandidate) {
  var cost = candidate.length - candidate.outward * 14;
  if (previousCandidate == candidate.placement.candidate) cost -= 3;
  return cost;
}

bool _optionConflicts(
  _PlacementOption option,
  Map<int, _Candidate> chosen,
) {
  final values = option.candidates.values.toList();
  for (var i = 0; i < values.length; i++) {
    for (var j = i + 1; j < values.length; j++) {
      if (values[i].placement.rect.overlaps(values[j].placement.rect.inflate(2))) {
        return true;
      }
    }
    for (final other in chosen.values) {
      if (values[i].placement.rect.overlaps(other.placement.rect.inflate(2))) {
        return true;
      }
    }
  }
  return false;
}

double _transitionCost(
  _PlacementOption option,
  Map<int, _Candidate> chosen,
  List<(Offset, Offset)> edges,
) {
  var cost = 0.0;
  for (final candidate in option.candidates.values) {
    for (final other in chosen.values) {
      if (_segmentsCross(
        candidate.placement.lineStart,
        candidate.placement.lineEnd,
        other.placement.lineStart,
        other.placement.lineEnd,
      )) {
        cost += 22;
      }
      if (_segmentHitsRect(
        other.placement.lineStart,
        other.placement.lineEnd,
        candidate.placement.rect,
      )) {
        cost += 36;
      }
    }
    for (final (a, b) in edges) {
      if (_segmentHitsRect(a, b, candidate.placement.rect)) cost += 16;
      if (_segmentsCross(candidate.placement.lineStart, candidate.placement.lineEnd, a, b)) {
        cost += 4;
      }
    }
  }
  return cost;
}

bool _areMirrored(LabelPlacement a, LabelPlacement b, double axisX) {
  const tolerance = 0.01;
  bool same(double first, double second) => (first - second).abs() <= tolerance;
  return same(a.lineStart.dx + b.lineStart.dx, 2 * axisX) &&
      same(a.lineStart.dy, b.lineStart.dy) &&
      same(a.lineEnd.dx + b.lineEnd.dx, 2 * axisX) &&
      same(a.lineEnd.dy, b.lineEnd.dy) &&
      same(a.rect.left + b.rect.right, 2 * axisX) &&
      same(a.rect.right + b.rect.left, 2 * axisX) &&
      same(a.rect.top, b.rect.top) &&
      same(a.rect.bottom, b.rect.bottom);
}

bool _cardHitsAnyStar(_Candidate candidate, List<MapNode> nodes) => nodes.any(
  (node) => _rectHitsCircle(candidate.placement.rect, node.center, node.radius),
);

/// Scores complete candidate assignments. A collision dominates everything;
/// once the diagram is clear, the total leader length decides which valid
/// composition uses the constellation's surrounding space most compactly.
double _layoutQuality(
  Map<int, _Candidate> chosen,
  List<MapNode> nodes,
  int labelCount,
) {
  var collisions = labelCount - chosen.length;
  final values = chosen.values.toList();
  for (var i = 0; i < values.length; i++) {
    final rect = values[i].placement.rect;
    for (var j = i + 1; j < values.length; j++) {
      if (rect.overlaps(values[j].placement.rect.inflate(2))) collisions++;
    }
    for (final node in nodes) {
      if (_rectHitsCircle(rect, node.center, node.radius)) collisions++;
    }
  }
  final length = values.fold<double>(0, (sum, candidate) => sum + candidate.length);
  return collisions * 1000000 + length;
}

List<_Candidate> _gridCandidatesFor(
  MapNode node,
  Size size,
  Offset outwardDirection,
  LabelGrid grid,
  List<MapNode> nodes,
) {
  final candidates = <_Candidate>[];
  final column = ((node.center.dx - grid.origin.dx) / grid.spacing).round();
  final row = ((node.center.dy - grid.origin.dy) / grid.spacing).round();
  var index = 0;
  void add(int dx, int dy) {
    if (dx == 0 && dy == 0) return;
    final end = Offset(
      grid.origin.dx + (column + dx) * grid.spacing,
      grid.origin.dy + (row + dy) * grid.spacing,
    );
    final fromNode = end - node.center;
    final distance = fromNode.distance;
    final clearance = (node.leaderRadius ?? node.radius) + _kStartGap;
    if (distance <= clearance) return;
    final direction = fromNode / distance;
    final start = node.center + direction * clearance;
    final horizontal = direction.dx.abs() >= direction.dy.abs();
    final Rect rect;
    if (horizontal) {
      final left = direction.dx > 0
          ? end.dx + _kEndGap
          : end.dx - _kEndGap - size.width;
      rect = Rect.fromLTWH(
        left,
        end.dy - size.height / 2,
        size.width,
        size.height,
      );
    } else {
      final top = direction.dy > 0
          ? end.dy + _kEndGap
          : end.dy - _kEndGap - size.height;
      rect = Rect.fromLTWH(
        end.dx - size.width / 2,
        top,
        size.width,
        size.height,
      );
    }
    candidates.add(
      _Candidate(
        LabelPlacement(
          id: node.id,
          rect: rect,
          lineStart: start,
          lineEnd: end,
          horizontal: horizontal,
          candidate: index++,
        ),
        (end - start).distance,
        direction.dx * outwardDirection.dx + direction.dy * outwardDirection.dy,
        direction,
      ),
    );
  }

  // Thoroughly search the nearby cells first. Beyond that, add long-range
  // cardinal and diagonal lanes: these give every label an escape route out
  // of a dense constellation without producing an expensive full grid.
  for (var dy = -6; dy <= 6; dy++) {
    for (var dx = -6; dx <= 6; dx++) {
      add(dx, dy);
    }
  }
  final farthestNode = nodes
      .map((other) => (other.center - node.center).distance / grid.spacing)
      .fold(0.0, math.max)
      .ceil();
  // Carry every lane beyond the whole graph, plus a generous card margin.
  // At least one of these candidates is necessarily clear of every star.
  final maxDistance = math.max(80, farthestNode + 12);
  for (var distance = 7; distance <= maxDistance; distance++) {
    add(distance, 0);
    add(-distance, 0);
    add(0, distance);
    add(0, -distance);
    add(distance, distance);
    add(distance, -distance);
    add(-distance, distance);
    add(-distance, -distance);
  }
  candidates.sort((a, b) => a.length.compareTo(b.length));
  return candidates;
}

const double _kMirrorDirectionPenalty = 220;
const double _kMirrorLengthPenalty = 8;
const double _kAxisHorizontalPenalty = 18;

/// Associates labels whose nodes are reflections across the anchor's vertical
/// axis. The tolerance is deliberately tied to a node's visual radius: exact
/// grid mirrors match, while merely nearby stars do not get forced together.
Map<int, int> _verticalMirrorPairs(List<MapNode> nodes, double? axisX) {
  if (axisX == null) return const {};
  final pairs = <int, int>{};
  for (final node in nodes) {
    if (pairs.containsKey(node.id) || _isOnVerticalAxis(node, axisX)) continue;
    final reflected = Offset(2 * axisX - node.center.dx, node.center.dy);
    final tolerance = math.max(3, node.radius * 0.25);
    MapNode? best;
    var bestDistance = double.infinity;
    for (final other in nodes) {
      if (other.id == node.id || pairs.containsKey(other.id)) continue;
      final distance = (other.center - reflected).distance;
      if (distance <= tolerance && distance < bestDistance) {
        best = other;
        bestDistance = distance;
      }
    }
    if (best != null) {
      pairs[node.id] = best.id;
      pairs[best.id] = node.id;
    }
  }
  return pairs;
}

bool _isOnVerticalAxis(MapNode node, double? axisX) {
  if (axisX == null) return false;
  return (node.center.dx - axisX).abs() <= math.max(3, node.radius * 0.25);
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
