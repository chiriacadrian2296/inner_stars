import 'package:shared_preferences/shared_preferences.dart';

/// The current wish entrusted to the shooting star in the Galaxy.
///
/// This intentionally stores one wish, not a history: the moving star is one
/// recurring sky element for now. A dated/history model can be introduced
/// later without making the first interaction pretend those rules exist.
class ShootingStarWishRepository {
  ShootingStarWishRepository(this._prefs);

  static const _storageKey = 'shooting-star-wish-v1';
  final SharedPreferences _prefs;

  static Future<ShootingStarWishRepository> create() async =>
      ShootingStarWishRepository(await SharedPreferences.getInstance());

  String? get wish {
    final value = _prefs.getString(_storageKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> save(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_storageKey);
    } else {
      await _prefs.setString(_storageKey, trimmed);
    }
  }

  Future<void> clear() => _prefs.remove(_storageKey);
}
