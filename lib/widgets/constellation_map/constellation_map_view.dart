import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/strings_scope.dart';
import '../../models/star_kind.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_style.dart';
import '../constellation_painter.dart';
import '../intensity_dots.dart';
import '../photo_image.dart';
import '../star_glyph.dart';
import 'constellation_label_layout.dart';

// Font size and size of a map card at zoom-neutral scale; both then
// grow/shrink with the view's own [_uiScale] and the layout's card scale.
const double _kLabelFontSize = 12;
// Cards stay part of the same zoom-scaled map, but begin noticeably smaller
// than the nodes and constellation they annotate. This makes the shape read
// first at the overview zoom without changing the camera's single scale.
const double _kMapCardWidth = 124;
const double _kMapCardHeight = 36;
// Search cards use a soft radius on a much taller surface. Keep that same
// visual proportion here rather than making these compact labels pill-shaped.
const double _kMapCardRadius = 6;

/// The constellation is the map's primary structure: its edges and the
/// stars' own outlines deliberately retain the strongest white stroke.
const double _kConstellationEdgeWidth = 3.5;
const double _kNodeStrokeWidth = 2.5;

/// Cards are annotations, not another graph. Leaders inherit their star's
/// color but remain much lighter and thinner than constellation edges.
const double _kLabelLeaderWidth = 1.25;
const double _kLabelLeaderOpacity = 0.78;

// A layout search is intentionally thorough for a crowded constellation. Keep
// completed maps beyond the lifetime of one screen so moving away and back
// never makes the UI thread solve the exact same geometry again.
const int _kStoredLayoutsLimit = 18;
final Map<String, _StoredLabelLayout> _storedLabelLayouts = {};

class _StoredLabelLayout {
  const _StoredLabelLayout({required this.layout, required this.referenceZoom});

  final LabelLayout layout;
  final double referenceZoom;
}

/// One constellation as a map: every star a round, self-explaining button
/// (its kind's icon, dots, and a proportional glow), each tied by a smooth
/// line to a card, laid out so nothing sits on top of anything else.
///
/// The map pans/zooms with the shared [transformation], driven by this
/// widget's own gestures rather than an `InteractiveViewer`, so it can move
/// like the Sky does: a drag keeps the point you grabbed under your finger,
/// a flick glides to a stop, a pinch or the wheel zooms toward where you are
/// — and the map can be carried freely anywhere so long as at least one star
/// stays on screen. Everything visible is drawn in *screen space* by an overlay
/// underneath that reads the same matrix. Every visual element follows the
/// camera's linear zoom factor, while positions are recomputed only when that
/// zoom changes and merely translated while panning.
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

  /// Every constellation opens at this fixed overview level. Every visual
  /// element uses this same linear zoom factor, like one scalable map image.
  // Keep the overview far enough out to include every annotation with some
  // breathing room, without making the cards and glow disappear into dots.
  static const double initialZoomFactor = 0.55;

  final ValueChanged<ConstellationStar> onStarTap;

  @override
  State<ConstellationMapView> createState() => _ConstellationMapViewState();
}

class _ConstellationMapViewState extends State<ConstellationMapView>
    with TickerProviderStateMixin {
  // The layout is a function of the zoom (and the stars), not of the pan.
  double? _layoutZoom;
  Object? _layoutStars;
  _MapGeometry? _geometry;
  Offset _translation = Offset.zero;

  final Map<(int, double), Size> _labelSizes = {};
  Map<int, int> _previousCandidates = const {};
  LabelLayout? _lockedLayout;
  double? _layoutReferenceZoom;

  /// The map's one visual scale: cards, stars, glows, borders, and both line
  /// families all grow and shrink by this exact same ratio.
  double _uiScale(double zoom) {
    final relative = zoom / widget.fitScale;
    return relative <= 0 ? 1 : relative;
  }

  // How far the map may be zoomed out/in, as multiples of the fit zoom.
  static const _minZoomFactor = ConstellationMapView.initialZoomFactor;
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
  late final AnimationController _cameraAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  double _cameraFromZoom = 1;
  double _cameraToZoom = 1;
  Offset _cameraFromPan = Offset.zero;
  Offset _cameraToPan = Offset.zero;
  Offset _lastTapPosition = Offset.zero;
  Offset _lastDoubleTapPosition = Offset.zero;
  late final Matrix4 _initialTransform;

  // Raw pointer state supplements GestureDetector's recognizers: a star tap
  // is only valid for a one-finger interaction from start to finish. A pinch
  // that begins over a star must keep its priority as a camera gesture.
  final Set<int> _activePointers = <int>{};
  bool _gestureUsedMultiplePointers = false;

  @override
  void initState() {
    super.initState();
    // The screen frames the shape before creating this map. Keep that exact
    // camera so a double-tap zoom-out always returns to the centered opening
    // composition, rather than merely zooming out around the last finger.
    _initialTransform = Matrix4.copy(widget.transformation.value);
    _cameraAnimation.addListener(() {
      final t = Curves.easeOut.transform(_cameraAnimation.value);
      _apply(
        lerpDouble(_cameraFromZoom, _cameraToZoom, t)!,
        Offset.lerp(_cameraFromPan, _cameraToPan, t)!,
      );
    });
  }

  @override
  void dispose() {
    _inertiaTicker?.dispose();
    _cameraAnimation.dispose();
    super.dispose();
  }

  void _stopInertia() {
    _inertiaTicker?.stop();
    _inertiaTicker?.dispose();
    _inertiaTicker = null;
    _velocity = Offset.zero;
  }

  /// Gallery-style double tap: below this threshold it comes closer; once
  /// there, the next double tap returns to the constellation overview.
  static const _doubleTapZoomFactor = 1.5;
  static const _doubleTapResetThreshold = 1.25;

  void _animateCameraTo(double zoom, Offset pan) {
    _stopInertia();
    _cameraAnimation.stop();
    _cameraFromZoom = _zoom;
    _cameraFromPan = _pan;
    _cameraToZoom = zoom;
    _cameraToPan = _constrainPan(zoom, pan);
    _cameraAnimation
      ..value = 0
      ..forward(from: 0);
  }

  void _onDoubleTap(Offset focalPoint) {
    final zoomingOut = _zoom / widget.fitScale >= _doubleTapResetThreshold;
    if (zoomingOut) {
      _animateCameraTo(
        _initialTransform.entry(0, 0),
        Offset(_initialTransform.entry(0, 3), _initialTransform.entry(1, 3)),
      );
      return;
    }
    final targetZoom = (widget.fitScale * _doubleTapZoomFactor)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    final anchor = (focalPoint - _pan) / _zoom;
    _animateCameraTo(targetZoom, focalPoint - anchor * targetZoom);
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
    _cameraAnimation.stop();
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

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) _gestureUsedMultiplePointers = false;
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) _gestureUsedMultiplePointers = true;
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
  }

  /// Star buttons use the same linear camera scale as cards and lines. At the
  /// widest view they are small dots; zooming in enlarges the whole map in
  /// lockstep.
  double _nodeScale(double zoom) {
    return zoom / widget.fitScale;
  }

  @override
  void didUpdateWidget(ConstellationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stars, widget.stars) ||
        oldWidget.edges != widget.edges) {
      _layoutStars = null;
      _labelSizes.clear();
      _lockedLayout = null;
      _layoutReferenceZoom = null;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // A hot reload keeps State alive. The map deliberately freezes its first
    // composition, but a new label-layout algorithm must be able to compose
    // a fresh snapshot while it is being tuned in debug.
    _geometry = null;
    _layoutZoom = null;
    _layoutStars = null;
    _previousCandidates = const {};
    _lockedLayout = null;
    _layoutReferenceZoom = null;
    _storedLabelLayouts.clear();
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
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onDoubleTapDown: (details) =>
                  _lastDoubleTapPosition = details.localPosition,
              onDoubleTap: () => _onDoubleTap(_lastDoubleTapPosition),
              onTapUp: (details) => _lastTapPosition = details.localPosition,
              // `onTap`, unlike `onTapUp`, waits for Flutter to rule out a
              // double tap. A double tap on a star therefore zooms the map
              // instead of opening that star on its first touch.
              onTap: () {
                if (_gestureUsedMultiplePointers) return;
                final star = _hitTest(_lastTapPosition);
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
      final scale =
          MediaQuery.textScalerOf(context).scale(fontSize) / _kLabelFontSize;
      return Size(_kMapCardWidth * scale, _kMapCardHeight * scale);
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
    final shapeNodes =
        nodes.where((n) => stars[n.index].slotSequence != null).toList()..sort(
          (a, b) => stars[a.index].slotSequence!.compareTo(
            stars[b.index].slotSequence!,
          ),
        );
    // The shape, rather than the average of every visible star, defines its
    // vertical symmetry axis. Pulsars can sit outside the grid and must not
    // make two genuinely mirrored grid stars look asymmetric.
    final symmetryAxisX = shapeNodes.isEmpty
        ? anchor.dx
        : (shapeNodes
                      .map((node) => node.center.dx)
                      .reduce((left, right) => left < right ? left : right) +
                  shapeNodes
                      .map((node) => node.center.dx)
                      .reduce((left, right) => left > right ? left : right)) /
              2;
    final segments = <(Offset, Offset)>[
      for (final (a, b) in widget.edges)
        if (a < shapeNodes.length && b < shapeNodes.length)
          (shapeNodes[a].center, shapeNodes[b].center),
    ];
    final shapeGrid = _gridForShapeNodes(shapeNodes);

    final lockedLayout = _lockedLayout;
    final referenceZoom = _layoutReferenceZoom;
    if (lockedLayout != null && referenceZoom != null) {
      _layoutZoom = zoom;
      _layoutStars = widget.stars;
      return _geometry = _MapGeometry(
        nodes: nodes,
        segments: segments,
        layout: _scaleLayout(lockedLayout, zoom / referenceZoom),
        uiScale: ui,
        grid: shapeGrid,
      );
    }

    final layoutCacheKey = _layoutCacheKey(context, zoom);
    final stored = _storedLabelLayouts[layoutCacheKey];
    if (stored != null) {
      // The cache contains a complete layout in exactly this map's coordinate
      // system. It is immutable, so it can safely be shared across screens.
      _lockedLayout = stored.layout;
      _layoutReferenceZoom = stored.referenceZoom;
      _layoutZoom = zoom;
      _layoutStars = widget.stars;
      return _geometry = _MapGeometry(
        nodes: nodes,
        segments: segments,
        layout: _scaleLayout(stored.layout, zoom / stored.referenceZoom),
        uiScale: ui,
        grid: shapeGrid,
      );
    }

    final layout = layoutConstellationLabels(
      nodes: [
        for (final node in nodes)
          MapNode(
            id: node.index,
            center: node.center,
            radius: node.outer,
            leaderRadius: node.metrics.coreOuter,
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
      symmetryAxisX: symmetryAxisX,
      grid: shapeGrid,
      previous: _previousCandidates,
      leaderLengthScale: ui,
    );
    _previousCandidates = {
      for (final entry in layout.placements.entries)
        entry.key: entry.value.candidate,
    };
    // Keep the first complete composition in map coordinates. Zoom and pan
    // transform this snapshot as one image rather than running another label
    // search, so no card can migrate around its own star while exploring.
    _lockedLayout = layout;
    _layoutReferenceZoom = zoom;
    _storeLayout(layoutCacheKey, layout, zoom);

    _layoutZoom = zoom;
    _layoutStars = widget.stars;
    return _geometry = _MapGeometry(
      nodes: nodes,
      segments: segments,
      layout: layout,
      uiScale: ui,
      grid: shapeGrid,
    );
  }

  /// A version of the render inputs that affect label geometry. Updating a
  /// constellation naturally changes this key; returning to an untouched one
  /// reuses its finished map without even entering the placement solver.
  String _layoutCacheKey(BuildContext context, double zoom) {
    String number(double value) => value.toStringAsFixed(3);
    final textScale = MediaQuery.textScalerOf(context).scale(_kLabelFontSize);
    final starData = widget.stars
        .map((star) {
          return [
            star.entityId,
            number(star.position.dx),
            number(star.position.dy),
            star.kind.name,
            star.lit,
            star.label,
            star.slotSequence,
            star.intensity,
          ].join('~');
        })
        .join('|');
    final edgeData = widget.edges
        .map((edge) => '${edge.$1}:${edge.$2}')
        .join(',');
    return [
      number(widget.canvasSize.width),
      number(widget.canvasSize.height),
      number(zoom),
      number(textScale),
      starData,
      edgeData,
    ].join('#');
  }

  void _storeLayout(String key, LabelLayout layout, double referenceZoom) {
    // Dart maps retain insertion order. A tiny LRU-like cap is enough here:
    // most people revisit only a handful of constellations in one session.
    _storedLabelLayouts.remove(key);
    while (_storedLabelLayouts.length >= _kStoredLayoutsLimit) {
      _storedLabelLayouts.remove(_storedLabelLayouts.keys.first);
    }
    _storedLabelLayouts[key] = _StoredLabelLayout(
      layout: layout,
      referenceZoom: referenceZoom,
    );
  }

  /// The rendered graph may contain midpoint stars grown from the editor's
  /// original edges. Its finest occupied interval is therefore the grid we
  /// can actually show: every rendered shape star lies on this lattice.
  LabelGrid? _gridForShapeNodes(List<_MapNode> nodes) {
    if (nodes.length < 2) return null;
    final xs = nodes.map((node) => node.center.dx).toSet().toList()..sort();
    final ys = nodes.map((node) => node.center.dy).toSet().toList()..sort();
    double? spacing;
    void readIntervals(List<double> values) {
      for (var i = 1; i < values.length; i++) {
        final interval = values[i] - values[i - 1];
        if (interval <= 0.001) continue;
        if (spacing == null || interval < spacing!) spacing = interval;
      }
    }

    readIntervals(xs);
    readIntervals(ys);
    if (spacing == null) return null;
    return LabelGrid(origin: Offset(xs.first, ys.first), spacing: spacing!);
  }

  LabelLayout _scaleLayout(LabelLayout source, double scale) {
    LabelPlacement scaled(LabelPlacement placement) => LabelPlacement(
      id: placement.id,
      rect: Rect.fromLTRB(
        placement.rect.left * scale,
        placement.rect.top * scale,
        placement.rect.right * scale,
        placement.rect.bottom * scale,
      ),
      lineStart: placement.lineStart * scale,
      lineEnd: placement.lineEnd * scale,
      horizontal: placement.horizontal,
      candidate: placement.candidate,
    );
    return LabelLayout(
      placements: {
        for (final entry in source.placements.entries)
          entry.key: scaled(entry.value),
      },
      labelScale: source.labelScale,
      overlaps: source.overlaps,
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
          color: starKindColor(
            stars[placement.id].kind,
            colors,
            lit: stars[placement.id].lit,
          ).withValues(alpha: _kLabelLeaderOpacity),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The glow is atmospheric: it stays below both the constellation and
        // annotation lines instead of washing over the graph.
        for (final node in geometry.nodes)
          if (node.metrics.glowStrength > 0)
            Positioned(
              left: node.center.dx + translation.dx - node.outer,
              top: node.center.dy + translation.dy - node.outer,
              width: node.outer * 2,
              height: node.outer * 2,
              child: _StarGlow(star: stars[node.index], metrics: node.metrics),
            ),
        Positioned.fill(
          child: CustomPaint(
            painter: _LinesPainter(
              segments: [
                for (final (a, b) in geometry.segments)
                  (a + translation, b + translation),
              ],
              edgeColor: colors.text,
              edgeWidth: _kConstellationEdgeWidth * geometry.uiScale,
              leaderWidth: _kLabelLeaderWidth * geometry.uiScale,
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
            child: _StarButton(star: stars[node.index], metrics: node.metrics),
          ),
        for (final placement in layout.placements.values)
          Positioned.fromRect(
            rect: placement.rect.shift(translation),
            child: _StarMapCard(
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
    required this.grid,
  });

  final List<_MapNode> nodes;
  final List<(Offset, Offset)> segments;
  final LabelLayout layout;

  /// The shared linear scale for cards and line weights.
  final double uiScale;
  final LabelGrid? grid;
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

/// How big one star's button is: every disc stays the same size; intensity
/// reads through a static aura around it and, when close enough, the dots
/// inside it. The aura's breathing room also keeps labels from sitting over
/// its visible light.
class _NodeMetrics {
  const _NodeMetrics({
    required this.diameter,
    required this.strokeWidth,
    required this.glowStrength,
  });

  factory _NodeMetrics.of(ConstellationStar star, double ui) {
    switch (star.kind) {
      // An empty slot is a little smaller: it's a place, not yet a star.
      case StarKind.nascent:
        return _NodeMetrics(
          diameter: 32 * ui,
          strokeWidth: _kNodeStrokeWidth * ui,
          glowStrength: 0,
        );
      case StarKind.dead:
        return _NodeMetrics(
          diameter: 40 * ui,
          strokeWidth: _kNodeStrokeWidth * ui,
          glowStrength: 0,
        );
      // Every other star is the same size whatever its intensity. The
      // strength steps keep the difference clear without creating the
      // technical-looking white rings the map used to have.
      case StarKind.lit:
      case StarKind.unlit:
      case StarKind.pulsar:
        final intensity = (star.intensity ?? 1).clamp(1, 5).toInt();
        return _NodeMetrics(
          diameter: 40 * ui,
          strokeWidth: _kNodeStrokeWidth * ui,
          glowStrength: _glowStrengths[intensity - 1],
        );
    }
  }

  final double diameter;
  final double strokeWidth;
  final double glowStrength;

  /// Holds the tighter radial aura inside the node so labels remain clear of
  /// its visible light at every intensity.
  double outer(double ui) =>
      diameter / 2 + ((8 + 10 * glowStrength) / 2) * ui + strokeWidth;

  /// Connectors leave from the solid disc; the decorative aura does not move
  /// their endpoint farther away.
  double get coreOuter => diameter / 2 + strokeWidth;
}

const _glowStrengths = [0.35, 0.55, 0.8, 1.05, 1.3];

class _StarButton extends StatelessWidget {
  const _StarButton({required this.star, required this.metrics});

  final ConstellationStar star;
  final _NodeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = star.kind;
    // Navy and white throughout, like the constellation editor and the shape
    // previews: the only colors are the kind's own (its icon — gold when it
    // burns, blue when it doesn't) and gold for the intensity dots.
    final kindColor = starKindColor(kind, colors, lit: star.lit);
    final diameter = metrics.diameter;
    final nascent = kind == StarKind.nascent;
    final photoPath = star.photoPath;

    final disc = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.night,
        border: Border.all(color: colors.text, width: metrics.strokeWidth),
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
                      kind.icon,
                      size: diameter * 0.5,
                      color: colors.text.withValues(alpha: 0.5),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(kind.icon, size: diameter * 0.4, color: kindColor),
                        Padding(
                          padding: EdgeInsets.only(top: diameter * 0.04),
                          child: IntensityDots(
                            intensity: star.intensity,
                            color: colors.gold,
                            dotSize: diameter * 0.038,
                            spacing: diameter * 0.024,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(alignment: Alignment.center, children: [disc]);
  }
}

/// Kept separate from [_StarButton] so the glow can be below every line on
/// the map, while the solid star disc itself remains above them.
class _StarGlow extends StatelessWidget {
  const _StarGlow({required this.star, required this.metrics});

  final ConstellationStar star;
  final _NodeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      painter: _IntensityGlowPainter(
        color: star.lit
            ? colors.gold
            : starKindColor(star.kind, colors, lit: false),
        baseRadius: metrics.diameter / 2,
        strength: metrics.glowStrength,
      ),
    );
  }
}

/// Two compact radial layers make the intensity read at a glance. Unlike a
/// [BoxShadow] tuned for large gold action buttons, this is painted inside the
/// map node itself, so even a small, dark-disc star retains a visible aura.
class _IntensityGlowPainter extends CustomPainter {
  const _IntensityGlowPainter({
    required this.color,
    required this.baseRadius,
    required this.strength,
  });

  final Color color;
  final double baseRadius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = baseRadius + (8 + 10 * strength) / 2;
    final innerRadius = baseRadius + (4 + 6 * strength) / 2;

    void paintAura(double radius, double centerAlpha, double edgeAlpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: centerAlpha),
              color.withValues(alpha: edgeAlpha),
              Colors.transparent,
            ],
            stops: const [0, 0.68, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Keep the brightness close to the disc: the glow communicates
    // intensity without turning into a wide haze between nearby stars.
    paintAura(outerRadius, 0.16 + 0.16 * strength, 0.035);
    paintAura(innerRadius, 0.32 + 0.22 * strength, 0.08);
  }

  @override
  bool shouldRepaint(_IntensityGlowPainter old) =>
      color != old.color ||
      baseRadius != old.baseRadius ||
      strength != old.strength;
}

/// Search-result card treatment, stripped of its quick-action drawer: on a
/// constellation map the star itself remains the single tap target.
class _StarMapCard extends StatelessWidget {
  const _StarMapCard({required this.star, required this.style});

  final ConstellationStar star;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typeColor = starKindColor(star.kind, colors, lit: star.lit);
    final strings = context.strings;
    final scale = (style.fontSize ?? _kLabelFontSize) / _kLabelFontSize;
    return Container(
      decoration: BoxDecoration(
        // The card still reads as a surface, while the constellation's
        // connectors remain subtly visible underneath it.
        color: colors.nightPanel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(_kMapCardRadius * scale),
        border: Border.all(color: typeColor, width: kBorderWidth * scale),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 7 * scale,
                vertical: scale,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    star.kind.label(strings).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 5 * scale,
                      letterSpacing: 0.7 * scale,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                  SizedBox(height: scale),
                  Text(
                    star.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(
                      fontSize: 7.5 * scale,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  SizedBox(height: scale),
                  Text(
                    strings.intensityCount(star.intensity ?? 0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 6 * scale,
                      fontWeight: FontWeight.w600,
                      color: colors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leader {
  const _Leader({required this.path, required this.color});
  final Path path;
  final Color color;
}

/// Star-colored card leaders first, then the constellation's strong white
/// edges. At crossings the graph remains visually on top of its annotations.
class _LinesPainter extends CustomPainter {
  const _LinesPainter({
    required this.segments,
    required this.edgeColor,
    required this.edgeWidth,
    required this.leaderWidth,
    required this.leaders,
  });

  final List<(Offset, Offset)> segments;
  final Color edgeColor;
  final double edgeWidth;
  final double leaderWidth;
  final List<_Leader> leaders;

  @override
  void paint(Canvas canvas, Size size) {
    for (final leader in leaders) {
      canvas.drawPath(
        leader.path,
        Paint()
          ..color = leader.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = leaderWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = edgeWidth
      ..style = PaintingStyle.stroke;
    for (final (a, b) in segments) {
      canvas.drawLine(a, b, edgePaint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => true;
}
