import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences updates its memory cache before the platform acknowledges
/// a write. Restore that cache on failure so readers never show a false save.
Future<void> writeRepositoryValue(
  SharedPreferences prefs,
  String key,
  String? value,
) async {
  final previous = prefs.getString(key);
  try {
    final saved = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, value);
    if (!saved) throw StateError('Could not save repository');
  } catch (_) {
    try {
      if (previous == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
    } catch (_) {
      // The cache is restored before this platform operation is attempted.
    }
    rethrow;
  }
}
