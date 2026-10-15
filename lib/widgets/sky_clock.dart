import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The one animation clock behind the Galaxy's ambient motion (nebula,
/// supernova flare, sigils, star flicker, the menu button's glow).
///
/// It exists for two reasons. Those layers used to own one [Ticker] each and
/// call `setState` on every vsync, so on a 120 Hz display the whole Galaxy was
/// rebuilt and repainted 120 times a second even when nothing moved. Here a
/// single ticker feeds them all, capped so a 120 Hz screen repaints the
/// ambient motion at ~60 fps (a twinkle or a slow rotation can't tell the
/// difference). And because they all hear the same notification, they repaint
/// in the same frame instead of drifting out of phase and dirtying alternate
/// frames.
///
/// The cap has to keep the ticker itself quiet in between, not just skip
/// notifying: a running ticker asks for a frame on every vsync, and every
/// frame drawn redraws the whole sky on the GPU even when nothing changed.
/// So after each tick the ticker stops and a timer starts it again once the
/// interval is up.
///
/// Camera gestures are unaffected: they repaint the Galaxy on their own, at
/// the display's full rate.
class SkyClock extends ChangeNotifier {
  SkyClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick)..start();
    _time.start();
  }

  late final Ticker _ticker;
  final _time = Stopwatch();
  Timer? _wake;

  // Short enough that 90 Hz and 60 Hz screens still tick every frame; long
  // enough that a 120 Hz screen (8.3 ms apart) ticks every second one.
  Duration _minInterval = const Duration(milliseconds: 10);

  /// Caps the ambient motion at about [fps] repaints a second: 60 (the
  /// default) or 30 to spare the phone — every second frame of a 60 Hz
  /// screen, every third at 90 Hz, every fourth at 120 Hz. The slack keeps
  /// a slightly early frame from being skipped.
  set maxFps(int fps) => _minInterval = fps >= 60
      ? const Duration(milliseconds: 10)
      : Duration(microseconds: (1e6 / fps * 0.85).round());

  double _seconds = 0;

  /// Seconds since the clock started, as of the last tick.
  double get seconds => _seconds;

  void _onTick(Duration elapsed) {
    _seconds = _time.elapsedMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
    // Quiet until the next tick is due. Stopped rather than muted, so the
    // ticker's own muting (a page pushed over the Galaxy) keeps working.
    _ticker.stop();
    _wake = Timer(_minInterval, () {
      if (!_ticker.isActive) _ticker.start();
    });
  }

  @override
  void dispose() {
    _wake?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}
