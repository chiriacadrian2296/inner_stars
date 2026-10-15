import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// TEMPORARY test (2026-10-15, Galaxy smoothness): caps the whole app's
/// frame rate so a steady 40 or 30 fps can be compared by eye with the free
/// rate, camera gestures included. 0 is free. Not persisted.
///
/// A frame due too soon after the last one drawn is skipped outright — no
/// build, no paint, nothing sent to the GPU — and the next vsync asked for
/// instead, so on a 120 Hz screen 40 fps is every third vsync and 30 every
/// fourth, always evenly spaced.
final frameRateLimit = ValueNotifier<int>(0);

Duration? _lastDrawn;
bool _skipping = false;

/// Wraps the engine's frame callbacks; call once after the binding exists.
/// Done after the first frame: only by then has the binding registered its
/// own callbacks to wrap.
void installFrameRateLimiter() {
  SchedulerBinding.instance.addPostFrameCallback((_) => _install());
}

void _install() {
  final dispatcher = PlatformDispatcher.instance;
  final beginFrame = dispatcher.onBeginFrame;
  final drawFrame = dispatcher.onDrawFrame;
  if (beginFrame == null || drawFrame == null) {
    // Not yet (e.g. after the warm-up frame): try after the next one.
    installFrameRateLimiter();
    return;
  }
  dispatcher.onBeginFrame = (timeStamp) {
    final limit = frameRateLimit.value;
    final last = _lastDrawn;
    if (limit > 0 && last != null && timeStamp > last) {
      // Half a 120 Hz vsync of slack, so a frame due right on time is
      // never skipped for being a hair early.
      final interval = Duration(microseconds: 1000000 ~/ limit - 4000);
      if (timeStamp - last < interval) {
        _skipping = true;
        dispatcher.scheduleFrame();
        return;
      }
    }
    _lastDrawn = timeStamp;
    beginFrame(timeStamp);
  };
  dispatcher.onDrawFrame = () {
    if (_skipping) {
      _skipping = false;
      return;
    }
    drawFrame();
  };
}
