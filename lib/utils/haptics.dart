import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A one-shot motor buzz, routed through a small native Android channel
/// (`MainActivity.kt`) rather than the `vibration` package directly — see
/// that file's own doc comment for why: the package always tags its
/// `Vibrator.vibrate` calls as `AudioAttributes.USAGE_ALARM`, which at least
/// one real test device (a Xiaomi phone) substitutes with a fixed-strength
/// vendor haptic regardless of the requested amplitude. Tagging the same
/// call as `USAGE_TOUCH` instead is what actually lets [amplitude] (1-255)
/// change anything.
///
/// A no-op everywhere but Android — nothing on the other end of the channel
/// on iOS/web/desktop, and none of those are this app's real target for a
/// motor buzz anyway.
class Haptics {
  static const _channel = MethodChannel('inner_stars/haptics');

  static Future<void> vibrate({
    required Duration duration,
    required int amplitude,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('vibrate', {
      'duration': duration.inMilliseconds,
      'amplitude': amplitude,
    });
  }

  static Future<void> cancel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('cancel');
  }
}
