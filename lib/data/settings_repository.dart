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

  Future<void> setReminder({required bool enabled, required int hour, required int minute}) async {
    await _prefs.setBool(_reminderEnabledKey, enabled);
    await _prefs.setInt(_reminderHourKey, hour);
    await _prefs.setInt(_reminderMinuteKey, minute);
  }

  /// Whether the Sky's own coordinate grid is drawn over the nebula
  /// background — off by default, same as it always started before this
  /// became a real setting.
  bool get showGrid => _prefs.getBool(_showGridKey) ?? false;

  Future<void> setShowGrid(bool value) => _prefs.setBool(_showGridKey, value);

  /// Whether any `hint_kit` guided tour is allowed to auto-start at all. Off
  /// by default; turning it off doesn't touch which tours are individually
  /// marked seen (see `PrefsTourStorage`) — it just makes every one of them
  /// behave as already-seen until this is switched back on.
  bool get tutorialsEnabled => _prefs.getBool(_tutorialsEnabledKey) ?? false;

  Future<void> setTutorialsEnabled(bool value) =>
      _prefs.setBool(_tutorialsEnabledKey, value);
}
