package com.example.inner_stars

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// A tiny native haptics channel, bypassing the `vibration` package for the
/// sky's own hold/tap buzz. That package always tags its `Vibrator.vibrate`
/// calls with the legacy `AudioAttributes.USAGE_ALARM` (see its Java
/// source), which the platform maps onto `VibrationAttributes.USAGE_ALARM`
/// — on this project's own Xiaomi test device (and reportedly others),
/// Android routes that category through a vendor haptics service that
/// supplies its own fixed-strength params, silently discarding whatever
/// amplitude the app actually asked for (`dumpsys vibrator_manager` shows
/// exactly this: `requestVibrationParamsForUsages = [ALARM, ...]`). Tagging
/// the vibration as `VibrationAttributes.USAGE_TOUCH` instead — the
/// category real touch feedback uses, and not one of the ones routed
/// through that vendor override — was the only way found to make the
/// intensity dial in `sky_screen.dart` (`_hapticAmplitude`) actually do
/// anything. `VibrationAttributes` only exists from API 33 (Android 13)
/// on; below that this just fires a plain, attribute-less
/// `VibrationEffect`, which was never observed going through the ALARM
/// override in the first place (that's a behavior of the newer
/// per-usage-intensity vibration system `VibrationAttributes` belongs to).
class MainActivity : FlutterActivity() {
    private val hapticsChannelName = "inner_stars/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannelName)
            .setMethodCallHandler { call, result ->
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator == null || !vibrator.hasVibrator()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "vibrate" -> {
                        val durationMs = (call.argument<Int>("duration") ?: 0).toLong()
                        val amplitude = call.argument<Int>("amplitude") ?: VibrationEffect.DEFAULT_AMPLITUDE
                        if (durationMs > 0) {
                            val effect = VibrationEffect.createOneShot(durationMs, amplitude)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                val attributes = VibrationAttributes.Builder()
                                    .setUsage(VibrationAttributes.USAGE_TOUCH)
                                    .build()
                                vibrator.vibrate(effect, attributes)
                            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(effect)
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(durationMs)
                            }
                        }
                        result.success(null)
                    }
                    "cancel" -> {
                        vibrator.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
