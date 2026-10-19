import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import '../models/sync_text_value.dart';
import 'repository_write.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

/// Each area's vision is a keyed record, including a sync tombstone when cleared.
class AreaVisionRepository extends ChangeNotifier with SyncableRepository {
  AreaVisionRepository(this._prefs);
  static const storageKey = 'area-visions';
  final SharedPreferences _prefs;

  @override
  String get syncName => 'area-visions';

  @override
  late final LocalCollection syncCollection = LocalCollection.keyedMap(
    _prefs,
    storageKey,
  );
  static Future<AreaVisionRepository> create() async =>
      AreaVisionRepository(await SharedPreferences.getInstance());

  Map<String, SyncTextValue> _readAll() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        value is String
            ? SyncTextValue(
                value: value,
                updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              )
            : SyncTextValue.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Map<String, SyncTextValue> getAll({bool includeDeleted = false}) {
    try {
      return {
        for (final entry in _readAll().entries)
          if (includeDeleted || !entry.value.deleted) entry.key: entry.value,
      };
    } catch (_) {
      return {};
    }
  }

  String getVision(LifeArea area) => getAll()[area.name]?.value ?? '';

  Future<void> setVision(LifeArea area, String vision) async {
    final all = _readAll();
    final next = {...all}..removeWhere((_, record) => record.deleted);
    final trimmed = vision.trim();
    if (trimmed.isEmpty) {
      next.remove(area.name);
    } else {
      next[area.name] = SyncTextValue(
        value: trimmed,
        updatedAt: DateTime.now(),
      );
    }
    await _save(all, next);
  }

  Future<void> clear() async => _save(_readAll(), {});
  Future<void> _save(
    Map<String, SyncTextValue> previous,
    Map<String, SyncTextValue> next,
  ) async {
    await writeRepositoryValue(
      _prefs,
      storageKey,
      jsonEncode(
        reconcileLocalRecords(
          previous.map((key, record) => MapEntry(key, record.toJson())),
          next.map((key, record) => MapEntry(key, record.toJson())),
        ),
      ),
    );
    notifyListeners();
  }
}
