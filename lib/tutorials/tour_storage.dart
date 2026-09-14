import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which `hint_kit` guided tours this user has already finished
/// (or skipped — see [TourStorage.markCompleted]'s own doc comment), so
/// none of them auto-starts a second time. Same tiny SharedPreferences-
/// backed shape as `OnboardingPrefs`, just implementing hint_kit's own
/// [TourStorage] interface instead of a bespoke one, since `TourScope`
/// reads it directly.
class PrefsTourStorage extends TourStorage {
  PrefsTourStorage(this._prefs, {bool Function()? enabled})
      : _enabled = enabled ?? _alwaysEnabled;

  static const _keyPrefix = 'tour.';

  static bool _alwaysEnabled() => true;

  final SharedPreferences _prefs;

  /// Reports whether tours are allowed to auto-start at all right now — see
  /// `SettingsController.tutorialsEnabled`. Checked fresh on every call
  /// (not read once at construction) so flipping the setting takes effect
  /// immediately, without needing a new `PrefsTourStorage` instance.
  final bool Function() _enabled;

  static Future<PrefsTourStorage> create({bool Function()? enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsTourStorage(prefs, enabled: enabled);
  }

  /// Treats every tour as already-completed while [_enabled] reports false
  /// — the actual mechanism behind the app-wide tutorials on/off switch.
  /// `TourController.start` (without `force: true`, which is what every
  /// screen's own auto-start call uses) checks exactly this before running,
  /// so this one check is enough to silence every tour in the app without
  /// touching each of their call sites — and doesn't disturb a tour's real
  /// per-tour completion flag underneath, so switching this back on lets
  /// whichever tours haven't genuinely run yet pick up normally.
  @override
  Future<bool> isCompleted(String tour) async =>
      !_enabled() || (_prefs.getBool('$_keyPrefix$tour') ?? false);

  @override
  Future<void> markCompleted(String tour) =>
      _prefs.setBool('$_keyPrefix$tour', true);

  @override
  Future<void> reset(String tour) => _prefs.remove('$_keyPrefix$tour');
}
