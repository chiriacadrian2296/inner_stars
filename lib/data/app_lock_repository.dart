import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';
import 'repository_write.dart';

/// Reads and writes the optional app-lock settings: whether the lock is on,
/// whether a fingerprint/biometric shortcut is allowed alongside it, and
/// the PIN itself — stored only as a salted SHA-256 hash, never in the
/// clear. See `AppLockGate`, which reads this at startup/resume, and
/// `AppLockScreen`/`PinSetupScreen`, which write to it.
///
/// The PIN (hash and salt) is one synced record, so it is the same on every
/// device of the account; turning the lock off is a deletion record that
/// carries no hash. The biometric shortcut stays per device. The lock is a
/// privacy screen, not a security boundary: four digits are always quick to
/// guess for anyone who can read the hash.
class AppLockRepository extends ChangeNotifier with SyncableRepository {
  AppLockRepository._(this._prefs);

  static const recordKey = 'app_lock.record-v1';
  static const _biometricEnabledKey = 'app_lock.biometric_enabled';
  // Where the PIN lived before it was synced.
  static const _legacyEnabledKey = 'app_lock.enabled';
  static const _legacyPinHashKey = 'app_lock.pin_hash';
  static const _legacyPinSaltKey = 'app_lock.pin_salt';

  final SharedPreferences _prefs;

  @override
  String get syncName => 'app-lock';

  @override
  late final LocalCollection syncCollection = LocalCollection.single(
    _prefs,
    recordKey,
  );

  static Future<AppLockRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final repository = AppLockRepository._(prefs);
    await repository._migrateLegacy();
    return repository;
  }

  /// Moves a PIN saved before syncing existed into the synced record, stamped
  /// now so it reaches the other devices.
  Future<void> _migrateLegacy() async {
    final hash = _prefs.getString(_legacyPinHashKey);
    final salt = _prefs.getString(_legacyPinSaltKey);
    if (!_prefs.containsKey(recordKey) && hash != null && salt != null) {
      await _write({'hash': hash, 'salt': salt, 'deleted': false});
    }
    for (final key in [
      _legacyEnabledKey,
      _legacyPinHashKey,
      _legacyPinSaltKey,
    ]) {
      if (_prefs.containsKey(key)) await _prefs.remove(key);
    }
  }

  Map<String, dynamic>? _stored() {
    final raw = _prefs.getString(recordKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  /// The PIN record, unless the lock is off (never set, or a deletion record).
  Map<String, dynamic>? _active() {
    final record = _stored();
    if (record == null ||
        record['deleted'] == true ||
        record['hash'] is! String ||
        record['salt'] is! String) {
      return null;
    }
    return record;
  }

  Future<void> _write(Map<String, dynamic> content) async {
    final previous = _stored();
    final records = reconcileLocalRecords(
      {'current': ?previous},
      {'current': content},
    );
    await writeRepositoryValue(
      _prefs,
      recordKey,
      jsonEncode(records['current']),
    );
    notifyListeners();
  }

  /// Off by default — the lock is opt-in.
  bool get isEnabled => _active() != null;

  bool get biometricEnabled => _prefs.getBool(_biometricEnabledKey) ?? false;

  bool get hasPin => isEnabled;

  /// Hashes and persists a new 4-digit PIN with a fresh random salt, and
  /// turns the lock on. Call this both for the initial setup and for
  /// changing an existing PIN.
  Future<void> setPin(String pin) {
    final salt = _generateSalt();
    return _write({
      'hash': _hashPin(pin, salt),
      'salt': salt,
      'deleted': false,
    });
  }

  /// Recomputes the hash with the stored salt and compares. Returns false
  /// (never throws) when no PIN has been set yet.
  bool verifyPin(String pin) {
    final record = _active();
    if (record == null) return false;
    return _hashPin(pin, record['salt'] as String) == record['hash'];
  }

  /// No-op when there's no PIN yet — biometrics are only ever a shortcut
  /// on top of a PIN, never a standalone unlock method.
  Future<void> setBiometricEnabled(bool value) async {
    if (!hasPin) return;
    await _prefs.setBool(_biometricEnabledKey, value);
  }

  /// Turns the lock off and forgets the PIN entirely — there's no undo,
  /// the same "Remove lock" action re-creates it from scratch next time.
  /// The other devices of the account turn it off too.
  Future<void> disable() async {
    await _prefs.setBool(_biometricEnabledKey, false);
    await _write({'deleted': true});
  }

  /// Forgets the lock without telling the cloud: used when another account
  /// signs in on this device, so one account's PIN never locks another's data.
  Future<void> forgetLocally() async {
    await writeRepositoryValue(_prefs, recordKey, null);
    await _prefs.setBool(_biometricEnabledKey, false);
    notifyListeners();
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
