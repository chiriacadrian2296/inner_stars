import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository_write.dart';
import 'local_collection.dart';
import 'merge.dart';

/// The user's settings as a synced collection: one record per preference key,
/// `{id: key, value, updatedAt, deleted}`. Settings carry no clock of their
/// own and have dozens of setters, so changes are detected by comparing each
/// value with the last one seen ([metaKey]) and dated when noticed, which is
/// at the latest the next sync. Per-device settings are excluded.
class SettingsCollection implements SyncCollection {
  SettingsCollection(this._prefs);
  final SharedPreferences _prefs;

  static const metaKey = 'sync.settings-meta';

  /// Galaxy quality and every volume stay per device; the rest are device
  /// migration flags, not choices.
  static bool isSynced(String key) {
    if (key == 'settings.galaxyQuality' ||
        key == 'settings.artworkGoldMigrated') {
      return false;
    }
    if (key.startsWith('audio-') && key.endsWith('-volume')) return false;
    return key.startsWith('settings.') || key.startsWith('audio-');
  }

  Map<String, Map<String, dynamic>> _readMeta() {
    final raw = _prefs.getString(metaKey);
    if (raw == null) return {};
    return {
      for (final e in (jsonDecode(raw) as Map).entries)
        e.key as String: Map<String, dynamic>.from(e.value as Map),
    };
  }

  Future<void> _writeMeta(Map<String, Map<String, dynamic>> meta) =>
      writeRepositoryValue(_prefs, metaKey, jsonEncode(meta));

  Object? _current(String key) => _prefs.get(key);

  /// Dates every synced preference whose value differs from the last one seen.
  /// Clocks are strictly increasing per key.
  Future<void> _stampChanges() async {
    final meta = _readMeta();
    final now = DateTime.now().toUtc();
    var dirty = false;
    for (final key in _prefs.getKeys().where(isSynced)) {
      final value = _current(key);
      final seen = meta[key];
      if (seen != null && jsonEncode(seen['value']) == jsonEncode(value)) {
        continue;
      }
      final previous = seen == null
          ? null
          : DateTime.parse(seen['updatedAt'] as String);
      final next = previous == null || now.isAfter(previous)
          ? now
          : previous.add(const Duration(microseconds: 1));
      meta[key] = {'value': value, 'updatedAt': next.toIso8601String()};
      dirty = true;
    }
    if (dirty) await _writeMeta(meta);
  }

  SyncRecord _record(String key, Map<String, dynamic> seen) => {
    'id': key,
    'value': seen['value'],
    'updatedAt': seen['updatedAt'],
    'deleted': false,
  };

  @override
  List<SyncRecord> readAll() => [
    for (final e in _readMeta().entries)
      if (isSynced(e.key)) _record(e.key, e.value),
  ];

  @override
  Future<List<SyncRecord>> exportChangesSince(DateTime? since) async {
    await _stampChanges();
    return [
      for (final r in readAll())
        if (since == null ||
            DateTime.parse(r['updatedAt'] as String).isAfter(since))
          r,
    ];
  }

  Future<void> _set(String key, Object? value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is List) {
      await _prefs.setStringList(key, value.cast<String>());
    } else if (value is num) {
      // JSON loses the int/double difference for whole numbers.
      if (_prefs.get(key) is double || value is double) {
        await _prefs.setDouble(key, value.toDouble());
      } else {
        await _prefs.setInt(key, value.toInt());
      }
    }
  }

  @override
  Future<int> applyRemote(List<SyncRecord> remote) async {
    await _stampChanges();
    final meta = _readMeta();
    var changed = 0;
    for (final incoming in remote) {
      final key = incoming['id'] as String;
      if (!isSynced(key) || incoming['deleted'] == true) continue;
      final seen = meta[key];
      if (seen != null &&
          pickWinner(_record(key, seen), incoming) != SyncWinner.remote) {
        continue;
      }
      await _set(key, incoming['value']);
      meta[key] = {'value': _current(key), 'updatedAt': incoming['updatedAt']};
      changed++;
    }
    if (changed > 0) await _writeMeta(meta);
    return changed;
  }
}
