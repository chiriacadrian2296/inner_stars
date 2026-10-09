import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// The shared column width every screen caps at on wide viewports — one
/// constant (not per-screen tuning) so the app reads as one coherent web
/// app rather than each page picking its own width.
const double kResponsiveContentMaxWidth = 720;

/// The horizontal space to leave on each side of a full-width scrollable so
/// its content lines up with a [ResponsiveContent] column: 0 on narrow
/// layouts, half the spare width on wide ones. For slivers/grids that can't
/// be wrapped in a [ResponsiveContent] — add it to their padding instead, so
/// the scroll view itself still spans the whole window (wheel works anywhere,
/// scrollbar sits at the page edge).
double responsiveSideInset(
  BuildContext context,
  double viewportWidth, {
  double maxWidth = kResponsiveContentMaxWidth,
}) {
  if (!isWideLayout(context)) return 0;
  return viewportWidth > maxWidth ? (viewportWidth - maxWidth) / 2 : 0;
}

/// No-op on narrow viewports (renders [child] unchanged — zero risk to the
/// phone layout). On wide viewports, centers [child] in a column capped at
/// [maxWidth] so text/forms/lists don't stretch edge-to-edge in a browser
/// or desktop window.
class ResponsiveContent extends StatefulWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = kResponsiveContentMaxWidth,
    this.shrinkHeight = false,
  });

  final Widget child;
  final double maxWidth;

  /// For a child placed in a slot with loose height (a `Positioned` with no
  /// top/bottom pair, say): the wide-layout [Center] would otherwise grow to
  /// fill that height and float [child] to its middle.
  final bool shrinkHeight;

  @override
  State<ResponsiveContent> createState() => _ResponsiveContentState();
}

class _ResponsiveContentState extends State<ResponsiveContent> {
  /// Gives [widget.child]'s subtree an identity that survives crossing
  /// [kWideLayoutBreakpoint] mid-session (a live browser-window resize, not
  /// just a cold start on one side of it).
  ///
  /// Without this, the two branches below return differently-shaped trees —
  /// `child` bare vs. `Center > ConstrainedBox > child` — at the same slot,
  /// so Flutter's reconciler (which matches by widget type at each slot) has
  /// to tear the old one down and build the new one from scratch the moment
  /// [isWideLayout] flips. If [widget.child] contains a `HintTarget` (see
  /// `hint_kit`), that teardown loses the race with the rebuild: Flutter
  /// defers a deactivated element's actual `dispose()` to the end of the
  /// frame, but the new element's `initState`/`didChangeDependencies` runs
  /// immediately — so the new `HintTarget` registers with `TourScope`
  /// *before* the old one has deregistered, and `TourScope` asserts on the
  /// double registration. Confirmed live: dragging a browser window's width
  /// back and forth across 840px on a screen with an active tour step throws
  /// exactly that assertion.
  ///
  /// A `GlobalKey` sidesteps the teardown entirely: Flutter recognizes the
  /// same key reappearing elsewhere in the same frame and *moves* the
  /// existing element into its new parent instead of destroying and
  /// recreating it, so a `HintTarget` underneath never sees a gap. Kept on
  /// the `State` (not a local in `build`) so it stays the same key across
  /// every rebuild of this instance — a fresh key each time would defeat
  /// the point, and a `static`/shared one would collide the moment two
  /// `ResponsiveContent`s are mounted at once (an underlying route kept
  /// alive behind a pushed one, for instance).
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (!isWideLayout(context)) return content;
    return Center(
      heightFactor: widget.shrinkHeight ? 1 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: content,
      ),
    );
  }
}
