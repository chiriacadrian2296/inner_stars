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
/// Camera gestures are unaffected: they repaint the Galaxy on their own, at
/// the display's full rate.
class SkyClock extends ChangeNotifier {
  SkyClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  // Short enough that 90 Hz and 60 Hz screens still tick every frame; long
  // enough that a 120 Hz screen (8.3 ms apart) ticks every second one.
  static const _minInterval = Duration(milliseconds: 10);

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _seconds = 0;

  /// Seconds since the clock started, as of the last tick.
  double get seconds => _seconds;

  void _onTick(Duration elapsed) {
    if (elapsed - _last < _minInterval) return;
    _last = elapsed;
    _seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
