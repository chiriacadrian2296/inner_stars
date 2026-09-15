import 'package:flutter/widgets.dart';
import 'package:hint_kit/hint_kit.dart';

import 'tour_step_card.dart';

/// A tour's own opening step — a general "here's what this screen is for"
/// card with no arrow, since there's no specific widget for it to point at.
/// Every tour starts with one of these now (order 1), pushing whatever was
/// order 1 before down to order 2 and so on.
///
/// [IgnorePointer] keeps the (otherwise pointless) anchor out of the
/// gesture arena entirely, so it never affects a real tap underneath it.
/// Unlike a normal step, this one keeps the scrim at its usual full
/// dimming (no `scrimOpacity` override) and cuts no hole at all — the
/// anchor is a genuinely empty [SizedBox.shrink] with zero
/// [HintTarget.spotlightPadding], which [Spotlight] reads as "nothing to
/// cut" (an empty hole rect), and [HintTarget.pulse] is off too, so there
/// is no small highlighted/pulsing zone left to distract from a card about
/// the whole screen rather than any one point on it. The card itself is
/// pinned to the screen's exact center ([HintTarget.pinnedCardAlignment])
/// rather than anchored beside the (meaningless) 1x1 point, for the same
/// reason.
///
/// Drop it straight into a [Column]'s `children` (a form, a dialog) — it
/// becomes another (invisible) item in that linear flow, wherever it's
/// placed, rather than floating independently over the whole screen.
class TourIntroTarget extends StatelessWidget {
  const TourIntroTarget({
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
    return IgnorePointer(
      child: HintTarget(
        tour: tour,
        order: order,
        showArrow: false,
        pulse: false,
        spotlightPadding: EdgeInsets.zero,
        pinnedCardAlignment: Alignment.center,
        contentBuilder: appTourStepCard,
        title: title,
        description: description,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
