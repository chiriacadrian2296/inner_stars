import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the optional app-lock settings: whether the lock is on,
/// whether a fingerprint/biometric shortcut is allowed alongside it, and
/// the PIN itself — stored only as a salted SHA-256 hash, never in the
/// clear. See `AppLockGate`, which reads this at startup/resume, and
/// `AppLockScreen`/`PinSetupScreen`, which write to it.
class AppLockRepository {
  AppLockRepository._(this._prefs);

  static const _enabledKey = 'app_lock.enabled';
  static const _biometricEnabledKey = 'app_lock.biometric_enabled';
  static const _pinHashKey = 'app_lock.pin_hash';
  static const _pinSaltKey = 'app_lock.pin_salt';

  final SharedPreferences _prefs;

  static Future<AppLockRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLockRepository._(prefs);
  }

  /// Off by default — the lock is opt-in.
  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;

  bool get biometricEnabled => _prefs.getBool(_biometricEnabledKey) ?? false;

  bool get hasPin => _prefs.getString(_pinHashKey) != null;

  /// Hashes and persists a new 4-digit PIN with a fresh random salt, and
  /// turns the lock on. Call this both for the initial setup and for
  /// changing an existing PIN.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _prefs.setString(_pinSaltKey, salt);
    await _prefs.setString(_pinHashKey, hash);
    await _prefs.setBool(_enabledKey, true);
  }

  /// Recomputes the hash with the stored salt and compares. Returns false
  /// (never throws) when no PIN has been set yet.
  bool verifyPin(String pin) {
    final salt = _prefs.getString(_pinSaltKey);
    final storedHash = _prefs.getString(_pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  /// No-op when there's no PIN yet — biometrics are only ever a shortcut
  /// on top of a PIN, never a standalone unlock method.
  Future<void> setBiometricEnabled(bool value) async {
    if (!hasPin) return;
    await _prefs.setBool(_biometricEnabledKey, value);
  }

  /// Turns the lock off and forgets the PIN entirely — there's no undo,
  /// the same "Remove lock" action re-creates it from scratch next time.
  Future<void> disable() async {
    await _prefs.remove(_pinHashKey);
    await _prefs.remove(_pinSaltKey);
    await _prefs.setBool(_biometricEnabledKey, false);
    await _prefs.setBool(_enabledKey, false);
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
