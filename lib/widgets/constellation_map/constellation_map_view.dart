import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/star_kind.dart';
import '../../theme/app_colors.dart';
import '../constellation_painter.dart';
import '../intensity_dots.dart';
import '../photo_image.dart';
import '../star_glyph.dart';
import 'constellation_label_layout.dart';

// Font size and box of a label at zoom-neutral scale; both then grow/shrink
// with the view's own [_uiScale] and the layout's label scale.
const double _kLabelFontSize = 12;
const double _kLabelMaxWidth = 116;
const double _kLabelPadX = 8;
const double _kLabelPadY = 4;

/// The one thickness every white line on the map shares: the constellation's
/// own lines, the ring around each star, the leaders and the labels' borders,
/// at any zoom.
const double _kLineWidth = 2.5;

/// One constellation as a map: every star a round, self-explaining button
/// (its kind's icon, its intensity as dots and — for a stronger one — as
/// concentric rings), each tied by a smooth S-shaped line to a label with its
/// title, laid out so nothing sits on top of anything else.
///
/// The map pans/zooms with the shared [transformation], driven by this
/// widget's own gestures rather than an `InteractiveViewer`, so it can move
/// like the Sky does: a drag keeps the point you grabbed under your finger,
/// a flick glides to a stop, a pinch or the wheel zooms toward where you are
/// — and the map can be carried freely anywhere so long as at least one star
/// stays on screen. Everything visible is drawn in *screen space* by an overlay
/// underneath that reads the same matrix, so buttons and text keep a readable
/// size at any zoom instead of shrinking with the canvas — they only scale a
/// little (see [_uiScale]). Label positions depend on the zoom alone, so
/// they are recomputed only when it changes and merely translated while
/// panning.
class ConstellationMapView extends StatefulWidget {
  const ConstellationMapView({
    super.key,
    required this.stars,
    required this.edges,
    required this.transformation,
    required this.canvasSize,
    required this.fitScale,
    required this.onStarTap,
  });

  final List<ConstellationStar> stars;

  /// Index pairs into the slot-ordered subset of [stars] (see
  /// `ConstellationPainter.edges`).
  final List<(int, int)> edges;

  /// The map's camera: a uniform scale plus a translation, from canvas pixels
  /// to screen pixels. Written by this widget's gestures; the screen only
  /// sets its initial framing.
  final TransformationController transformation;
  final Size canvasSize;

  /// The zoom at which the whole shape fits the viewport — the scale
  /// [_uiScale] is measured against, and the basis of the zoom limits.
  final double fitScale;

  final ValueChanged<ConstellationStar> onStarTap;

  @override
  State<ConstellationMapView> createState() => _ConstellationMapViewState();
}

class _ConstellationMapViewState extends State<ConstellationMapView>
    with SingleTickerProviderStateMixin {
  // The layout is a function of the zoom (and the stars), not of the pan.
  double? _layoutZoom;
  Object? _layoutStars;
  _MapGeometry? _geometry;
  Offset _translation = Offset.zero;

  final Map<(int, double), Size> _labelSizes = {};
  Map<int, int> _previousCandidates = const {};

  /// Labels grow with the zoom, but only a little (an exponent well under 1)
  /// and never past these bounds — enough to feel like zooming, not enough to
  /// make the text unreadably small or huge.
  double _uiScale(double zoom) {
    final relative = zoom / widget.fitScale;
    return math
        .pow(relative <= 0 ? 1 : relative, 0.4)
        .toDouble()
        .clamp(0.85, 1.6)
        .toDouble();
  }

  // How far the map may be zoomed out/in, as multiples of the fit zoom.
  static const _minZoomFactor = 0.6;
  static const _maxZoomFactor = 14.0;

  /// How much of a star must stay inside the viewport's edge for it to count
  /// as "on screen" - about a button's radius plus a little.
  static const _visibleInset = 40.0;

  double get _minZoom => widget.fitScale * _minZoomFactor;
  double get _maxZoom => widget.fitScale * _maxZoomFactor;

  double get _zoom => widget.transformation.value.entry(0, 0);
  Offset get _pan => Offset(
    widget.transformation.value.entry(0, 3),
    widget.transformation.value.entry(1, 3),
  );

  // The gesture in progress: the camera as it was when it began, and where
  // the fingers were then. Every frame re-derives the camera from these
  // (never by accumulating steps), so the canvas point that was under the
  // fingers stays exactly under them for the whole drag/pinch - and, since
  // the clamping below never feeds back into them, dragging past a limit and
  // back doesn't drift.
  double _startZoom = 1;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;

  // Momentum left from a flick, in screen pixels per second.
  Offset _velocity = Offset.zero;
  Ticker? _inertiaTicker;
  Duration _lastInertiaTick = Duration.zero;

  @override
  void dispose() {
    _inertiaTicker?.dispose();
    super.dispose();
  }

  void _stopInertia() {
    _inertiaTicker?.stop();
    _inertiaTicker?.dispose();
    _inertiaTicker = null;
    _velocity = Offset.zero;
  }

  /// Moves the camera to zoom [zoom] and pan [pan], after nudging the pan
  /// just enough that at least one star is still on screen.
  void _apply(double zoom, Offset pan) {
    final constrained = _constrainPan(zoom, pan);
    widget.transformation.value = Matrix4.identity()
      ..translateByDouble(constrained.dx, constrained.dy, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1);
  }

  /// [pan] itself if some star lands inside the (slightly inset) viewport at
  /// this [zoom]; otherwise the closest pan that puts the nearest star
  /// exactly on its edge. That is the whole boundary: the map can be dragged
  /// anywhere, like the sky, but never fully out of sight.
  Offset _constrainPan(double zoom, Offset pan) {
    final size = context.size;
    final stars = widget.stars;
    if (size == null || size.isEmpty || stars.isEmpty) return pan;
    final inset = math.min(
      _visibleInset,
      math.min(size.width, size.height) / 2,
    );
    final visible = (Offset.zero & size).deflate(inset);
    var bestShift = Offset.zero;
    var bestDistance = double.infinity;
    for (final star in stars) {
      final screen = Offset(
        star.position.dx * widget.canvasSize.width * zoom + pan.dx,
        star.position.dy * widget.canvasSize.height * zoom + pan.dy,
      );
      final shift =
          Offset(
            screen.dx.clamp(visible.left, visible.right).toDouble(),
            screen.dy.clamp(visible.top, visible.bottom).toDouble(),
          ) -
          screen;
      final distance = shift.distanceSquared;
      if (distance == 0) return pan;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestShift = shift;
      }
    }
    return pan + bestShift;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _stopInertia();
    _startZoom = _zoom;
    _startPan = _pan;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final zoom = (_startZoom * details.scale)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    final anchor = (_startFocal - _startPan) / _startZoom;
    _apply(zoom, details.localFocalPoint - anchor * zoom);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Only a lifted-off drag glides; ending a pinch with one finger still
    // down goes straight on into a new drag.
    if (details.pointerCount != 0) return;
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 120) return;
    _velocity = velocity.distance > 5000
        ? velocity / velocity.distance * 5000
        : velocity;
    _lastInertiaTick = Duration.zero;
    _inertiaTicker = createTicker(_onInertiaTick)..start();
  }

  void _onInertiaTick(Duration elapsed) {
    final dt = _lastInertiaTick == Duration.zero
        ? 0.0
        : (elapsed - _lastInertiaTick).inMicroseconds / 1e6;
    _lastInertiaTick = elapsed;
    if (dt <= 0) return;
    final wanted = _pan + _velocity * dt;
    _apply(_zoom, wanted);
    // Ran into the "one star must stay visible" limit: stop pushing that way.
    if ((_pan - wanted).distanceSquared > 0.25) _velocity = Offset.zero;
    // Same friction as the sky: this fraction of the speed survives a second.
    _velocity *= math.pow(0.04, dt).toDouble();
    if (_velocity.distance < 8) _stopInertia();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _stopInertia();
    final zoom = (_zoom * math.exp(-event.scrollDelta.dy * 0.0015))
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    final anchor = (event.localPosition - _pan) / _zoom;
    _apply(zoom, event.localPosition - anchor * zoom);
  }

  /// The star buttons, unlike the text, are part of the map: their size is
  /// exactly proportional to the zoom, like a marker's on a map. At the widest
  /// view they are small dots so the whole constellation reads as a shape, and
  /// zooming in makes them as big as you like — there is no upper limit.
  double _nodeScale(double zoom) {
    return zoom / widget.fitScale * 0.7;
  }

  @override
  void didUpdateWidget(ConstellationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stars, widget.stars) ||
        oldWidget.edges != widget.edges) {
      _layoutStars = null;
      _labelSizes.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: widget.transformation,
                builder: (context, _) => _buildOverlay(context),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onTapUp: (details) {
                final star = _hitTest(details.localPosition);
                if (star != null) widget.onStarTap(star);
              },
            ),
          ),
        ),
      ],
    );
  }

  ConstellationStar? _hitTest(Offset screen) {
    final geometry = _geometry;
    if (geometry == null) return null;
    final point = screen - _translation;
    ConstellationStar? best;
    var bestDistance = double.infinity;
    for (final node in geometry.nodes) {
      // A little beyond the visible button, so a thumb doesn't have to be
      // precise on a small one.
      final distance = (node.center - point).distance;
      if (distance <= node.outer + 6 && distance < bestDistance) {
        bestDistance = distance;
        best = widget.stars[node.index];
      }
    }
    if (best != null) return best;
    for (final node in geometry.nodes) {
      final placement = geometry.layout.placements[node.index];
      if (placement != null && placement.rect.inflate(4).contains(point)) {
        return widget.stars[node.index];
      }
    }
    return null;
  }

  Size _measureLabel(BuildContext context, int index, double fontSize) {
    final key = (index, fontSize);
    // Pinching walks through a continuum of font sizes; don't keep them all.
    if (_labelSizes.length > 1500) _labelSizes.clear();
    return _labelSizes.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(
          text: widget.stars[index].label,
          style: _labelStyle(context, fontSize),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: _kLabelMaxWidth * fontSize / _kLabelFontSize - _kLabelPadX * 2);
      final size = Size(
        painter.width.ceilToDouble() + 1 + _kLabelPadX * 2,
        painter.height.ceilToDouble() + _kLabelPadY * 2,
      );
      painter.dispose();
      return size;
    });
  }

  TextStyle _labelStyle(BuildContext context, double fontSize) {
    return DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: fontSize,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: context.colors.text,
      ),
    );
  }

  _MapGeometry _ensureGeometry(
    BuildContext context,
    double zoom,
    double ui,
    double nodeScale,
  ) {
    final cached = _geometry;
    if (cached != null &&
        _layoutZoom == zoom &&
        identical(_layoutStars, widget.stars)) {
      return cached;
    }

    final stars = widget.stars;
    final nodes = <_MapNode>[];
    for (var i = 0; i < stars.length; i++) {
      final metrics = _NodeMetrics.of(stars[i], nodeScale);
      nodes.add(
        _MapNode(
          index: i,
          center: Offset(
            stars[i].position.dx * widget.canvasSize.width * zoom,
            stars[i].position.dy * widget.canvasSize.height * zoom,
          ),
          metrics: metrics,
          outer: metrics.outer(nodeScale),
        ),
      );
    }

    var anchor = Offset.zero;
    for (final node in nodes) {
      anchor += node.center;
    }
    if (nodes.isNotEmpty) anchor = anchor / nodes.length.toDouble();

    // Same slot ordering the painter uses to resolve edge indices — pulsars,
    // which sit on no slot, never take part.
    final shapeNodes = nodes.where((n) => stars[n.index].slotSequence != null).toList()
      ..sort((a, b) => stars[a.index].slotSequence!.compareTo(stars[b.index].slotSequence!));
    final segments = <(Offset, Offset)>[
      for (final (a, b) in widget.edges)
        if (a < shapeNodes.length && b < shapeNodes.length)
          (shapeNodes[a].center, shapeNodes[b].center),
    ];

    final layout = layoutConstellationLabels(
      nodes: [
        for (final node in nodes)
          MapNode(
            id: node.index,
            center: node.center,
            radius: node.outer,
            // The crowded middle of the shape gets first pick of the free
            // space; the outer stars can always reach into the open sky.
            priority: -(node.center - anchor).distance,
          ),
      ],
      labelSize: (id, labelScale) => stars[id].label.isEmpty
          ? null
          : _measureLabel(context, id, _kLabelFontSize * ui * labelScale),
      edges: segments,
      anchor: anchor,
      previous: _previousCandidates,
    );
    _previousCandidates = {
      for (final entry in layout.placements.entries)
        entry.key: entry.value.candidate,
    };

    _layoutZoom = zoom;
    _layoutStars = widget.stars;
    return _geometry = _MapGeometry(
      nodes: nodes,
      segments: segments,
      layout: layout,
      uiScale: ui,
      nodeScale: nodeScale,
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final matrix = widget.transformation.value;
    final zoom = matrix.entry(0, 0);
    if (zoom <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    final ui = _uiScale(zoom);
    final geometry = _ensureGeometry(context, zoom, ui, _nodeScale(zoom));
    final translation = Offset(matrix.entry(0, 3), matrix.entry(1, 3));
    _translation = translation;
    final layout = geometry.layout;
    final stars = widget.stars;

    final leaders = <_Leader>[];
    for (final placement in layout.placements.values) {
      leaders.add(
        _Leader(
          path: placement.path.shift(translation),
          color: colors.text,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinesPainter(
              segments: [
                for (final (a, b) in geometry.segments)
                  (a + translation, b + translation),
              ],
              edgeColor: colors.text,
              edgeWidth: _kLineWidth,
              leaders: leaders,
            ),
          ),
        ),
        for (final node in geometry.nodes)
          Positioned(
            left: node.center.dx + translation.dx - node.outer,
            top: node.center.dy + translation.dy - node.outer,
            width: node.outer * 2,
            height: node.outer * 2,
            child: _StarButton(
              star: stars[node.index],
              metrics: node.metrics,
              uiScale: geometry.nodeScale,
            ),
          ),
        for (final placement in layout.placements.values)
          Positioned.fromRect(
            rect: placement.rect.shift(translation),
            child: _LabelPill(
              star: stars[placement.id],
              style: _labelStyle(
                context,
                _kLabelFontSize * geometry.uiScale * layout.labelScale,
              ),
            ),
          ),
      ],
    );
  }
}

class _MapGeometry {
  const _MapGeometry({
    required this.nodes,
    required this.segments,
    required this.layout,
    required this.uiScale,
    required this.nodeScale,
  });

  final List<_MapNode> nodes;
  final List<(Offset, Offset)> segments;
  final LabelLayout layout;

  /// Scale of the labels' text, and of the buttons (see [_nodeScale]).
  final double uiScale;
  final double nodeScale;
}

class _MapNode {
  const _MapNode({
    required this.index,
    required this.center,
    required this.metrics,
    required this.outer,
  });

  final int index;

  /// In layout space: the canvas position scaled by the zoom, before the
  /// pan's translation.
  final Offset center;
  final _NodeMetrics metrics;

  /// The button's outer radius, rings included.
  final double outer;
}

/// How big one star's button is: its disc, and how many decoration rings
/// stack around it. Every star is the same size; intensity shows only in the
/// rings (none for a light effort, four for the heaviest) and the dots.
class _NodeMetrics {
  const _NodeMetrics({required this.diameter, required this.rings});

  factory _NodeMetrics.of(ConstellationStar star, double ui) {
    switch (star.kind) {
      // An empty slot is a little smaller: it's a place, not yet a star.
      case StarKind.nascent:
        return _NodeMetrics(diameter: 32 * ui, rings: 0);
      case StarKind.dead:
        return _NodeMetrics(diameter: 40 * ui, rings: 0);
      // Every other star is the same size whatever its intensity — that is
      // what the rings around it are for.
      case StarKind.lit:
      case StarKind.unlit:
      case StarKind.pulsar:
        final intensity = (star.intensity ?? 1).clamp(1, 5).toInt();
        return _NodeMetrics(diameter: 40 * ui, rings: intensity - 1);
    }
  }

  final double diameter;
  final int rings;

  /// The distance between one ring and the next. Grows with the zoom like the
  /// button itself, but never below what keeps two [_kLineWidth] rings
  /// distinct, so they still read as separate rings from far away.
  static double ringGap(double ui) => math.max(4.5, 5 * ui);

  double outer(double ui) => diameter / 2 + rings * ringGap(ui) + _kLineWidth;
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.star,
    required this.metrics,
    required this.uiScale,
  });

  final ConstellationStar star;
  final _NodeMetrics metrics;
  final double uiScale;

  /// Below this scale a button is too small for its five intensity dots to
  /// read; it keeps just the icon (and its rings) until you zoom in.
  static const _dotsMinScale = 0.65;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = star.kind;
    // Navy and white throughout, like the constellation editor and the shape
    // previews: the only colors are the kind's own (its icon — gold when it
    // burns, blue when it doesn't) and gold for the intensity dots; the rings
    // are white, like the border.
    final kindColor = starKindColor(kind, colors, lit: star.lit);
    final diameter = metrics.diameter;
    final nascent = kind == StarKind.nascent;
    final dead = kind == StarKind.dead;
    final photoPath = star.photoPath;

    final disc = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.night,
        border: Border.all(
          color: colors.text,
          width: _kLineWidth,
        ),
      ),
      // The star's photo, if it has one, fills the disc behind everything
      // else at half strength — its center, cropped to the circle.
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (photoPath != null && photoPath.isNotEmpty)
              Opacity(
                opacity: 0.5,
                child: PhotoImage(
                  photoPath: photoPath,
                  fit: BoxFit.cover,
                  // Never shown bigger than the biggest button, however
                  // sharp the camera photo it came from.
                  cacheWidth: 400,
                ),
              ),
            Center(
              child: nascent
                  ? Icon(
                      Icons.add,
                      size: diameter * 0.5,
                      color: colors.text.withValues(alpha: 0.5),
                    )
                  // Too small to read, the dots simply aren't there; once the
                  // button is big enough they fade in while the icon glides
                  // up (and shrinks) to make room, and back again.
                  : TweenAnimationBuilder<double>(
                      tween: Tween(end: uiScale >= _dotsMinScale ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      builder: (context, t, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            kind.icon,
                            size: diameter * (0.55 - 0.15 * t),
                            color: kindColor,
                          ),
                          Align(
                            heightFactor: t,
                            child: Opacity(
                              opacity: t,
                              child: Padding(
                                padding: EdgeInsets.only(top: diameter * 0.04),
                                child: IntensityDots(
                                  intensity: star.intensity,
                                  color: colors.gold,
                                  dotSize: math.max(1.1, diameter * 0.038),
                                  spacing: math.max(0.7, diameter * 0.024),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        if (metrics.rings > 0)
          Positioned.fill(
            child: CustomPaint(
              painter: _RingsPainter(
                color: colors.text,
                rings: metrics.rings,
                baseRadius: diameter / 2,
                gap: _NodeMetrics.ringGap(uiScale),
                strokeWidth: _kLineWidth,
              ),
            ),
          ),
        Opacity(opacity: dead ? 0.75 : 1, child: disc),
      ],
    );
  }
}

/// Concentric white rings around a star's disc — one per intensity level above
/// the first, each fainter than the one inside it, so intensity reads as a
/// halo that fades outward. The same thickness as the disc's own border.
class _RingsPainter extends CustomPainter {
  const _RingsPainter({
    required this.color,
    required this.rings,
    required this.baseRadius,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final int rings;
  final double baseRadius;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var k = 1; k <= rings; k++) {
      // Solid white next to the disc, fading to 40% at the outermost ring.
      final fade = rings == 1 ? 1.0 : 1 - 0.6 * (k - 1) / (rings - 1);
      canvas.drawCircle(
        center,
        baseRadius + k * gap,
        Paint()
          ..color = color.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      color != old.color ||
      rings != old.rings ||
      baseRadius != old.baseRadius ||
      gap != old.gap ||
      strokeWidth != old.strokeWidth;
}

class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.star, required this.style});

  final ConstellationStar star;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dead = star.kind == StarKind.dead;
    return Container(
      alignment: Alignment.center,
      // With the border, exactly the padding `_measureLabel` reserved, so the
      // text wraps as it was measured.
      padding: const EdgeInsets.symmetric(horizontal: _kLabelPadX - _kLineWidth),
      decoration: BoxDecoration(
        color: colors.nightPanel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.text, width: _kLineWidth),
      ),
      child: Text(
        star.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: dead ? style.copyWith(color: colors.muted) : style,
      ),
    );
  }
}

class _Leader {
  const _Leader({required this.path, required this.color});
  final Path path;
  final Color color;
}

/// The constellation's own straight lines, then every label's S-curve leader
/// on top of them — thinner and fainter, so a leader is never mistaken for
/// part of the shape.
class _LinesPainter extends CustomPainter {
  const _LinesPainter({
    required this.segments,
    required this.edgeColor,
    required this.edgeWidth,
    required this.leaders,
  });

  final List<(Offset, Offset)> segments;
  final Color edgeColor;
  final double edgeWidth;
  final List<_Leader> leaders;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = edgeWidth
      ..style = PaintingStyle.stroke;
    for (final (a, b) in segments) {
      canvas.drawLine(a, b, edgePaint);
    }
    for (final leader in leaders) {
      canvas.drawPath(
        leader.path,
        Paint()
          ..color = leader.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _kLineWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => true;
}
