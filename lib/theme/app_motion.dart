import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// The app's shared motion vocabulary — one set of durations and curves for
/// the transitions, dialogs, sheets and press feedback added on top of the
/// screens, so they all feel like the same hand made them.
///
/// Older inline timings elsewhere in the app were left as they were; only
/// new motion code draws from here.
const kMotionFast = Duration(milliseconds: 120);
const kMotionBase = Duration(milliseconds: 220);
const kMotionSlow = Duration(milliseconds: 320);

const kMotionEnter = Curves.easeOutCubic;
const kMotionExit = Curves.easeInCubic;

/// [base], or [Duration.zero] when the system asks for reduced motion.
Duration motionDuration(BuildContext context, Duration base) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;
}

/// The shared-axis push/pop every route in the app uses (see
/// `pageTransitionsTheme` in `buildAppTheme`). Skips the animation entirely
/// under reduced motion, since a route's transition doesn't shorten itself.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => kMotionSlow;

  @override
  Duration get reverseTransitionDuration => kMotionSlow;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // The night backdrop fills the gap behind the sliding pages; the
    // default canvas color would flash a grey between them.
    return SharedAxisPageTransitionsBuilder(
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
    ).buildTransitions<T>(route, context, animation, secondaryAnimation, child);
  }
}
