import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../theme/app_colors.dart';

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
    final controller = Tour.of(context);
    final bool isActive =
        controller.activeTour == tour &&
        TourScope.of(context).orderAt(tour, controller.index) == order;
    if (!isActive) return const SizedBox.shrink();
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
