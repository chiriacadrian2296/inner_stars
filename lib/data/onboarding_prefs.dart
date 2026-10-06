import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has already been shown the first-launch onboarding
/// tutorial (see `OnboardingScreen`) — checked once at app start (`main.dart`)
/// to decide whether to auto-show it, and set the moment it's dismissed for
/// any reason (finished, skipped, or backed out of), so it never appears
/// automatically more than once. Its own tiny SharedPreferences-backed flag,
/// same reasoning as `ConstellationEditorPrefs`.
class OnboardingPrefs {
  OnboardingPrefs(this._prefs);

  static const _seenKey = 'onboarding.seen';

  final SharedPreferences _prefs;

  static Future<OnboardingPrefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingPrefs(prefs);
  }

  bool get hasSeenOnboarding => _prefs.getBool(_seenKey) ?? false;

  Future<void> setSeenOnboarding(bool value) => _prefs.setBool(_seenKey, value);
}
