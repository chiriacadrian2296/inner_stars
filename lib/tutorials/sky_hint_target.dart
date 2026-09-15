import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../widgets/constellation_field.dart';
import 'tour_step_card.dart';

/// A tour step that cuts a real scrim hole around a point in the Sky's own
/// pan/zoom world — a supernova, a constellation, a star — rather than
/// around a widget.
///
/// The Sky is one hand-drawn canvas (`ConstellationField`/`SkySupernova`
/// paint everything themselves), so there is no `RenderBox` for a normal
/// `HintTarget` to measure the way it does everywhere else in the app (the
/// FAB, say). This uses `HintTarget.rectProvider` (a local `hint_kit`
/// addition, see its own doc comment) instead: every frame, it projects
/// [worldPosition] through [camera]/[zoom] via [worldToScreen] — the exact
/// same projection the sky's own rendering and hit-testing use — and
/// converts that point from the sky surface's local coordinates into the
/// enclosing `Overlay`'s, via [skySurfaceKey]'s `RenderBox`. [camera]/[zoom]
/// are callbacks rather than plain values so the hole tracks a live pan/zoom
/// gesture, not just the position the step happened to open on.
///
/// Always `passthrough: true`: like `TourGestureStep`, this is a "do the
/// gesture yourself" step, not a "tap Next" one — the card built by
/// [appTourGestureStepCard] only offers Skip, and the tour's own gesture
/// handler (`_flyToArea`, `_openStar`, etc.) is what actually advances it.
/// The card is pinned to the top-center of the screen
/// (`HintTarget.pinCardToTop`) rather than anchored next to the hole the
/// way a normal `HintTarget`'s is: the hole here moves with every pan/zoom
/// and can land right at a screen edge, and reading a card that chases a
/// moving point around is worse than one sitting still. It is still
/// [HintTarget]'s own card, though — sized to its content and painted in
/// the same `Overlay` layer as the scrim, so it can never end up looking
/// like it's sitting *under* it (unlike `TourGestureStep`'s separate,
/// independently-painted banner).
///
/// Meant to be reused by any future sky tour step that needs to point at
/// something painted on the canvas, not just `sky-navigation`.
class SkyHintTarget extends StatelessWidget {
  const SkyHintTarget({
    super.key,
    required this.tour,
    required this.order,
    required this.title,
    required this.description,
    required this.worldPosition,
    required this.skySurfaceKey,
    required this.camera,
    required this.zoom,
    this.spotlight = SpotlightShape.circle,
    this.spotlightPadding,
  });

  /// The tour this step belongs to.
  final String tour;

  /// This step's position within the tour.
  final int order;

  /// Heading of the step card.
  final String title;

  /// Body text of the step card.
  final String description;

  /// Where in the sky's world space to cut the hole — an azimuth/elevation
  /// pair in turns, same space as [PlacedConstellation.worldPosition]/
  /// [areaWorldPosition]. A callback (not a plain `Offset`) because some
  /// targets — `starWorldPosition`, in particular — only make sense
  /// relative to the current camera/zoom themselves and can legitimately
  /// have no answer right now (its own constellation off-screen), which is
  /// why this returns `null`-ably too.
  final Offset? Function(SkyCamera camera, double zoom, Size screenSize)
  worldPosition;

  /// Identifies the `RenderBox` [worldToScreen]'s projection is local to —
  /// the `Stack` the sky paints its background/constellations/supernovas
  /// into (`sky_screen.dart`'s own `_skySurfaceKey`), *not* necessarily the
  /// whole screen (an app bar or safe-area padding can offset it).
  final GlobalKey skySurfaceKey;

  /// The sky's current camera, read fresh on every measurement.
  final SkyCamera Function() camera;

  /// The sky's current zoom, read fresh on every measurement.
  final double Function() zoom;

  /// The shape of the hole cut around [worldPosition].
  final SpotlightShape spotlight;

  /// Grows the point [worldPosition] projects to into a visibly-sized hole
  /// — the projection itself is a single point, so without this the hole
  /// would have zero size. Same idea as `HintTarget.spotlightPadding` on a
  /// real widget, just starting from a point instead of that widget's own
  /// rect.
  final EdgeInsets? spotlightPadding;

  /// Projects [worldPosition] to a point in the enclosing `Overlay`'s
  /// coordinates, or `null` when it can't currently be measured (the sky
  /// surface isn't laid out yet, or the point is behind the camera).
  Rect? _computeRect() {
    final BuildContext? surfaceContext = skySurfaceKey.currentContext;
    if (surfaceContext == null) return null;
    final RenderObject? surfaceObject = surfaceContext.findRenderObject();
    if (surfaceObject is! RenderBox ||
        !surfaceObject.attached ||
        !surfaceObject.hasSize) {
      return null;
    }
    final RenderObject? overlayObject = Overlay.of(
      surfaceContext,
    ).context.findRenderObject();
    if (overlayObject is! RenderBox ||
        !overlayObject.attached ||
        !overlayObject.hasSize) {
      return null;
    }
    final SkyCamera resolvedCamera = camera();
    final double resolvedZoom = zoom();
    final Offset? world = worldPosition(
      resolvedCamera,
      resolvedZoom,
      surfaceObject.size,
    );
    if (world == null) return null;
    final ScreenProjection? projection = worldToScreen(
      world,
      resolvedCamera,
      resolvedZoom,
      surfaceObject.size,
    );
    if (projection == null) return null;
    final Offset origin = surfaceObject.localToGlobal(
      projection.position,
      ancestor: overlayObject,
    );
    if (!origin.isFinite) return null;
    return origin & Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    return HintTarget(
      tour: tour,
      order: order,
      title: title,
      description: description,
      contentBuilder: appTourGestureStepCard,
      passthrough: true,
      showArrow: false,
      pinnedCardAlignment: Alignment.topCenter,
      spotlight: spotlight,
      spotlightPadding: spotlightPadding,
      rectProvider: _computeRect,
      child: const SizedBox.shrink(),
    );
  }
}
