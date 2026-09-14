import 'package:flutter/widgets.dart';
import 'package:hint_kit/hint_kit.dart';

import 'tour_step_card.dart';

/// A tour's own opening step — a general "here's what this screen is for"
/// card with no arrow, since there's no specific widget for it to point at.
/// Every tour starts with one of these now (order 1), pushing whatever was
/// order 1 before down to order 2 and so on.
///
/// Reuses the same trick `sky_screen.dart`'s own `sky-navigation` tour
/// pioneered for its first step (an inert, invisible anchor purely so
/// `HintTarget` has *something* to measure) — [IgnorePointer] keeps it out
/// of the gesture arena entirely, so it never affects a real tap underneath
/// it. `scrimOpacity: 0` turns off the dimming entirely instead of cutting
/// a hole around this 1×1 anchor: a real hole here would circle a
/// meaningless point in the middle of the screen rather than anything the
/// step is actually about, so a full, undimmed page reads better than a
/// spotlight on nothing.
///
/// Drop it straight into a [Column]'s `children` (a form, a dialog) — it
/// becomes another (invisible) item in that linear flow, wherever it's
/// placed, rather than floating independently over the whole screen. (The
/// Sky's own tour stopped using this — see [TourGestureStep] instead — so
/// there's currently no screen that needs a true floating/centered variant;
/// add one back here if that changes rather than guessing at its shape
/// unused.)
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
      child: Center(
        child: HintTarget(
          tour: tour,
          order: order,
          showArrow: false,
          theme: const HintThemeData(scrimOpacity: 0),
          contentBuilder: appTourStepCard,
          title: title,
          description: description,
          child: const SizedBox(width: 1, height: 1),
        ),
      ),
    );
  }
}
