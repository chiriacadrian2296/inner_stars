import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps a [NightlightStarfield]'s own exclusion zones tracking the
/// *actual*, current on-screen position of whichever content needs to stay
/// clear of the animated stars — rather than a fixed guess at fractional
/// coordinates, which drifts out of sync the moment the page's own
/// responsive layout reflows (a resized browser window, a different
/// device, an orientation change, ...).
///
/// A screen mixing this in: gives [stackKey] to the `Stack` that has both
/// the `NightlightStarfield` and the real content as siblings (measurements
/// land in that `Stack`'s own coordinate space — exactly what the
/// starfield's painter draws in, since it fills that same `Stack` via
/// `Positioned.fill`); attaches a stable [GlobalKey] to each widget that
/// needs to stay clear (most widgets already take one via their own `key`
/// parameter); and calls [scheduleZoneMeasurement] with all of those keys
/// once per `build`, then reads [nightlightZones] back into
/// `NightlightStarfield.exclusionZones`.
mixin NightlightZoneMeasuring<T extends StatefulWidget> on State<T> {
  final GlobalKey stackKey = GlobalKey();

  List<Rect> _zones = const [];
  List<Rect> get nightlightZones => _zones;

  /// Re-measures once the current frame has landed (so every key has an
  /// attached, laid-out [RenderBox] to read), and updates [nightlightZones]
  /// — via `setState` — only if something actually moved. A screen calls
  /// this once per `build`, which itself only re-runs when something (its
  /// own state, or a `MediaQuery` dependency it reads) actually changes, so
  /// this doesn't loop on its own.
  void scheduleZoneMeasurement(List<GlobalKey> keys, {double padding = 8}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ancestor = stackKey.currentContext?.findRenderObject();
      if (ancestor is! RenderBox || !ancestor.attached) return;
      final zones = <Rect>[];
      for (final key in keys) {
        final zone = _measure(key, ancestor, padding);
        if (zone != null) zones.add(zone);
      }
      if (!listEquals(zones, _zones)) {
        setState(() => _zones = zones);
      }
    });
  }

  Rect? _measure(GlobalKey key, RenderBox ancestor, double padding) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: ancestor);
    return (topLeft & renderObject.size).inflate(padding);
  }
}
