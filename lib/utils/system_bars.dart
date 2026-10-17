import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tells screens when another route covers them or they come back on top,
/// so they can hand the system bars over (see [SystemBars]).
final systemBarsRouteObserver = RouteObserver<ModalRoute<void>>();

/// Whether the phone's system bars (status and navigation) are shown.
///
/// The app is edge to edge by default. A screen that wants the bars hidden -
/// Galaxy always, "Vedi" on a phone on its side - says so with [set], and
/// [release]s its wish when it goes. The latest wish wins, so a screen that
/// closes never shows the bars over one that had hidden them underneath:
/// returning to Galaxy keeps them hidden even if the closing screen's own
/// cleanup runs after Galaxy has asked again.
abstract final class SystemBars {
  static final Map<Object, bool> _wishes = {};
  static bool _hidden = false;

  /// Records [owner]'s wish as the latest one, and applies it.
  static void set(Object owner, {required bool hidden}) {
    _wishes
      ..remove(owner)
      ..[owner] = hidden;
    _apply();
  }

  /// Forgets [owner]'s wish; the latest remaining one applies.
  static void release(Object owner) {
    if (_wishes.remove(owner) != null) _apply();
  }

  static void _apply() {
    final hidden = _wishes.isNotEmpty && _wishes.values.last;
    if (hidden == _hidden) return;
    _hidden = hidden;
    // Only phones have bars to hide; elsewhere this is a no-op anyway.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    // Sticky: a swipe from the edge brings the bars back for a moment.
    SystemChrome.setEnabledSystemUIMode(
      hidden ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @visibleForTesting
  static void reset() {
    _wishes.clear();
    _hidden = false;
  }
}
