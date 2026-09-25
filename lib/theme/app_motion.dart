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

/// The push/pop every route in the app uses (see `pageTransitionsTheme` in
/// `buildAppTheme`): the new page fades in while sliding a short way in from
/// the side, over the previous page, which stays put; going back it just fades
/// out in place. Skips the animation
/// entirely under reduced motion, since a route's transition doesn't shorten
/// itself.
///
/// Deliberately not a shared-axis / fade-through: that fades the outgoing page
/// to nothing before the new one appears, and whatever sits behind (the
/// scaffold color) shows as a dark flash between the two.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => kMotionSlow;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // No reverseCurve: leaving replays the fade exactly backwards, rather
    // than easing out on a different curve.
    final curved = CurvedAnimation(parent: animation, curve: kMotionEnter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        // Only the entrance slides; leaving fades out in place.
        builder: (context, child) => FractionalTranslation(
          translation: animation.status == AnimationStatus.reverse
              ? Offset.zero
              : Offset(0.06 * (1 - curved.value), 0),
          child: child,
        ),
      ),
    );
  }
}
