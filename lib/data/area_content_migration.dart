import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/life_area.dart';
import '../models/sync_text_value.dart';
import 'area_vision_repository.dart';
import 'moodboard_repository.dart';
import 'repository_write.dart';
import 'shooting_star_wish_repository.dart';
import 'uuid_migration.dart';

const areaContentMigrationJournalKey = 'local-data-area-content-migration';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

void _validateAreaWrites(Map<String, String?> writes) {
  for (final entry in writes.entries) {
    if (entry.value == null) {
      if (entry.key == ShootingStarWishRepository.legacyStorageKey) continue;
      if (entry.key.startsWith(legacyMoodboardPrefix)) {
        LifeArea.values.byName(
          entry.key.substring(legacyMoodboardPrefix.length),
        );
        continue;
      }
      throw const FormatException('Invalid area migration deletion');
    }
    final decoded = jsonDecode(entry.value!) as Map<String, dynamic>;
    if (entry.key == AreaVisionRepository.storageKey) {
      for (final value in decoded.values) {
        SyncTextValue.fromJson(Map<String, dynamic>.from(value as Map));
      }
    } else if (entry.key == ShootingStarWishRepository.storageKey) {
      SyncTextValue.fromJson(decoded);
    } else if (entry.key == moodboardStorageKey) {
      final activeCounts = <LifeArea, int>{};
      for (final row in decoded.entries) {
        final item = MoodboardItem.fromJson(
          Map<String, dynamic>.from(row.value as Map),
        );
        if (item.area == null ||
            item.id != row.key ||
            !_uuid.hasMatch(item.id)) {
          throw const FormatException('Invalid moodboard record identity');
        }
        if (!item.deleted) {
          final count = activeCounts.update(
            item.area!,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          if (count > kMaxMoodboardItems) {
            throw const FormatException('Moodboard limit exceeded');
          }
        }
      }
    } else {
      throw const FormatException('Invalid area migration target');
    }
  }
}

/// Schema 3: keyed area text and individually identifiable moodboard records.
/// Legacy overflow remains as tombstones with its content; no media is erased.
Future<void> migrateAreaContent(SharedPreferences prefs) async {
  final version =
      (jsonDecode(prefs.getString(localSchemaKey)!) as Map)['version'] as int;
  if (version >= 3) {
    if (prefs.containsKey(areaContentMigrationJournalKey)) {
      await writeRepositoryValue(prefs, areaContentMigrationJournalKey, null);
    }
    return;
  }
  if (version != 2) throw StateError('Record metadata must be migrated first');
  final pending = prefs.getString(areaContentMigrationJournalKey);
  final writes = pending == null
      ? <String, String?>{}
      : Map<String, String?>.from(jsonDecode(pending) as Map);
  if (pending == null) {
    final stamp = DateTime.now().toUtc().toIso8601String();
    final visionRaw = prefs.getString(AreaVisionRepository.storageKey);
    if (visionRaw != null) {
      final visions = jsonDecode(visionRaw) as Map<String, dynamic>;
      writes[AreaVisionRepository.storageKey] = jsonEncode(
        visions.map(
          (key, value) => MapEntry(
            key,
            value is String
                ? {
                    'value': value,
                    'updatedAt': stamp,
                    'deleted': value.trim().isEmpty,
                  }
                : value,
          ),
        ),
      );
    }
    final wish = prefs.getString(ShootingStarWishRepository.legacyStorageKey);
    final newWish = prefs.getString(ShootingStarWishRepository.storageKey);
    if (newWish != null) {
      writes[ShootingStarWishRepository.storageKey] = newWish;
    } else if (wish != null) {
      writes[ShootingStarWishRepository.storageKey] = jsonEncode({
        'value': wish.trim(),
        'updatedAt': stamp,
        'deleted': wish.trim().isEmpty,
      });
    }

    final records = <String, Map<String, dynamic>>{};
    final identities = <String>{};
    void add(Map<String, dynamic> row, LifeArea area, int position) {
      final originalId = row['id'] as String;
      var id = originalId;
      if (!_uuid.hasMatch(id) || identities.contains(id)) {
        id = const Uuid().v4();
      }
      identities.add(id);
      records[id] = {
        ...row,
        'id': id,
        'area': area.name,
        'position': position,
        'updatedAt': row['updatedAt'] ?? stamp,
        'deleted': row['deleted'] ?? false,
      };
    }

    final currentRaw = prefs.getString(moodboardStorageKey);
    if (currentRaw != null) {
      for (final value
          in (jsonDecode(currentRaw) as Map<String, dynamic>).values) {
        final row = Map<String, dynamic>.from(value as Map);
        add(
          row,
          LifeArea.values.byName(row['area'] as String),
          row['position'] as int? ?? 0,
        );
      }
    }
    final legacyKeys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(legacyMoodboardPrefix))
            .toList()
          ..sort();
    for (final key in legacyKeys) {
      final area = LifeArea.values.byName(
        key.substring(legacyMoodboardPrefix.length),
      );
      final rows = jsonDecode(prefs.getString(key)!) as List;
      final seen = <String>{};
      var position =
          records.values
              .where((row) => row['area'] == area.name)
              .fold<int>(
                -1,
                (max, row) => (row['position'] as int) > max
                    ? row['position'] as int
                    : max,
              ) +
          1;
      for (final value in rows) {
        final row = Map<String, dynamic>.from(value as Map);
        if (!seen.add(row['id'] as String)) {
          throw const FormatException('Duplicate legacy moodboard identity');
        }
        add(row, area, position++);
      }
    }
    for (final area in LifeArea.values) {
      final rows =
          records.values.where((row) => row['area'] == area.name).toList()
            ..sort(
              (a, b) => (a['position'] as int).compareTo(b['position'] as int),
            );
      var active = 0;
      for (final row in rows) {
        if (row['deleted'] == true) continue;
        if (active++ >= kMaxMoodboardItems) row['deleted'] = true;
      }
    }
    if (currentRaw != null || legacyKeys.isNotEmpty) {
      writes[moodboardStorageKey] = jsonEncode(records);
    }
    // New records precede removals; the complete journal makes every stage replayable.
    if (wish != null) {
      writes[ShootingStarWishRepository.legacyStorageKey] = null;
    }
    for (final key in legacyKeys) {
      writes[key] = null;
    }
  }
  _validateAreaWrites(writes);
  if (pending == null) {
    await writeRepositoryValue(
      prefs,
      areaContentMigrationJournalKey,
      jsonEncode(writes),
    );
  }
  for (final entry in writes.entries) {
    await writeRepositoryValue(prefs, entry.key, entry.value);
  }
  await writeRepositoryValue(prefs, localSchemaKey, jsonEncode({'version': 3}));
  await writeRepositoryValue(prefs, areaContentMigrationJournalKey, null);
}
