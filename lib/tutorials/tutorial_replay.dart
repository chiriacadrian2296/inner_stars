import 'dart:async';

import 'package:hint_kit/hint_kit.dart';

/// Marks tours the Tutorials screen asked to replay, so the screen that owns
/// each tour starts it with `force: true` — the seen flag was reset, but
/// `PrefsTourStorage.isCompleted` also reports every tour as done while the
/// app-wide tutorials switch is off, which would otherwise swallow a replay.
class TourReplay {
  TourReplay._();

  static final Set<String> _requested = {};

  /// Asks for [tour] to start forced the next time its screen auto-starts it.
  static void request(String tour) => _requested.add(tour);

  /// Drops a request that never got consumed (screen never opened).
  static void clear(String tour) => _requested.remove(tour);

  /// True once per [request]; the screen's own auto-start calls this.
  static bool take(String tour) => _requested.remove(tour);
}

/// What every screen's auto-start calls instead of `tour.start(name)`:
/// the same, but forced when a replay was requested for this tour.
Future<void> startTourAuto(TourController tour, String name) =>
    tour.start(name, force: TourReplay.take(name));

/// Resolves when [name] has started and then ended (finished, skipped or
/// cancelled), or right away if it never starts within [startTimeout].
Future<void> waitForTourEnd(
  TourController tour,
  String name, {
  Duration startTimeout = const Duration(seconds: 8),
}) {
  final done = Completer<void>();
  var started = tour.activeTour == name;
  late final Timer timer;
  void listener() {
    if (tour.activeTour == name) {
      started = true;
    } else if (started && !done.isCompleted) {
      done.complete();
    }
  }

  timer = Timer(startTimeout, () {
    if (!started && !done.isCompleted) done.complete();
  });
  tour.addListener(listener);
  return done.future.whenComplete(() {
    timer.cancel();
    tour.removeListener(listener);
  });
}
