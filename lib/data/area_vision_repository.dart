import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';

/// Reads and writes each [LifeArea]'s "vision" — the user's own words for
/// what kind of reality they want in that area, something to work toward
/// with goals and habits. Unlike a [Project]'s description (a fact about
/// one project), this belongs to the area itself and applies across every
/// project in it. Blank (never written) is the default for all 8 areas.
class AreaVisionRepository {
  AreaVisionRepository(this._prefs);

  static const _storageKey = 'area-visions';

  final SharedPreferences _prefs;

  static Future<AreaVisionRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AreaVisionRepository(prefs);
  }

  Map<String, String> _readAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  /// Empty string when the user hasn't written one yet — never null, so
  /// callers can feed this straight into a [TextEditingController] without
  /// a null check.
  String getVision(LifeArea area) => _readAll()[area.name] ?? '';

  /// A blank (or all-whitespace) [vision] removes the entry entirely rather
  /// than storing an empty string, so [getVision] and "has the user written
  /// anything for this area" stay the same question.
  Future<void> setVision(LifeArea area, String vision) async {
    final all = _readAll();
    final trimmed = vision.trim();
    if (trimmed.isEmpty) {
      all.remove(area.name);
    } else {
      all[area.name] = trimmed;
    }
    final saved = await _prefs.setString(_storageKey, jsonEncode(all));
    if (!saved) throw StateError('Could not persist the area vision');
  }

  /// Used by the "reset all data" action — there's no undo.
  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }
}
