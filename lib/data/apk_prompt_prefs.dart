import 'package:shared_preferences/shared_preferences.dart';

/// Whether the web build's "download the real Android app" prompt (see
/// `showApkDownloadPrompt`) has already been answered — checked once at app
/// start (`main.dart`) to decide whether to show it, and set the moment it's
/// dismissed for any reason, so it never nags twice. Its own tiny
/// SharedPreferences-backed flag, same shape as [OnboardingPrefs].
class ApkPromptPrefs {
  ApkPromptPrefs(this._prefs);

  static const _dismissedKey = 'apkPrompt.dismissed';

  final SharedPreferences _prefs;

  static Future<ApkPromptPrefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApkPromptPrefs(prefs);
  }

  bool get dismissed => _prefs.getBool(_dismissedKey) ?? false;

  Future<void> setDismissed(bool value) => _prefs.setBool(_dismissedKey, value);
}
