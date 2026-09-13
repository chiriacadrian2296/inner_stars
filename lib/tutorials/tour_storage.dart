import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which `hint_kit` guided tours this user has already finished
/// (or skipped — see [TourStorage.markCompleted]'s own doc comment), so
/// none of them auto-starts a second time. Same tiny SharedPreferences-
/// backed shape as `OnboardingPrefs`, just implementing hint_kit's own
/// [TourStorage] interface instead of a bespoke one, since `TourScope`
/// reads it directly.
class PrefsTourStorage extends TourStorage {
  PrefsTourStorage(this._prefs);

  static const _keyPrefix = 'tour.';

  final SharedPreferences _prefs;

  static Future<PrefsTourStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsTourStorage(prefs);
  }

  @override
  Future<bool> isCompleted(String tour) async =>
      _prefs.getBool('$_keyPrefix$tour') ?? false;

  @override
  Future<void> markCompleted(String tour) =>
      _prefs.setBool('$_keyPrefix$tour', true);

  @override
  Future<void> reset(String tour) => _prefs.remove('$_keyPrefix$tour');
}
