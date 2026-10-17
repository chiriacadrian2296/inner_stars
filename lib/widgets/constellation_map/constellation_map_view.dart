import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import '../../models/star_kind.dart';
import '../../models/constellation_card_layout.dart';
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

export '../../models/constellation_card_layout.dart';

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
/// — and the map can be carried freely anywhere so long as some part of the
/// graph stays on screen. Every visual element follows the camera's linear
/// zoom factor, so the whole scene is laid out once at the fit zoom and the
/// camera merely transforms it: panning and zooming rebuild nothing.
enum ConstellationNodeStyle { disc, beacon, glyph }

enum ConstellationConnectorStyle { original, discreet, numbered }

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
    this.connectorStyle = ConstellationConnectorStyle.original,
    this.onViewStar,
    this.onFlyStar,
    this.cardLayout = ConstellationCardLayout.aroundShape,
    this.numberedTabStyle = false,
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

  /// How far the map draws above a star's centre at visual scale [ui]: half
  /// its disc, plus the number tab resting on it when [numberedTabs].
  static double reachAboveStar({
    required double ui,
    required double tooltipScale,
    bool numberedTabs = true,
  }) =>
      (40 + _kConstellationEdgeWidth * 2) / 2 * ui +
      (numberedTabs
          ? _ConstellationMapViewState._referenceTabHeight * tooltipScale * ui
          : 0);

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
  final ConstellationConnectorStyle connectorStyle;
  final ValueChanged<ConstellationStar>? onViewStar;
  final ValueChanged<ConstellationStar>? onFlyStar;
  final ConstellationCardLayout cardLayout;
  final bool numberedTabStyle;

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
  final Map<(int, int?), Widget> _cardContents = {};
  _MapGeometry? _geometry;

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

  /// How far a piece of the graph must reach inside the viewport's edge for
  /// it to count as "on screen" - enough to still read as part of the shape.
  static const _visibleInset = 24.0;

  double get _minZoom => math.min(
    math.min(
      widget.fitScale * _minZoomFactor,
      _overviewZoom ?? double.infinity,
    ),
    _wholeMapZoom ?? double.infinity,
  );

  /// The scene's content - shape and every card - in scene units, kept by
  /// the last build for [_wholeMapZoom].
  Rect? _contentBounds;

  /// How much of the screen the whole map fills at the farthest zoom out.
  static const _wholeMapFill = 0.85;

  /// The zoom that shows the whole map with some air around it. A phone
  /// opens close in, so this, not the fixed factor, sets how far out it can
  /// go: always far enough to take in everything at once.
  double? get _wholeMapZoom {
    final bounds = _contentBounds;
    final size = context.size;
    if (bounds == null || bounds.isEmpty || size == null || size.isEmpty) {
      return null;
    }
    return _sceneZoom *
        _wholeMapFill *
        math.min(size.width / bounds.width, size.height / bounds.height);
  }

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
    if (!widget.autoFrame) {
      _frameZoom = _initialTransform.entry(0, 0);
    }
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
  /// just enough that some part of the graph is still on screen.
  void _apply(double zoom, Offset pan) {
    final constrained = _constrainPan(zoom, pan);
    widget.transformation.value = Matrix4.identity()
      ..translateByDouble(constrained.dx, constrained.dy, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1);
  }

  /// [pan] itself if any piece of the graph - a card or label, a star or a
  /// line - reaches inside the (slightly inset) viewport at this [zoom];
  /// otherwise the closest pan that brings the nearest piece back to that
  /// edge. That is the whole boundary: the map can be dragged anywhere, like
  /// the sky, but the shape never leaves sight entirely.
  Offset _constrainPan(double zoom, Offset pan) {
    final size = context.size;
    if (size == null || size.isEmpty || widget.stars.isEmpty) return pan;
    final inset = math.min(
      _visibleInset,
      math.min(size.width, size.height) / 2,
    );
    final visible = (Offset.zero & size).deflate(inset);
    // The scene is laid out once at the reference zoom; this zoom scales it
    // and the pan shifts it onto the screen.
    final geometry = _sceneGeometry(context);
    final scale = zoom / _sceneZoom;
    double axis(double low, double high, double min, double max) =>
        high < min ? min - high : (low > max ? max - low : 0);
    var bestShift = Offset.zero;
    var bestDistance = double.infinity;
    bool consider(Rect piece) {
      final rect = Rect.fromLTRB(
        piece.left * scale,
        piece.top * scale,
        piece.right * scale,
        piece.bottom * scale,
      ).shift(pan);
      final shift = Offset(
        axis(rect.left, rect.right, visible.left, visible.right),
        axis(rect.top, rect.bottom, visible.top, visible.bottom),
      );
      final distance = shift.distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestShift = shift;
      }
      return distance == 0;
    }

    for (final placement in geometry.layout.placements.values) {
      if (consider(placement.rect)) return pan;
    }
    for (final node in geometry.nodes) {
      if (consider(
        Rect.fromCircle(center: node.center, radius: node.metrics.diameter / 2),
      )) {
        return pan;
      }
    }
    // A line can cross the screen with both its stars outside. Use its exact
    // nearest displacement instead of sampling points along it every frame.
    for (final (a, b) in geometry.segments) {
      final shift = _segmentShiftIntoRect(
        a * scale + pan,
        b * scale + pan,
        visible,
      );
      final distance = shift.distanceSquared;
      if (distance == 0) return pan;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestShift = shift;
      }
    }
    return pan + bestShift;
  }

  static Offset _segmentShiftIntoRect(Offset a, Offset b, Rect rect) {
    if (rect.contains(a) || rect.contains(b)) return Offset.zero;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    for (var i = 0; i < corners.length; i++) {
      if (_segmentsIntersect(a, b, corners[i], corners[(i + 1) % 4])) {
        return Offset.zero;
      }
    }
    var best = Offset.zero;
    var bestDistance = double.infinity;
    void consider(Offset onSegment, Offset inRect) {
      final shift = inRect - onSegment;
      final distance = shift.distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = shift;
      }
    }

    Offset clampToRect(Offset point) => Offset(
      point.dx.clamp(rect.left, rect.right).toDouble(),
      point.dy.clamp(rect.top, rect.bottom).toDouble(),
    );
    consider(a, clampToRect(a));
    consider(b, clampToRect(b));
    final delta = b - a;
    final lengthSquared = delta.distanceSquared;
    for (final corner in corners) {
      final t = lengthSquared == 0
          ? 0.0
          : ((corner - a).dx * delta.dx + (corner - a).dy * delta.dy) /
                lengthSquared;
      final onSegment = a + delta * t.clamp(0.0, 1.0);
      consider(onSegment, corner);
    }
    return best;
  }

  static bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    final abC = cross(a, b, c);
    final abD = cross(a, b, d);
    final cdA = cross(c, d, a);
    final cdB = cross(c, d, b);
    bool overlaps(double a1, double a2, double b1, double b2) =>
        math.max(math.min(a1, a2), math.min(b1, b2)) <=
        math.min(math.max(a1, a2), math.max(b1, b2));
    return abC * abD <= 0 &&
        cdA * cdB <= 0 &&
        overlaps(a.dx, b.dx, c.dx, d.dx) &&
        overlaps(a.dy, b.dy, c.dy, d.dy);
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
    // Ran into the "some of the graph stays visible" limit: stop pushing.
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
    // One shared scale preserves the Casa lab's proportions between nodes,
    // lines, number tabs and cards in every constellation.
    return zoom / widget.fitScale;
  }

  void _frameCompleteMap(_MapGeometry geometry) {
    if (!widget.autoFrame ||
        _overviewFitted ||
        _fitScheduled ||
        _tooltipSizes.length < widget.stars.length ||
        _pendingTooltipSizes.isNotEmpty) {
      return;
    }
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
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
      // [bounds] is in scene units; [ratio] maps them onto the screen, never
      // zooming in past the cap relative to the camera it opened with.
      final cap = widget.cardLayout != ConstellationCardLayout.aroundShape
          ? 2.0
          : 1.0;
      final ratio = math.min(
        cap * _zoom / _sceneZoom,
        math.min(
          available.width / bounds!.width,
          available.height / bounds!.height,
        ),
      );
      final zoom = _sceneZoom * ratio;
      // Re-size the frame for this overview first: it slightly changes the
      // cards' size, so the fit runs again on the re-measured layout.
      final frameZoom = _frameZoom;
      if (widget.matchTooltipFrameToNode &&
          _framePasses < 3 &&
          (frameZoom == null || (zoom / frameZoom - 1).abs() > 0.01)) {
        _framePasses++;
        setState(() => _frameZoom = zoom);
        return;
      }
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
    // The screen reframes when it turns (or resizes): double tap returns to
    // the new framing, and the card frame is sized for its zoom.
    final home = widget.homeTransform;
    if (home != null && home != oldWidget.homeTransform) {
      _initialTransform = Matrix4.copy(home);
      if (!widget.autoFrame) _frameZoom = home.entry(0, 0);
    }
    if (oldWidget.cardLayout != widget.cardLayout) {
      _overviewFitted = false;
      _framePasses = 0;
      _selectedIndex = null;
    }
    final selected = _selectedIndex;
    if (selected != null &&
        (selected >= widget.stars.length ||
            selected >= oldWidget.stars.length ||
            _tooltipId(widget.stars[selected]) !=
                _tooltipId(oldWidget.stars[selected]))) {
      _selectedIndex = null;
    }
    if (!identical(oldWidget.stars, widget.stars) ||
        oldWidget.canvasSize != widget.canvasSize ||
        oldWidget.fitScale != widget.fitScale ||
        oldWidget.edges != widget.edges ||
        oldWidget.tooltipScale != widget.tooltipScale ||
        oldWidget.nodeStyle != widget.nodeStyle ||
        oldWidget.cardLayout != widget.cardLayout ||
        oldWidget.uniformNodeSize != widget.uniformNodeSize ||
        oldWidget.matchTooltipFrameToNode != widget.matchTooltipFrameToNode ||
        oldWidget.showCardVisual != widget.showCardVisual ||
        oldWidget.refinedPresentation != widget.refinedPresentation) {
      _layoutStars = null;
      _lockedLayout = null;
      _layoutReferenceZoom = null;
    }
    if (!identical(oldWidget.stars, widget.stars) ||
        oldWidget.cardBuilder != widget.cardBuilder) {
      _cardContents.clear();
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
    _cardContents.clear();
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
        child: ClipRect(child: _buildCamera(context)),
      ),
    );
  }

  /// Every piece of the map - nodes, lines, glows, tabs and cards - scales
  /// linearly with the zoom, so the scene at any zoom is the scene at the
  /// reference zoom, scaled. It is built and laid out once; panning and
  /// zooming only move one transform layer over its cached picture.
  double get _sceneZoom => widget.fitScale;

  _MapGeometry _sceneGeometry(BuildContext context) => _ensureGeometry(
    context,
    _sceneZoom,
    _uiScale(_sceneZoom),
    _nodeScale(_sceneZoom),
  );

  /// Room around the scene's content for glows and the cards' number tabs,
  /// which paint beyond their own boxes.
  static const _sceneMargin = 96.0;

  Widget _buildCamera(BuildContext context) {
    if (_sceneZoom <= 0) return const SizedBox.shrink();
    final geometry = _sceneGeometry(context);
    _frameCompleteMap(geometry);
    var bounds = Rect.zero;
    var first = true;
    void include(Rect rect) {
      bounds = first ? rect : bounds.expandToInclude(rect);
      first = false;
    }

    for (final node in geometry.nodes) {
      include(Rect.fromCircle(center: node.center, radius: node.outer));
    }
    for (final placement in geometry.layout.placements.values) {
      include(placement.rect);
    }
    _contentBounds = bounds;
    bounds = bounds.inflate(_sceneMargin * geometry.uiScale);
    final scene = RepaintBoundary(
      child: SizedBox.fromSize(
        size: bounds.size,
        child: _buildOverlay(context, geometry, -bounds.topLeft),
      ),
    );
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: 0,
      minHeight: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: AnimatedBuilder(
        animation: widget.transformation,
        child: scene,
        builder: (context, child) {
          final scale = _zoom / _sceneZoom;
          final origin = _pan + bounds.topLeft * scale;
          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(origin.dx, origin.dy, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            child: child,
          );
        },
      ),
    );
  }

  ConstellationStar? _hitTest(Offset screen) {
    final geometry = _geometry;
    final scale = _zoom / _sceneZoom;
    if (geometry == null || scale <= 0) return null;
    final point = (screen - _pan) / scale;
    ConstellationStar? best;
    var bestDistance = double.infinity;
    for (final node in geometry.nodes) {
      // A little beyond the visible button, so a thumb doesn't have to be
      // precise on a small one.
      final distance = (node.center - point).distance;
      if (distance <= node.outer + 6 / scale && distance < bestDistance) {
        bestDistance = distance;
        best = widget.stars[node.index];
      }
    }
    if (best != null) return best;
    return null;
  }

  (int, int?) _tooltipId(ConstellationStar star) =>
      (star.entityId, star.slotSequence);

  Widget _cardContent(BuildContext context, ConstellationStar star) =>
      _cardContents.putIfAbsent(
        _tooltipId(star),
        () => widget.cardBuilder?.call(context, star) ?? Text(star.label),
      );

  /// Screen thickness of a card's frame at the overview, the same for every
  /// constellation however much room its shape and cards need.
  static const _kOverviewFrameOnScreen = 3.0;

  /// The overview zoom the frame is sized for. The map then scales it along
  /// with everything else, so zooming in still enlarges cards as one image.
  double? _frameZoom;
  int _framePasses = 0;
  bool _fitScheduled = false;

  double _tooltipFrameWidth() {
    if (!widget.matchTooltipFrameToNode) return galaxyTooltipPadding;
    final frameZoom = _frameZoom;
    if (frameZoom != null) {
      return _kOverviewFrameOnScreen /
          (widget.tooltipScale * _uiScale(frameZoom));
    }
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

  /// A card's size inside its frame. The frame's native thickness follows
  /// the card size setting, but the content inside keeps one width, so
  /// measurements are kept without the frame and stay valid when it changes:
  /// resizing cards reflows the layout in the same frame, with no re-measure.
  double _cardContentWidth(BuildContext context) =>
      _mapTooltipWidth(context) - 2 * _tooltipFrameWidth();

  Size _nativeTooltipSize(BuildContext context, ConstellationStar star) {
    final width = _mapTooltipWidth(context);
    final measured = _tooltipSizes[_tooltipId(star)];
    if (measured != null) {
      final frame = 2 * _tooltipFrameWidth();
      return Size(measured.width + frame, measured.height + frame);
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Size(
      width,
      SearchResultCard.defaultBodyHeight +
          math.max(0.0, textScale - 1) * 66 +
          galaxyTooltipPadding * 2,
    );
  }

  void _onTooltipSize((int, int?) id, Size measured) {
    if (!mounted || measured.isEmpty) return;
    final frame = 2 * _tooltipFrameWidth();
    final size = Size(measured.width - frame, measured.height - frame);
    final known = _tooltipSizes[id];
    if (known != null &&
        (known.width - size.width).abs() < 0.01 &&
        (known.height - size.height).abs() < 0.01) {
      return;
    }
    final initialMeasurement = !_tooltipSizes.containsKey(id);
    _pendingTooltipSizes[id] = size;
    _commitTooltipSizes(recompose: initialMeasurement);
  }

  void _commitTooltipSizes({bool recompose = false}) {
    if (!mounted || _pendingTooltipSizes.isEmpty) return;
    setState(() {
      _tooltipSizes.addAll(_pendingTooltipSizes);
      _pendingTooltipSizes.clear();
      _geometry = null;
      _layoutStars = null;
      if (recompose) {
        _lockedLayout = null;
        _layoutReferenceZoom = null;
      }
    });
  }

  LabelLayout _resizeLabels(
    LabelLayout layout,
    List<_MapNode> nodes,
    double ui,
  ) => resizeConstellationLabels(
    layout,
    {
      for (final node in nodes)
        node.index:
            _nativeTooltipSize(context, widget.stars[node.index]) *
            (widget.tooltipScale * ui),
    },
    {for (final node in nodes) node.index: node.center},
  );

  /// Whether the numbered cards stand in side columns rather than in a grid
  /// below the shape. A phone turned sideways has no room below the shape,
  /// while the side rails show every card at once: it always takes them.
  /// Otherwise side columns need a wide or landscape window.
  bool _sidesInUse(BuildContext context) {
    if (widget.cardLayout == ConstellationCardLayout.aroundShape) return false;
    final viewport = MediaQuery.sizeOf(context);
    final phoneLandscape =
        viewport.width > viewport.height && viewport.shortestSide < 600;
    return phoneLandscape ||
        (widget.cardLayout == ConstellationCardLayout.sideColumns &&
            (viewport.width >= 900 || viewport.width > viewport.height));
  }

  _MapGeometry _ensureGeometry(
    BuildContext context,
    double zoom,
    double ui,
    double nodeScale,
  ) {
    // Only what changes a card's content invalidates its measurements; a
    // thicker or thinner frame around it does not.
    final nativeSize = Size(
      _cardContentWidth(context),
      MediaQuery.textScalerOf(context).scale(1),
    );
    if (_layoutEnvironment != nativeSize) {
      _layoutEnvironment = nativeSize;
      _tooltipSizes.clear();
      _pendingTooltipSizes.clear();
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

    if (widget.cardLayout != ConstellationCardLayout.aroundShape &&
        nodes.isNotEmpty) {
      final bounds = nodes
          .map((n) => Rect.fromCircle(center: n.center, radius: n.outer))
          .reduce((a, b) => a.expandToInclude(b));
      final cardSizes = [
        for (final star in stars)
          _nativeTooltipSize(context, star) * (widget.tooltipScale * ui),
      ];
      final layout = _sidesInUse(context)
          ? layoutNumberedSideColumns(
              constellationBounds: bounds,
              cardSizes: cardSizes,
              scale: ui,
              maxColumnHeight: bounds.height,
            )
          : layoutNumberedCardGrid(
              constellationBounds: bounds,
              cardSizes: cardSizes,
              columns: 2,
              scale: ui,
            );
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

    final lockedLayout = _lockedLayout;
    final referenceZoom = _layoutReferenceZoom;
    if (lockedLayout != null && referenceZoom != null) {
      _layoutZoom = zoom;
      _layoutStars = widget.stars;
      return _geometry = _MapGeometry(
        nodes: nodes,
        segments: segments,
        layout: _resizeLabels(
          _scaleLayout(lockedLayout, zoom / referenceZoom),
          nodes,
          ui,
        ),
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
        layout: _resizeLabels(
          _scaleLayout(stored.layout, zoom / stored.referenceZoom),
          nodes,
          ui,
        ),
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

  Path _discreetLeader(LabelPlacement placement, double ui) {
    final a = placement.lineStart;
    final b = placement.lineEnd;
    final points = placement.horizontal
        ? [
            a,
            Offset((a.dx + b.dx) / 2, a.dy),
            Offset((a.dx + b.dx) / 2, b.dy),
            b,
          ]
        : [
            a,
            Offset(a.dx, (a.dy + b.dy) / 2),
            Offset(b.dx, (a.dy + b.dy) / 2),
            b,
          ];
    final path = Path()..moveTo(a.dx, a.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final incoming = p - points[i - 1];
      final outgoing = points[i + 1] - p;
      final radius = math.min(
        5 * ui,
        math.min(incoming.distance, outgoing.distance) / 2,
      );
      if (radius < 0.001) {
        path.lineTo(p.dx, p.dy);
        continue;
      }
      final start = p - incoming / incoming.distance * radius;
      final end = p + outgoing / outgoing.distance * radius;
      path.lineTo(start.dx, start.dy);
      path.quadraticBezierTo(p.dx, p.dy, end.dx, end.dy);
    }
    return path..lineTo(b.dx, b.dy);
  }

  Widget _referenceBadge(int index, double size, bool focused) => Container(
    key: ValueKey('constellation-reference-$index'),
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: focused ? Colors.white : context.colors.night,
      border: Border.all(
        color: Colors.white.withValues(alpha: focused ? 1 : 0.65),
        width: size * 0.055,
      ),
    ),
    child: Text(
      '${index + 1}',
      style: TextStyle(
        color: focused ? context.colors.night : Colors.white,
        fontSize: size * 0.52,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );

  /// The grid layout labels each card/star pair with a tab centred above
  /// the element; an active pair gains a white glow.
  bool get _variedReferences => widget.numberedTabStyle;

  static const double _referenceTabHeight = 27;

  /// Fixed so a star's tab can work out where its corners meet the rim.
  static double _referenceTabWidth(int index) => index < 9 ? 34 : 44;

  /// [stem] lengthens the tab downwards without moving its numeral, so a
  /// star's tab can reach down to the rim. A [trapezoid] tab widens at its
  /// base by its slanted sides, keeping the same top for the numeral.
  Widget _variedReferenceBadge(
    int index,
    double u,
    bool focused, {
    double stem = 0,
    bool trapezoid = false,
    bool sideways = false,
    bool broadOnRight = true,
    bool dimmed = false,
    AxisDirection side = AxisDirection.up,
  }) {
    // A star's tab may stand beside or below its star: [side] is where it
    // points, and its stem always reaches back toward the circle.
    final across = side == AxisDirection.left || side == AxisDirection.right;
    final starTab = !trapezoid && !sideways;
    final colors = context.colors;
    final shadows = focused
        ? [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.7),
              blurRadius: 8 * u,
              spreadRadius: 0.5 * u,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 18 * u,
              spreadRadius: 2 * u,
            ),
          ]
        : null;
    final numeral = '${index + 1}';
    final numeralStyle = TextStyle(
      fontSize: 15.5 * u,
      fontWeight: FontWeight.w800,
      height: 1,
      // Trim ascent and descent equally so digits sit on the true centre.
      leadingDistribution: TextLeadingDistribution.even,
    );
    // At rest the tab matches the cards' frame.
    final fill = focused
        ? Colors.white
        : widget.tooltipFrameColor ?? widget.structureColor ?? colors.night;
    return Container(
      key: ValueKey('constellation-reference-$index'),
      width: starTab && across
          ? (_referenceTabHeight + stem) * u
          : sideways
          ? _referenceTabHeight * u
          : (_referenceTabWidth(index) +
                    (trapezoid
                        ? 2 *
                              _TrapezoidTabBorder.sideRatio *
                              _referenceTabHeight
                        : 0)) *
                u,
      height: starTab && across
          ? _referenceTabWidth(index) * u
          : sideways
          ? (_referenceTabWidth(index) +
                    2 * _TrapezoidTabBorder.sideRatio * _referenceTabHeight) *
                u
          : (_referenceTabHeight + stem) * u,
      // A trapezoid's weight sits low, so its extra room goes above the
      // numeral and the numeral drops a touch to look centred. A star tab's
      // stem is room on the side facing its star.
      padding: starTab
          ? EdgeInsets.only(
              top: side == AxisDirection.down ? stem * u : 0,
              bottom: side == AxisDirection.up ? stem * u : 0,
              left: side == AxisDirection.right ? stem * u : 0,
              right: side == AxisDirection.left ? stem * u : 0,
            )
          : EdgeInsets.only(
              top: (trapezoid && !sideways ? 5.5 : 0) * u,
              bottom: stem * u,
            ),
      alignment: Alignment.center,
      decoration: sideways
          ? ShapeDecoration(
              color: fill,
              shape: _RotatedTrapezoidTabBorder(broadOnRight: broadOnRight),
              shadows: shadows,
            )
          : trapezoid
          ? ShapeDecoration(
              color: fill,
              shape: const _TrapezoidTabBorder(),
              shadows: shadows,
            )
          : BoxDecoration(
              color: fill,
              // Rounded on the outer end, square where it meets the star.
              borderRadius: switch (side) {
                AxisDirection.up => BorderRadius.vertical(
                  top: Radius.circular(6 * u),
                ),
                AxisDirection.down => BorderRadius.vertical(
                  bottom: Radius.circular(6 * u),
                ),
                AxisDirection.left => BorderRadius.horizontal(
                  left: Radius.circular(6 * u),
                ),
                AxisDirection.right => BorderRadius.horizontal(
                  right: Radius.circular(6 * u),
                ),
              },
              boxShadow: shadows,
            ),
      child: focused
          // Dark on white reads thinner than light on navy, so the active
          // numeral gets a hairline outline to keep the resting weight.
          ? Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  numeral,
                  style: numeralStyle.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 0.9 * u
                      ..strokeJoin = StrokeJoin.round
                      ..color = colors.night,
                  ),
                ),
                Text(
                  numeral,
                  style: numeralStyle.copyWith(color: colors.night),
                ),
              ],
            )
          // A tab whose pair is not selected stays solid, so the lines behind
          // never show through it; only its numeral recedes.
          : AnimatedOpacity(
              opacity: dimmed ? 0.32 : 1,
              duration: const Duration(milliseconds: 220),
              child: Text(
                numeral,
                style: numeralStyle.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
    );
  }

  Widget _numberedFrame(int index, Widget child) {
    if (widget.connectorStyle != ConstellationConnectorStyle.numbered) {
      return child;
    }
    final selected = widget.focusedStarIndex ?? _selectedIndex;
    if (_variedReferences) {
      // A card's tab always points at the constellation: up from the grid
      // below it, inward from the side columns - right edge on left-hand
      // cards, left edge on right-hand ones. The unpaired card the side
      // layout sets below the shape keeps its top tab, for the same reason.
      final sides = _sidesInUse(context);
      final isSideOverflow =
          sides &&
          widget.stars.length.isOdd &&
          index == widget.stars.length - 1;
      final sideTab = sides && !isSideOverflow;
      final tabOnRight = sideTab && index.isEven;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: sideTab
                    ? (tabOnRight
                          ? Alignment.centerRight
                          : Alignment.centerLeft)
                    : Alignment.topCenter,
                child: FractionalTranslation(
                  translation: sideTab
                      ? (tabOnRight ? const Offset(1, 0) : const Offset(-1, 0))
                      : const Offset(0, -1),
                  child: _variedReferenceBadge(
                    index,
                    1,
                    selected == index,
                    trapezoid: true,
                    sideways: sideTab,
                    broadOnRight: !tabOnRight,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -8,
          top: -8,
          child: IgnorePointer(
            child: _referenceBadge(index, 24, selected == index),
          ),
        ),
      ],
    );
  }

  Widget _starReference(
    _MapNode node,
    Offset translation,
    double scale,
    int? selected, {
    AxisDirection side = AxisDirection.up,
  }) {
    if (!_variedReferences) {
      return Positioned(
        left: node.center.dx + translation.dx + node.metrics.diameter * 0.28,
        top: node.center.dy + translation.dy - node.metrics.diameter * 0.5,
        child: IgnorePointer(
          child: _focusStructure(
            node.index,
            _referenceBadge(node.index, 24 * scale, selected == node.index),
          ),
        ),
      );
    }
    // The tab shows the same height above the star's top as a card's tab,
    // and its stem drops until the bottom corners meet the curving rim.
    final radius = node.metrics.diameter / 2;
    final halfWidth = _referenceTabWidth(node.index) * scale / 2;
    final sag = halfWidth >= radius
        ? radius
        : radius - math.sqrt(radius * radius - halfWidth * halfWidth);
    final stem = sag + 1 * scale;
    // The tab's inner end sits just inside the rim on its [side]; the
    // fractional shift then hangs the tab outward from that point.
    final reach = radius - stem;
    final (Offset inner, Offset hang) = switch (side) {
      AxisDirection.up => (Offset(0, -reach), const Offset(-0.5, -1)),
      AxisDirection.down => (Offset(0, reach), const Offset(-0.5, 0)),
      AxisDirection.left => (Offset(-reach, 0), const Offset(-1, -0.5)),
      AxisDirection.right => (Offset(reach, 0), const Offset(0, -0.5)),
    };
    final at = node.center + translation + inner;
    return Positioned(
      left: at.dx,
      top: at.dy,
      // Not faded with the rest of the structure: a see-through tab would
      // show the lines beneath it. It dims its numeral instead.
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: hang,
          child: _variedReferenceBadge(
            node.index,
            scale,
            selected == node.index,
            stem: stem / scale,
            dimmed: selected != null && selected != node.index,
            side: side,
          ),
        ),
      ),
    );
  }

  /// The scene in its own coordinates: [geometry] at the reference zoom,
  /// shifted by [translation] so the scene's bounds start at the origin.
  /// The camera never rebuilds this; it only transforms it.
  Widget _buildOverlay(
    BuildContext context,
    _MapGeometry geometry,
    Offset translation,
  ) {
    final colors = context.colors;
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
      if (widget.connectorStyle == ConstellationConnectorStyle.numbered) {
        continue;
      }
      final focused = selected == placement.id;
      (focused ? selectedLeaders : leaders).add(
        _Leader(
          path:
              (widget.connectorStyle == ConstellationConnectorStyle.discreet
                      ? _discreetLeader(placement, geometry.uiScale)
                      : placement.path)
                  .shift(translation),
          color: widget.connectorStyle == ConstellationConnectorStyle.discreet
              ? (focused ? Colors.white : colors.muted.withValues(alpha: 0.45))
              : starKindColor(
                  stars[placement.id].kind,
                  colors,
                  lit: stars[placement.id].lit,
                ).withValues(alpha: focused ? 1 : _kLabelLeaderOpacity),
        ),
      );
    }

    // Each star's tab goes above it unless a close star would cover it.
    final tabScale = widget.tooltipScale * geometry.uiScale;
    final tabSides = _variedReferences
        ? chooseStarTabSides(
            stars: [
              for (final node in geometry.nodes)
                (
                  id: node.index,
                  center: node.center,
                  radius: node.metrics.diameter / 2,
                ),
            ],
            across: (id) => _referenceTabWidth(id) * tabScale,
            out: _referenceTabHeight * tabScale,
          )
        : const <int, AxisDirection>{};
    // Keyed, so a star and its tab keep their state (fade animations) when
    // selection moves them to the top of the stack.
    Widget starTab(_MapNode node) => KeyedSubtree(
      key: ValueKey(('constellation-star-tab', node.index)),
      child: _starReference(
        node,
        translation,
        tabScale,
        selected,
        side: tabSides[node.index] ?? AxisDirection.up,
      ),
    );
    Widget starNode(_MapNode node) => KeyedSubtree(
      key: ValueKey(('constellation-star-node', node.index)),
      child: Positioned(
        left: node.center.dx + translation.dx - node.outer,
        top: node.center.dy + translation.dy - node.outer,
        width: node.outer * 2,
        height: node.outer * 2,
        child: IgnorePointer(
          child: RepaintBoundary(
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
                    ? (widget.matchTooltipFrameToNode
                              ? tooltipFrame
                              : galaxyTooltipPadding) *
                          widget.tooltipScale *
                          geometry.uiScale
                    : 0,
                innerBorderWidth: widget.matchTooltipFrameToNode
                    ? kBorderWidth * widget.tooltipScale * geometry.uiScale
                    : null,
              ),
            ),
          ),
        ),
      ),
    );

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
                child: RepaintBoundary(
                  child: _focusStructure(
                    node.index,
                    _StarGlow(star: stars[node.index], metrics: node.metrics),
                  ),
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
                    (widget.connectorStyle ==
                            ConstellationConnectorStyle.discreet
                        ? 0.7
                        : _kLabelLeaderWidth) *
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
                      (widget.connectorStyle ==
                              ConstellationConnectorStyle.discreet
                          ? 0.7
                          : _kLabelLeaderWidth) *
                      geometry.uiScale *
                      (widget.refinedPresentation ? 0.55 : 1),
                  leaders: selectedLeaders,
                  discs: discs,
                ),
              ),
            ),
          ),
        // Grid tabs sit above the lines but tuck under their stars.
        if (widget.connectorStyle == ConstellationConnectorStyle.numbered &&
            _variedReferences)
          for (final node in geometry.nodes)
            if (node.index != selected) starTab(node),
        for (final node in geometry.nodes)
          if (node.index != selected || !_variedReferences) starNode(node),
        // The selected pair's tab rises above every other star, so a close
        // neighbour - even faded - never covers it; its own star still sits
        // on top, keeping the tab tucked under its circle.
        if (_variedReferences &&
            widget.connectorStyle == ConstellationConnectorStyle.numbered)
          for (final node in geometry.nodes)
            if (node.index == selected) starTab(node),
        if (_variedReferences)
          for (final node in geometry.nodes)
            if (node.index == selected) starNode(node),
        if (widget.connectorStyle == ConstellationConnectorStyle.numbered &&
            !_variedReferences)
          for (final node in geometry.nodes)
            _starReference(
              node,
              translation,
              widget.tooltipScale * geometry.uiScale,
              selected,
            ),
        // In numeric order whatever the layout filled first (side columns
        // go left rail, then right), so focus and reading follow the numbers.
        for (final placement
            in layout.placements.values.toList()
              ..sort((a, b) => a.id.compareTo(b.id)))
          Positioned.fromRect(
            key: ValueKey((
              stars[placement.id].entityId,
              stars[placement.id].slotSequence,
            )),
            rect: placement.rect.shift(translation),
            child: RepaintBoundary(
              child: _focusCard(
                placement.id,
                FittedBox(
                  child: SizedBox(
                    width: _nativeTooltipSize(
                      context,
                      stars[placement.id],
                    ).width,
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
                        onSize: (size) => _onTooltipSize(
                          _tooltipId(stars[placement.id]),
                          size,
                        ),
                        child: _numberedFrame(
                          placement.id,
                          CustomPaint(
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
                                  onView: widget.onViewStar == null
                                      ? null
                                      : () => widget.onViewStar!(
                                          stars[placement.id],
                                        ),
                                  onFly: widget.onFlyStar == null
                                      ? null
                                      : () => widget.onFlyStar!(
                                          stars[placement.id],
                                        ),
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
                                  child: _cardContent(
                                    context,
                                    stars[placement.id],
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
    this.innerBorderWidth,
    this.refined = false,
    this.simplified = false,
    this.nodeStyle = ConstellationNodeStyle.disc,
  });

  final Color? structureColor;

  final Color? innerRingColor;
  final double innerRingWidth;
  final double? innerBorderWidth;
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
              width: innerBorderWidth ?? metrics.strokeWidth,
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
    if (discs.isEmpty) {
      _paintLines(canvas);
    } else {
      paintOutsideDiscs(
        canvas,
        Offset.zero & size,
        discs,
        () => _paintLines(canvas),
      );
    }
  }

  void _paintLines(Canvas canvas) {
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
  bool shouldRepaint(_LinesPainter old) =>
      !listEquals(old.segments, segments) ||
      old.edgeColor != edgeColor ||
      old.edgeWidth != edgeWidth ||
      old.leaderWidth != leaderWidth ||
      !listEquals(old.leaders, leaders) ||
      !listEquals(old.discs, discs);
}

/// A tab with slanted sides and soft corners: rounded at the top, flaring
/// gently into the edge it rests on.
class _TrapezoidTabBorder extends ShapeBorder {
  const _TrapezoidTabBorder();

  /// Horizontal run of each side (flare plus slant) as a fraction of height.
  static const sideRatio = _flare + _slant;
  static const _flare = 0.22;
  static const _slant = 0.38;
  static const _corner = 0.32;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final h = rect.height;
    final flare = _flare * h;
    final corner = _corner * h;
    final baseLeft = Offset(rect.left + flare, rect.bottom);
    final topLeft = Offset(rect.left + flare + _slant * h, rect.top);
    final topRight = Offset(rect.right - flare - _slant * h, rect.top);
    final baseRight = Offset(rect.right - flare, rect.bottom);
    final up = (topLeft - baseLeft) / (topLeft - baseLeft).distance;
    final down = (baseRight - topRight) / (baseRight - topRight).distance;
    const across = Offset(1, 0);
    Path curve(Path path, Offset corner, Offset to) =>
        path..quadraticBezierTo(corner.dx, corner.dy, to.dx, to.dy);
    final path = Path()..moveTo(rect.left, rect.bottom);
    curve(path, baseLeft, baseLeft + up * flare);
    final a = topLeft - up * corner;
    path.lineTo(a.dx, a.dy);
    curve(path, topLeft, topLeft + across * corner);
    final b = topRight - across * corner;
    path.lineTo(b.dx, b.dy);
    curve(path, topRight, topRight + down * corner);
    final c = baseRight - down * flare;
    path.lineTo(c.dx, c.dy);
    curve(path, baseRight, rect.bottomRight);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// The exact top tab path rotated 90°, while its numeral remains upright.
class _RotatedTrapezoidTabBorder extends ShapeBorder {
  const _RotatedTrapezoidTabBorder({required this.broadOnRight});

  final bool broadOnRight;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final source = const _TrapezoidTabBorder().getOuterPath(
      Rect.fromLTWH(0, 0, rect.height, rect.width),
    );
    final transform = Matrix4.identity();
    if (broadOnRight) {
      // Visual 90° counter-clockwise: the broad bottom edge becomes right.
      transform
        ..setEntry(0, 0, 0)
        ..setEntry(0, 1, 1)
        ..setEntry(0, 3, rect.left)
        ..setEntry(1, 0, -1)
        ..setEntry(1, 1, 0)
        ..setEntry(1, 3, rect.top + rect.height);
    } else {
      // The mirrored rotation attaches the same broad edge on the left.
      transform
        ..setEntry(0, 0, 0)
        ..setEntry(0, 1, -1)
        ..setEntry(0, 3, rect.left + rect.width)
        ..setEntry(1, 0, 1)
        ..setEntry(1, 1, 0)
        ..setEntry(1, 3, rect.top);
    }
    return source.transform(transform.storage);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
