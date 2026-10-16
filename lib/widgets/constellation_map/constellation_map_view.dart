import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import '../../models/star_kind.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_style.dart';
import '../sky_search_tooltip_card.dart';
import '../search_result_card.dart';
import '../constellation_painter.dart';
import '../intensity_dots.dart';
import '../photo_image.dart';
import '../star_glyph.dart';
import 'constellation_label_layout.dart';
import 'constellation_structure_glow.dart';

// Render the real Galaxy tooltip at native dimensions. Only this explicit
// factor and the map's camera scale reduce it; the solver never shrinks it.

/// The constellation uses dark navy edges and thin muted node outlines.
const double _kConstellationEdgeWidth = 3.5;
const double _kNodeStrokeWidth = 0.5;

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
enum ConstellationNodeStyle { disc, beacon, glyph }

class ConstellationMapView extends StatefulWidget {
  const ConstellationMapView({
    super.key,
    required this.stars,
    required this.edges,
    required this.transformation,
    this.homeTransform,
    required this.canvasSize,
    required this.fitScale,
    required this.onStarTap,
    this.cardBuilder,
    this.tooltipScale = 0.45,
    this.autoFrame = false,
    this.structureColor,
    this.tooltipFrameColor,
    this.luminousStructure = false,
    this.refinedPresentation = false,
    this.focusedStarIndex,
    this.selectionEnabled = false,
    this.nodeStyle = ConstellationNodeStyle.disc,
    this.showCardVisual = false,
    this.simplifiedNodes = false,
    this.fadeStructureOnFocus = false,
    this.uniformNodeSize = false,
    this.matchTooltipFrameToNode = false,
  });

  final List<ConstellationStar> stars;

  /// Index pairs into the slot-ordered subset of [stars] (see
  /// `ConstellationPainter.edges`).
  final List<(int, int)> edges;

  /// The map's camera: a uniform scale plus a translation, from canvas pixels
  /// to screen pixels. Written by this widget's gestures; the screen only
  /// sets its initial framing.
  final TransformationController transformation;

  /// The overview camera a double tap zooms back out to; defaults to the
  /// camera the map opens with.
  final Matrix4? homeTransform;
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
  final Widget Function(BuildContext, ConstellationStar)? cardBuilder;

  /// 1 renders Galaxy's native tooltip dimensions at the fit zoom. The map
  /// uses a smaller uniform scale while keeping all tooltip geometry intact.
  final double tooltipScale;
  final bool autoFrame;

  /// Color override for graph edges, outer star shells and tooltip frames.
  final Color? structureColor;

  /// Independent tooltip frame color, separate from the graph structure.
  final Color? tooltipFrameColor;

  /// Outward-only structural glow and an inset ring matching tooltip frames.
  final bool luminousStructure;

  /// Lab composition with lighter structure and compact nodes.
  final bool refinedPresentation;
  final int? focusedStarIndex;
  final bool selectionEnabled;
  final ConstellationNodeStyle nodeStyle;
  final bool showCardVisual;
  final bool simplifiedNodes;
  final bool fadeStructureOnFocus;

  /// Lab comparison: equal disc diameters for every star kind.
  final bool uniformNodeSize;
  final bool matchTooltipFrameToNode;

  @override
  State<ConstellationMapView> createState() => _ConstellationMapViewState();
}

class _ConstellationMapViewState extends State<ConstellationMapView>
    with TickerProviderStateMixin {
  // The layout is a function of the zoom (and the stars), not of the pan.
  final _menuController = SearchCardMenuController();
  int? _selectedIndex;

  void _select(int? index) {
    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
  }

  double? _layoutZoom;
  Object? _layoutStars;
  Size? _layoutEnvironment;
  final Map<(int, int?), Size> _tooltipSizes = {};
  final Map<(int, int?), Size> _pendingTooltipSizes = {};
  Timer? _tooltipResizeTimer;
  _MapGeometry? _geometry;
  Offset _translation = Offset.zero;

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

  double get _minZoom => math.min(
    widget.fitScale * _minZoomFactor,
    _overviewZoom ?? double.infinity,
  );
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
  late Matrix4 _initialTransform;
  bool _overviewFitted = false;
  double? _overviewZoom;

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
    _initialTransform = Matrix4.copy(
      widget.homeTransform ?? widget.transformation.value,
    );
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
    _menuController.dispose();
    _tooltipResizeTimer?.cancel();
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
    final ui = zoom / widget.fitScale;
    var nearest = double.infinity;
    for (var i = 0; i < widget.stars.length; i++) {
      for (var j = i + 1; j < widget.stars.length; j++) {
        final delta = widget.stars[i].position - widget.stars[j].position;
        final distance =
            Offset(
              delta.dx * widget.canvasSize.width,
              delta.dy * widget.canvasSize.height,
            ).distance *
            zoom;
        if (distance > 0.001) nearest = math.min(nearest, distance);
      }
    }
    // Preserve the shape, but keep discs and their auras clear in dense groups.
    return ui * math.min(1.0, nearest / (74 * ui));
  }

  void _frameCompleteMap(_MapGeometry geometry) {
    if (_overviewFitted ||
        _tooltipSizes.length < widget.stars.length ||
        _pendingTooltipSizes.isNotEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overviewFitted) return;
      final viewport = context.size;
      if (viewport == null || viewport.isEmpty) return;
      Rect? bounds;
      void include(Rect rect) =>
          bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
      for (final node in geometry.nodes) {
        include(Rect.fromCircle(center: node.center, radius: node.outer));
      }
      for (final placement in geometry.layout.placements.values) {
        include(placement.rect);
      }
      if (bounds == null || bounds!.isEmpty) return;
      final available = Rect.fromLTRB(
        16,
        16,
        viewport.width - 16,
        viewport.height - 72,
      );
      final ratio = math.min(
        1.0,
        math.min(
          available.width / bounds!.width,
          available.height / bounds!.height,
        ),
      );
      final zoom = _zoom * ratio;
      final pan = available.center - bounds!.center * ratio;
      _overviewFitted = true;
      _overviewZoom = zoom;
      _initialTransform = Matrix4.identity()
        ..translateByDouble(pan.dx, pan.dy, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
      if (widget.autoFrame) {
        widget.transformation.value = _initialTransform.clone();
      }
    });
  }

  @override
  void didUpdateWidget(ConstellationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null &&
        (selected >= widget.stars.length ||
            selected >= oldWidget.stars.length ||
            _tooltipId(widget.stars[selected]) !=
                _tooltipId(oldWidget.stars[selected]))) {
      _selectedIndex = null;
    }
    if (!identical(oldWidget.stars, widget.stars) ||
        oldWidget.edges != widget.edges ||
        oldWidget.tooltipScale != widget.tooltipScale ||
        oldWidget.nodeStyle != widget.nodeStyle ||
        oldWidget.uniformNodeSize != widget.uniformNodeSize ||
        oldWidget.matchTooltipFrameToNode != widget.matchTooltipFrameToNode ||
        oldWidget.showCardVisual != widget.showCardVisual ||
        oldWidget.refinedPresentation != widget.refinedPresentation) {
      _layoutStars = null;
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
    return Listener(
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
        onLongPressStart: widget.selectionEnabled
            ? (details) {
                final star = _hitTest(details.localPosition);
                if (star != null) widget.onStarTap(star);
              }
            : null,
        onTap: () {
          if (_gestureUsedMultiplePointers) return;
          final star = _hitTest(_lastTapPosition);
          if (widget.selectionEnabled) {
            _select(star == null ? null : widget.stars.indexOf(star));
          } else if (star != null) {
            widget.onStarTap(star);
          }
        },
        child: ClipRect(
          child: AnimatedBuilder(
            animation: widget.transformation,
            builder: (context, _) => _buildOverlay(context),
          ),
        ),
      ),
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
    return null;
  }

  (int, int?) _tooltipId(ConstellationStar star) =>
      (star.entityId, star.slotSequence);

  double _tooltipFrameWidth() {
    if (!widget.matchTooltipFrameToNode) return galaxyTooltipPadding;
    final zoom = widget.transformation.value.entry(0, 0);
    final scale = zoom > 0 ? zoom : widget.fitScale;
    return _kConstellationEdgeWidth *
        _nodeScale(scale) /
        (widget.tooltipScale * _uiScale(scale));
  }

  double _mapTooltipWidth(BuildContext context) =>
      galaxyTooltipWidth(context) -
      (widget.showCardVisual ? 0 : SearchResultCard.visualSize) +
      2 * (_tooltipFrameWidth() - galaxyTooltipPadding);

  Size _nativeTooltipSize(BuildContext context, ConstellationStar star) {
    final width = _mapTooltipWidth(context);
    final measured = _tooltipSizes[_tooltipId(star)];
    if (measured != null && (measured.width - width).abs() < 0.1) {
      return measured;
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Size(
      width,
      SearchResultCard.defaultBodyHeight +
          math.max(0.0, textScale - 1) * 66 +
          galaxyTooltipPadding * 2,
    );
  }

  void _onTooltipSize((int, int?) id, Size size) {
    if (!mounted || size.isEmpty) return;
    if (_tooltipSizes[id] == size) {
      _pendingTooltipSizes.remove(id);
      if (_pendingTooltipSizes.isEmpty) _tooltipResizeTimer?.cancel();
      return;
    }
    _pendingTooltipSizes[id] = size;
    // Initial measurements settle together in the next frame. Later changes
    // wait for drawer/flip animation to stop instead of solving every tick.
    if (!_tooltipSizes.containsKey(id)) {
      _commitTooltipSizes();
    } else {
      _tooltipResizeTimer?.cancel();
      _tooltipResizeTimer = Timer(
        const Duration(milliseconds: 120),
        _commitTooltipSizes,
      );
    }
  }

  void _commitTooltipSizes() {
    if (!mounted || _pendingTooltipSizes.isEmpty) return;
    setState(() {
      _tooltipSizes.addAll(_pendingTooltipSizes);
      _pendingTooltipSizes.clear();
      _geometry = null;
      _layoutStars = null;
      _lockedLayout = null;
      _layoutReferenceZoom = null;
    });
  }

  _MapGeometry _ensureGeometry(
    BuildContext context,
    double zoom,
    double ui,
    double nodeScale,
  ) {
    final nativeSize = Size(
      _mapTooltipWidth(context),
      MediaQuery.textScalerOf(context).scale(1),
    );
    if (_layoutEnvironment != nativeSize) {
      _layoutEnvironment = nativeSize;
      _tooltipSizes.clear();
      _pendingTooltipSizes.clear();
      _tooltipResizeTimer?.cancel();
      _lockedLayout = null;
      _layoutReferenceZoom = null;
      _geometry = null;
    }
    final cached = _geometry;
    if (cached != null &&
        _layoutZoom == zoom &&
        identical(_layoutStars, widget.stars)) {
      return cached;
    }

    final stars = widget.stars;
    final nodes = <_MapNode>[];
    for (var i = 0; i < stars.length; i++) {
      final metrics = _NodeMetrics.of(
        stars[i],
        nodeScale * (widget.refinedPresentation ? 0.76 : 1),
        uniformSize: widget.uniformNodeSize,
      );
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
            leaderRadius:
                node.metrics.coreOuter *
                (widget.nodeStyle == ConstellationNodeStyle.beacon ? 0.32 : 1),
            // The crowded middle of the shape gets first pick of the free
            // space; the outer stars can always reach into the open sky.
            priority: -(node.center - anchor).distance,
          ),
      ],
      labelSize: (id, _) =>
          _nativeTooltipSize(context, stars[id]) * (widget.tooltipScale * ui),
      labelScales: const [1],
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
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
            number(_nativeTooltipSize(context, star).height),
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
      number(_mapTooltipWidth(context)),
      number(widget.tooltipScale),
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

  Widget _focusCard(int index, Widget child) {
    if (!widget.refinedPresentation && !widget.selectionEnabled) return child;
    final selected = widget.focusedStarIndex ?? _selectedIndex;
    Offset? pointerStart;
    return AnimatedOpacity(
      key: ValueKey('constellation-card-focus-$index'),
      opacity: selected == null || selected == index ? 1 : 0.32,
      duration: const Duration(milliseconds: 220),
      child: widget.selectionEnabled && !widget.fadeStructureOnFocus
          ? Listener(
              onPointerDown: (event) => pointerStart = event.position,
              onPointerUp: (event) {
                if (!_gestureUsedMultiplePointers &&
                    pointerStart != null &&
                    (event.position - pointerStart!).distance < 8) {
                  setState(() => _selectedIndex = index);
                }
              },
              child: child,
            )
          : child,
    );
  }

  Widget _focusStructure(int? index, Widget child) {
    if (!widget.fadeStructureOnFocus) return child;
    final selected = widget.focusedStarIndex ?? _selectedIndex;
    return AnimatedOpacity(
      key: ValueKey('constellation-structure-focus-$index'),
      opacity: selected == null || selected == index ? 1 : 0.32,
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final matrix = widget.transformation.value;
    final zoom = matrix.entry(0, 0);
    if (zoom <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    final ui = _uiScale(zoom);
    final geometry = _ensureGeometry(context, zoom, ui, _nodeScale(zoom));
    _frameCompleteMap(geometry);
    final translation = Offset(matrix.entry(0, 3), matrix.entry(1, 3));
    _translation = translation;
    final layout = geometry.layout;
    final stars = widget.stars;

    final selected = widget.fadeStructureOnFocus
        ? widget.focusedStarIndex ?? _selectedIndex
        : null;
    final discs = widget.fadeStructureOnFocus
        ? [
            for (final node in geometry.nodes)
              (node.center + translation, node.metrics.diameter / 2),
          ]
        : <(Offset, double)>[];
    final selectedLeaders = <_Leader>[];
    final tooltipFrame = _tooltipFrameWidth();
    final edgeStroke =
        _kConstellationEdgeWidth *
        geometry.uiScale *
        (widget.refinedPresentation ? 0.4 : 1);
    final leaders = <_Leader>[];
    for (final placement in layout.placements.values) {
      final focused = selected == placement.id;
      (focused ? selectedLeaders : leaders).add(
        _Leader(
          path: placement.path.shift(translation),
          color: starKindColor(
            stars[placement.id].kind,
            colors,
            lit: stars[placement.id].lit,
          ).withValues(alpha: focused ? 1 : _kLabelLeaderOpacity),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The glow is atmospheric: it stays below both the constellation and
        // annotation lines instead of washing over the graph.
        for (final node in geometry.nodes)
          if (node.metrics.glowStrength > 0 && !widget.refinedPresentation)
            Positioned(
              left: node.center.dx + translation.dx - node.outer,
              top: node.center.dy + translation.dy - node.outer,
              width: node.outer * 2,
              height: node.outer * 2,
              child: IgnorePointer(
                child: _focusStructure(
                  node.index,
                  _StarGlow(star: stars[node.index], metrics: node.metrics),
                ),
              ),
            ),
        if (widget.luminousStructure)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ConstellationStructureGlowPainter(
                  segments: [
                    for (final (a, b) in geometry.segments)
                      (a + translation, b + translation),
                  ],
                  discs: [
                    for (final node in geometry.nodes)
                      (node.center + translation, node.metrics.diameter / 2),
                  ],
                  strokeWidth: edgeStroke,
                  focusedDiscIndex: widget.fadeStructureOnFocus
                      ? widget.focusedStarIndex ?? _selectedIndex
                      : null,
                  inactiveOpacity: 0.32,
                  color: widget.structureColor ?? colors.night,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: _focusStructure(
            null,
            CustomPaint(
              painter: _LinesPainter(
                segments: [
                  for (final (a, b) in geometry.segments)
                    (a + translation, b + translation),
                ],
                edgeColor: widget.structureColor ?? colors.night,
                edgeWidth: edgeStroke,
                leaderWidth:
                    _kLabelLeaderWidth *
                    geometry.uiScale *
                    (widget.refinedPresentation ? 0.55 : 1),
                leaders: leaders,
                discs: discs,
              ),
            ),
          ),
        ),
        if (selectedLeaders.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('constellation-focused-connector'),
                painter: _LinesPainter(
                  segments: const [],
                  edgeColor: Colors.white,
                  edgeWidth: 0,
                  leaderWidth:
                      _kLabelLeaderWidth *
                      geometry.uiScale *
                      (widget.refinedPresentation ? 0.55 : 1),
                  leaders: selectedLeaders,
                  discs: discs,
                ),
              ),
            ),
          ),
        for (final node in geometry.nodes)
          Positioned(
            left: node.center.dx + translation.dx - node.outer,
            top: node.center.dy + translation.dy - node.outer,
            width: node.outer * 2,
            height: node.outer * 2,
            child: IgnorePointer(
              child: _focusStructure(
                node.index,
                _StarButton(
                  star: stars[node.index],
                  metrics: node.metrics,
                  refined: widget.refinedPresentation,
                  nodeStyle: widget.nodeStyle,
                  simplified: widget.simplifiedNodes,
                  structureColor: widget.structureColor,
                  innerRingColor: widget.luminousStructure
                      ? widget.tooltipFrameColor ?? colors.night
                      : null,
                  innerRingWidth: widget.luminousStructure
                      ? galaxyTooltipPadding *
                            widget.tooltipScale *
                            geometry.uiScale
                      : 0,
                ),
              ),
            ),
          ),
        for (final placement in layout.placements.values)
          Positioned.fromRect(
            key: ValueKey((
              stars[placement.id].entityId,
              stars[placement.id].slotSequence,
            )),
            rect: placement.rect.shift(translation),
            child: _focusCard(
              placement.id,
              FittedBox(
                child: SizedBox(
                  width: _nativeTooltipSize(context, stars[placement.id]).width,
                  height: _nativeTooltipSize(
                    context,
                    stars[placement.id],
                  ).height,
                  child: OverflowBox(
                    minWidth: _mapTooltipWidth(context),
                    maxWidth: _mapTooltipWidth(context),
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: _TooltipSizeObserver(
                      onSize: (size) =>
                          _onTooltipSize(_tooltipId(stars[placement.id]), size),
                      child: CustomPaint(
                        painter: selected == placement.id
                            ? ConstellationTooltipGlowPainter(
                                frameWidth: tooltipFrame,
                                radius: kRadiusCard + tooltipFrame,
                              )
                            : null,
                        child: Material(
                          color: selected == placement.id
                              ? Colors.white
                              : widget.tooltipFrameColor ??
                                    widget.structureColor ??
                                    colors.night,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              kRadiusCard + tooltipFrame,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(tooltipFrame),
                            child: SkyTooltipMenuScope(
                              controller: _menuController,
                              showVisual: widget.showCardVisual,
                              focused:
                                  !widget.fadeStructureOnFocus ||
                                  (!widget.selectionEnabled &&
                                      !widget.refinedPresentation) ||
                                  selected == placement.id,
                              onCardTap: widget.selectionEnabled
                                  ? () => setState(
                                      () => _selectedIndex = placement.id,
                                    )
                                  : null,
                              menuId: (
                                stars[placement.id].entityId,
                                stars[placement.id].slotSequence,
                              ),
                              child:
                                  widget.cardBuilder?.call(
                                    context,
                                    stars[placement.id],
                                  ) ??
                                  Text(stars[placement.id].label),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Measures native tooltip bounds before the map's uniform zoom transform.
class _TooltipSizeObserver extends SingleChildRenderObjectWidget {
  const _TooltipSizeObserver({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TooltipSizeRenderBox(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _TooltipSizeRenderBox renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _TooltipSizeRenderBox extends RenderProxyBox {
  _TooltipSizeRenderBox(this.onSize);
  ValueChanged<Size> onSize;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _lastSize) return;
    _lastSize = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
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

  factory _NodeMetrics.of(
    ConstellationStar star,
    double ui, {
    bool uniformSize = false,
  }) {
    switch (star.kind) {
      // Legacy comparisons keep empty slots smaller; the uniform lab uses one size.
      case StarKind.nascent:
        return _NodeMetrics(
          diameter:
              ((uniformSize ? 40 : 32) + _kConstellationEdgeWidth * 2) * ui,
          strokeWidth: _kNodeStrokeWidth * ui,
          glowStrength: 0,
        );
      case StarKind.dead:
        return _NodeMetrics(
          diameter: (40 + _kConstellationEdgeWidth * 2) * ui,
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
          diameter: (40 + _kConstellationEdgeWidth * 2) * ui,
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
  const _StarButton({
    required this.star,
    required this.metrics,
    this.structureColor,
    this.innerRingColor,
    this.innerRingWidth = 0,
    this.refined = false,
    this.simplified = false,
    this.nodeStyle = ConstellationNodeStyle.disc,
  });

  final Color? structureColor;

  final Color? innerRingColor;
  final double innerRingWidth;
  final bool refined;
  final bool simplified;
  final ConstellationNodeStyle nodeStyle;

  final ConstellationStar star;
  final _NodeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = star.kind;
    // The same nesting as a tooltip: dark navy frame, card border, then
    // the lighter card surface. Keep the glyph and its inner disc unchanged.
    final kindColor = starKindColor(kind, colors, lit: star.lit);
    final diameter = metrics.diameter;
    if (nodeStyle == ConstellationNodeStyle.beacon) {
      return Center(
        child: Container(
          width: diameter * 0.32,
          height: diameter * 0.32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: kindColor, width: diameter * 0.07),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35),
                blurRadius: diameter * 0.55,
              ),
            ],
          ),
        ),
      );
    }
    if (nodeStyle == ConstellationNodeStyle.glyph) {
      return Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.night,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(diameter * 0.08),
            child: Icon(kind.icon, size: diameter * 0.7, color: kindColor),
          ),
        ),
      );
    }
    final nascent = kind == StarKind.nascent;
    final photoPath = star.photoPath;
    final ui = metrics.strokeWidth / _kNodeStrokeWidth;
    final frameWidth = _kConstellationEdgeWidth * ui * (refined ? 0.53 : 1);
    final innerDiameter = diameter - frameWidth * 2;

    final disc = Container(
      width: diameter,
      height: diameter,
      padding: EdgeInsets.all(frameWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: structureColor ?? colors.night,
      ),
      child: Container(
        padding: EdgeInsets.all(math.min(innerRingWidth, innerDiameter * 0.2)),
        decoration: innerRingColor == null
            ? null
            : BoxDecoration(shape: BoxShape.circle, color: innerRingColor),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.nightPanel,
            border: Border.all(
              color: colors.nightBorder,
              width: metrics.strokeWidth,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          // The star's photo, if it has one, fills the disc behind everything
          // else at half strength — its center, cropped to the circle.
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (!simplified && photoPath != null && photoPath.isNotEmpty)
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
                  child: nascent || simplified
                      ? Icon(
                          kind.icon,
                          size: innerDiameter * (simplified ? 0.62 : 0.5),
                          color: kindColor,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              kind.icon,
                              size: innerDiameter * (refined ? 0.55 : 0.4),
                              color: kindColor,
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: innerDiameter * 0.04,
                              ),
                              child: IntensityDots(
                                intensity: star.intensity,
                                color: colors.gold,
                                dotSize: innerDiameter * 0.038,
                                spacing: innerDiameter * 0.024,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
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
    this.discs = const [],
  });

  final List<(Offset, Offset)> segments;
  final Color edgeColor;
  final double edgeWidth;
  final double leaderWidth;
  final List<_Leader> leaders;
  final List<(Offset, double)> discs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (discs.isNotEmpty) {
      canvas.clipPath(constellationOutsideDiscs(Offset.zero & size, discs));
    }

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
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinesPainter old) => true;
}
