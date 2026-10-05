import '../models/artwork_blend.dart';
import '../models/artwork_layer.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes user-facing app settings (language, daily reminder).
/// Each setting is its own [SharedPreferences] key rather than one JSON
/// blob — unlike [StarRepository]/[ProjectRepository]'s lists, these are
/// independent scalars with no shared ordering to preserve.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _localeKey = 'settings.locale';
  static const _reminderEnabledKey = 'settings.reminderEnabled';
  static const _reminderHourKey = 'settings.reminderHour';
  static const _reminderMinuteKey = 'settings.reminderMinute';
  static const _showGridKey = 'settings.showGrid';
  static const _artworkOpacityKey = 'settings.artworkOpacity';
  static const _artworkBlendKey = 'settings.artworkBlend';
  static const _artworkScaleKey = 'settings.artworkScale';
  static const _artworkColorKey = 'settings.artworkColor';
  static const _artworkGoldMigratedKey = 'settings.artworkGoldMigrated';
  static const _artworkLayerKey = 'settings.artworkLayer';
  static const _showSupernovaeKey = 'settings.showSupernovae';
  static const _supernovaScaleKey = 'settings.supernovaScale';
  static const _supernovaIntensityKey = 'settings.supernovaIntensity';
  static const _tutorialsEnabledKey = 'settings.tutorialsEnabled';

  final SharedPreferences _prefs;

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  /// 'en', 'it', or 'ro'. Defaults to 'en'.
  String get locale => _prefs.getString(_localeKey) ?? 'en';

  Future<void> setLocale(String code) => _prefs.setString(_localeKey, code);

  bool get reminderEnabled => _prefs.getBool(_reminderEnabledKey) ?? false;

  /// Hour/minute default to 20:00 the first time the reminder is turned on.
  int get reminderHour => _prefs.getInt(_reminderHourKey) ?? 20;

  int get reminderMinute => _prefs.getInt(_reminderMinuteKey) ?? 0;

  Future<void> setReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _prefs.setBool(_reminderEnabledKey, enabled);
    await _prefs.setInt(_reminderHourKey, hour);
    await _prefs.setInt(_reminderMinuteKey, minute);
  }

  /// Whether the Sky's own coordinate grid is drawn over the nebula
  /// background — off by default, same as it always started before this
  /// became a real setting.
  bool get showGrid => _prefs.getBool(_showGridKey) ?? false;

  Future<void> setShowGrid(bool value) => _prefs.setBool(_showGridKey, value);

  /// Whether the Cosmo draws each life area's supernova (the giant star over
  /// its artwork, and the sigil around it) — on by default.
  bool get showSupernovae => _prefs.getBool(_showSupernovaeKey) ?? true;

  Future<void> setShowSupernovae(bool value) =>
      _prefs.setBool(_showSupernovaeKey, value);

  double get supernovaScale => _prefs.getDouble(_supernovaScaleKey) ?? 1.0;

  Future<void> setSupernovaScale(double value) =>
      _prefs.setDouble(_supernovaScaleKey, value);

  double get supernovaIntensity =>
      _prefs.getDouble(_supernovaIntensityKey) ?? 1.0;

  Future<void> setSupernovaIntensity(double value) =>
      _prefs.setDouble(_supernovaIntensityKey, value);

  /// How strongly the Cosmo's area artwork shows (0..1), and how it blends
  /// onto the sky — defaults are the original look (half strength, additive).
  double get artworkOpacity => _prefs.getDouble(_artworkOpacityKey) ?? 0.5;

  Future<void> setArtworkOpacity(double value) =>
      _prefs.setDouble(_artworkOpacityKey, value);

  ArtworkBlend get artworkBlend =>
      ArtworkBlend.fromName(_prefs.getString(_artworkBlendKey));

  Future<void> setArtworkBlend(ArtworkBlend value) =>
      _prefs.setString(_artworkBlendKey, value.name);

  double get artworkScale => _prefs.getDouble(_artworkScaleKey) ?? 1.0;

  Future<void> setArtworkScale(double value) =>
      _prefs.setDouble(_artworkScaleKey, value);

  int get artworkColor {
    const oldPreviewGold = 0xFFFFCC00;
    const appGold = 0xFFF2B84B;
    final saved = _prefs.getInt(_artworkColorKey);
    if (!(_prefs.getBool(_artworkGoldMigratedKey) ?? false)) {
      _prefs.setBool(_artworkGoldMigratedKey, true);
      if (saved == oldPreviewGold) {
        _prefs.setInt(_artworkColorKey, appGold);
        return appGold;
      }
    }
    return saved ?? appGold;
  }

  Future<void> setArtworkColor(int value) =>
      _prefs.setInt(_artworkColorKey, value);

  ArtworkLayer get artworkLayer =>
      ArtworkLayer.fromName(_prefs.getString(_artworkLayerKey));

  Future<void> setArtworkLayer(ArtworkLayer value) =>
      _prefs.setString(_artworkLayerKey, value.name);

  /// Whether any `hint_kit` guided tour is allowed to auto-start at all. Off
  /// by default; turning it off doesn't touch which tours are individually
  /// marked seen (see `PrefsTourStorage`) — it just makes every one of them
  /// behave as already-seen until this is switched back on.
  bool get tutorialsEnabled => _prefs.getBool(_tutorialsEnabledKey) ?? false;

  Future<void> setTutorialsEnabled(bool value) =>
      _prefs.setBool(_tutorialsEnabledKey, value);
}
