import 'package:flutter/widgets.dart';
import 'package:hint_kit/hint_kit.dart';

/// A gold glow drawn behind [child] exactly while the `hint_kit` step
/// identified by [tour]/[order] is the active one — reactive via [Tour.of],
/// an [InheritedNotifier] that rebuilds this on every tour change, with
/// [TourScope.of]'s (non-reactive, but re-read on every rebuild anyway)
/// `orderAt` translating the controller's raw step index back to the
/// `order` a [HintTarget] was actually registered with.
///
/// Exists because `hint_kit`'s own spotlight/pulse alone don't reliably
/// read as "highlighted" on this app's muted/dark palette — confirmed live
/// (see the project's own memory on this) that even a field's own visible
/// border isn't enough contrast once everything around it is dimmed too.
/// A glow that exists specifically because this step is active sidesteps
/// the problem entirely: it never depends on the target's own brightness
/// or the scrim at all.
///
/// The matching [HintTarget] must widen its own `spotlightPadding` enough
/// to contain the glow's full painted extent (`blurRadius` + `spreadRadius`
/// below) — otherwise the scrim, cut to a hole no bigger than the target's
/// own bounds, paints right back over most of the glow. Confirmed live:
/// this was the actual bug the first time this widget shipped without the
/// matching padding change.
class TourGlow extends StatelessWidget {
  const TourGlow({
    super.key,
    required this.tour,
    required this.order,
    required this.color,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  final String tour;
  final int order;
  final Color color;
  final Widget child;

  /// [BoxShape.circle] for round targets (icon buttons); the default
  /// rectangle (with [borderRadius]) for everything else — fields, tiles,
  /// pill/rounded buttons.
  final BoxShape shape;

  /// Ignored when [shape] is [BoxShape.circle]. Defaults to
  /// `BorderRadius.circular(kRadiusField)` when null.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final controller = Tour.of(context);
    final isActive =
        controller.activeTour == tour &&
        TourScope.of(context).orderAt(tour, controller.index) == order;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(12)),
        boxShadow: isActive
            ? [BoxShadow(color: color, blurRadius: 28, spreadRadius: 10)]
            : null,
      ),
      child: child,
    );
  }
}

/// The extra room a [HintTarget] wrapping a [TourGlow] needs in its own
/// `spotlightPadding`, so the scrim's hole contains the whole glow instead
/// of cutting it off at the target's own bounds.
const EdgeInsets kTourGlowSpotlightPadding = EdgeInsets.all(40);
