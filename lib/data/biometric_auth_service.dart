import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Thin wrapper over `local_auth`, so the rest of the app never touches
/// the plugin directly. Biometrics are only ever a faster shortcut on top
/// of a PIN (see `AppLockRepository`), never a standalone unlock method,
/// and are never available on web.
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck && deviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// [title]/[cancelLabel] are the only parts of the system biometric
  /// prompt the OS lets an app touch at all — no colors, no fonts, no
  /// background. Both Android's `BiometricPrompt` and iOS's Face ID/Touch
  /// ID sheet are deliberately locked to system chrome (anti-spoofing: an
  /// app drawing its own look-alike prompt is exactly the attack this
  /// prevents), so this is the actual ceiling for making it feel like
  /// part of the app rather than a bug in this wrapper.
  ///
  /// Returns false instead of throwing on cancellation, lockout, or any
  /// plugin error — callers just fall back to the PIN keypad. Debug builds
  /// print whatever the error actually was: a plugin-level failure (e.g.
  /// the platform side rejecting the call outright, as opposed to the user
  /// just cancelling or failing a scan) otherwise looks identical to the
  /// button simply doing nothing on tap.
  Future<bool> authenticate({
    required String reason,
    required String title,
    required String cancelLabel,
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: [
          AndroidAuthMessages(signInTitle: title, cancelButton: cancelLabel),
          IOSAuthMessages(cancelButton: cancelLabel),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('BiometricAuthService.authenticate failed: $error');
      }
      return false;
    }
  }
}
