import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../theme/app_colors.dart';
import 'tour_step_card.dart';

/// A tour step that advances only when the user performs the real gesture
/// it describes — tapping an actual supernova, holding an actual
/// constellation — rather than by tapping Next on a card. Meant for a
/// screen like the Sky, where the things a step wants tapped are pixels on
/// a hand-drawn canvas, not discrete widgets `HintTarget` could measure and
/// circle the way it does everywhere else in the app.
///
/// Two things, layered:
///
/// 1. An invisible, full-screen `HintTarget` with `passthrough: true`, a
///    fully transparent scrim (`scrimOpacity: 0`) and `showCard: false` —
///    not there to show anything itself, just to (a) register this `order`
///    with `hint_kit`'s own step bookkeeping, the same registration every
///    other tour step gets from its own `HintTarget`, and (b) make sure the
///    scrim never blocks the real tap it's waiting for. Passthrough alone
///    isn't enough for that: a passthrough scrim only lets taps through
///    *inside its hole*, so the hole has to cover the entire screen — this
///    is the "make the whole page the highlight" case, since there's no
///    specific widget-sized thing to make a small one out of. `showCard:
///    false` (a local `hint_kit` addition — see its own doc comment)
///    matters for the same reason: without it, `HintTarget` still wraps its
///    own card chrome around nothing, which against a whole-screen target
///    read as a small, empty, stray bubble sitting wherever the placement
///    algorithm landed it.
/// 2. [TourGestureBanner], a plain reactive widget (no relation to
///    `HintTarget`'s own card/arrow/placement machinery) that shows this
///    step's own title/description while it's active — no controls at
///    all, not even Skip: the sky-navigation tour deliberately gives every
///    step no way through but the real gesture it describes. See
///    `sky_screen.dart`'s own gesture handlers (`_flyToArea`, `_openStar`,
///    etc.) for where each step actually gets advanced, via
///    `Tour.read(context).next()`.
///
/// Place both inside the same [Stack] as the real content, same as
/// [TourIntroTarget].
class TourGestureStep extends StatelessWidget {
  const TourGestureStep({super.key, required this.tour, required this.order});

  final String tour;
  final int order;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: HintTarget(
        tour: tour,
        order: order,
        passthrough: true,
        showArrow: false,
        showCard: false,
        theme: const HintThemeData(scrimOpacity: 0),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Whether [tour]'s currently active step is exactly [order] — the same
/// check [TourGestureBanner] and [TourGestureConfirmStep] each need before
/// showing anything, since both are (like [TourGestureStep] itself)
/// mounted for the whole time their surrounding route/modal is, not just
/// while their own step is active.
bool _isActiveTourStep(BuildContext context, String tour, int order) {
  final controller = Tour.of(context);
  return controller.activeTour == tour &&
      TourScope.of(context).orderAt(tour, controller.index) == order;
}

/// The banner half of [TourGestureStep] — see its own doc comment. Shows
/// [title]/[description] centered near the top of the screen (out of the
/// way of whatever's being tapped lower down) exactly while [tour]'s
/// active step is [order]. No controls — see [TourGestureStep]'s own doc
/// comment for why.
class TourGestureBanner extends StatelessWidget {
  const TourGestureBanner({
    super.key,
    required this.tour,
    required this.order,
    required this.title,
    required this.description,
  });

  final String tour;
  final int order;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    if (!_isActiveTourStep(context, tour, order)) return const SizedBox.shrink();
    final colors = context.colors;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          ignoring: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              // Capped the same width as every other tour step's card
              // (`HintThemeData.maxWidth`'s own default, 280) — without
              // this, nothing here stops the card from stretching as wide
              // as its longest line of text, which on a roomy screen (a
              // desktop browser window, a tablet) is most of it.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.nightPanel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.text, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [TourGestureStep] plus a real spotlight hole — for a step whose target
/// isn't any one widget or world position, just "empty sky, anywhere" (the
/// sky-navigation tour's own order-5 double-tap-to-zoom-out step): rather
/// than the fully invisible, unscrimmed passthrough every other gesture
/// step uses, this cuts a normal hole over a fixed, deliberately-empty
/// screen spot — [spotAlignment], well clear of every corner control
/// (drawer/Sound Lab/tutorials buttons), the FAB, and dead center (where
/// the star the previous step flew to sits) — so the step reads the same
/// "tap-here-in-the-lit-circle" way every other one does, even though any
/// other empty patch of sky works exactly as well for the real gesture.
///
/// Pinned to a fixed screen [Alignment] rather than projected from a world
/// position via `worldToScreen` the way [SkyHintTarget] is: nothing about
/// "an empty spot" needs to track the camera, and a fixed spot is
/// guaranteed to stay clear of the real content on screen regardless of
/// where the camera happens to be looking.
///
/// Still `passthrough: true` and `showCard: false` — [TourGestureBanner]
/// alongside this carries the actual instructions, and the real double
/// tap only has to reach the sky underneath the hole, not open a card of
/// its own.
class TourGestureEmptySpotHint extends StatelessWidget {
  const TourGestureEmptySpotHint({
    super.key,
    required this.tour,
    required this.order,
    this.spotAlignment = const Alignment(-0.6, 0),
    this.spotSize = 64,
    this.spotlightPadding = const EdgeInsets.all(16),
  });

  final String tour;
  final int order;

  /// Where on screen the hole sits — left-of-center at mid-height by
  /// default, clear of every corner control and of dead center alike.
  final Alignment spotAlignment;

  /// Size of the (invisible) spot the hole is cut around, before
  /// [spotlightPadding] grows it further.
  final double spotSize;
  final EdgeInsets spotlightPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: spotAlignment,
      child: HintTarget(
        tour: tour,
        order: order,
        passthrough: true,
        showArrow: false,
        showCard: false,
        spotlight: SpotlightShape.circle,
        spotlightPadding: spotlightPadding,
        child: SizedBox(width: spotSize, height: spotSize),
      ),
    );
  }
}

/// Same registration as [TourGestureStep], but gates the real gesture it
/// teaches behind an explicit "Try" tap first: a full scrim plus a
/// centered card with one button block everything else until pressed —
/// only then does the step's own passthrough become reachable. Used
/// where [TourGestureBanner]'s plain top-of-screen banner made the actual
/// task too easy to miss (the sky-navigation tour's own order-9 "close
/// this menu" step: its three dismiss gestures — swipe, tap outside, the
/// back button — are all real actions on the menu itself, not an
/// obviously-a-button prompt the way a banner suggested).
///
/// [_tryPressed] is local `State`, not tour state — a later "Replay" of
/// this tour reopens the menu modal fresh, which rebuilds this whole
/// widget (and therefore resets the gate) the same way any other modal
/// content would.
class TourGestureConfirmStep extends StatefulWidget {
  const TourGestureConfirmStep({
    super.key,
    required this.tour,
    required this.order,
    required this.title,
    required this.description,
    required this.tryLabel,
  });

  final String tour;
  final int order;
  final String title;
  final String description;
  final String tryLabel;

  @override
  State<TourGestureConfirmStep> createState() =>
      _TourGestureConfirmStepState();
}

class _TourGestureConfirmStepState extends State<TourGestureConfirmStep> {
  bool _tryPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isActiveTourStep(context, widget.tour, widget.order);
    final colors = context.colors;
    final theme = HintThemeData.resolve(context, TourScope.of(context).theme);
    // `Positioned.fill` at the top, same as [TourGestureStep]/
    // [TourGestureBanner] each are relative to whatever outer `Stack` this
    // sits in (the menu modal's own route content) — without it, this
    // inner `Stack`'s own size would depend on how its non-positioned
    // children happen to lay out instead of always matching that outer
    // bound exactly.
    return Positioned.fill(
      child: Stack(
        children: [
          // Registers this order and lets the real dismiss gesture through
          // once the gate below is out of the way — see [TourGestureStep]'s
          // own doc comment. Always mounted alongside this widget, exactly
          // the way it's used everywhere else, so the tour's own step
          // bookkeeping never depends on [_tryPressed].
          TourGestureStep(tour: widget.tour, order: widget.order),
          if (isActive)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _tryPressed,
                child: AnimatedOpacity(
                  opacity: _tryPressed ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  // Opaque and full-screen so nothing behind it — the
                  // menu's own items, its drag-to-dismiss, the
                  // tap-outside barrier — is reachable until
                  // [_tryPressed] flips true: an empty `onTap` is enough
                  // to claim every tap here rather than letting it fall
                  // through to whatever's underneath (see
                  // `HitTestBehavior.opaque`'s own doc comment).
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ColoredBox(
                      color: theme.scrimColor,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.nightPanel,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.text,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      color: colors.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.description,
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.center,
                                    child: AppTourButton(
                                      label: widget.tryLabel,
                                      onPressed: () =>
                                          setState(() => _tryPressed = true),
                                      emphasised: true,
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}
