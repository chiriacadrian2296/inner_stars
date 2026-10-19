import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_text_value.dart';
import 'repository_write.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

/// The existing single Galaxy wish, stored with sync metadata rather than history.
class ShootingStarWishRepository extends ChangeNotifier
    with SyncableRepository {
  ShootingStarWishRepository(this._prefs);
  static const legacyStorageKey = 'shooting-star-wish-v1';
  static const storageKey = 'shooting-star-wish-v2';
  final SharedPreferences _prefs;

  @override
  String get syncName => 'shooting-star-wish';

  @override
  late final LocalCollection syncCollection = LocalCollection.single(
    _prefs,
    storageKey,
  );
  static Future<ShootingStarWishRepository> create() async =>
      ShootingStarWishRepository(await SharedPreferences.getInstance());

  SyncTextValue? _read() {
    final raw = _prefs.getString(storageKey);
    if (raw != null) {
      return SyncTextValue.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final old = _prefs.getString(legacyStorageKey)?.trim();
    return old == null || old.isEmpty
        ? null
        : SyncTextValue(
            value: old,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          );
  }

  SyncTextValue? getRecord({bool includeDeleted = false}) {
    final record = _read();
    return record == null || (!includeDeleted && record.deleted)
        ? null
        : record;
  }

  String? get wish => getRecord()?.value;

  Future<void> save(String value) async {
    final previous = _read();
    final trimmed = value.trim();
    final records = reconcileLocalRecords(
      {if (previous != null) 'current': previous.toJson()},
      {
        if (trimmed.isNotEmpty)
          'current': SyncTextValue(
            value: trimmed,
            updatedAt: DateTime.now(),
          ).toJson(),
      },
    );
    if (records.isNotEmpty) {
      await writeRepositoryValue(
        _prefs,
        storageKey,
        jsonEncode(records['current']),
      );
      notifyListeners();
    }
  }

  Future<void> clear() => save('');
}
