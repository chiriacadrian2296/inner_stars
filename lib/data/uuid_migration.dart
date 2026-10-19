import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_constellation.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_cycle.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'repository_write.dart';

/// The local schema is advanced only after all collections have been written.
const localSchemaKey = 'local-data-schema';
const uuidMigrationJournalKey = 'local-data-uuid-migration';
const localSchemaVersion = 1;

const _collections = [
  'projects-list',
  'stars-list-v1',
  'habits-list-v1',
  'habit-completions-list-v1',
  'habit-cycles-v1',
  'custom-constellations-list',
];

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

void _validateWrites(Map<String, String> writes) {
  for (final entry in writes.entries) {
    for (final value in jsonDecode(entry.value) as List) {
      final row = Map<String, dynamic>.from(value as Map);
      switch (entry.key) {
        case 'projects-list':
          Project.fromJson(row);
        case 'stars-list-v1':
          Star.fromJson(row);
        case 'habits-list-v1':
          Habit.fromJson(row);
        case 'habit-completions-list-v1':
          HabitCompletion.fromJson(row);
        case 'habit-cycles-v1':
          HabitCycle.fromJson(row);
        case 'custom-constellations-list':
          StarsShape.fromJson(row);
      }
    }
  }
}

/// Converts legacy numeric identities and every foreign key before repositories
/// are read. A persisted journal contains the complete target state, so a crash
/// between writes is resumed with the same UUIDs on the next launch. Malformed
/// input fails before any collection is changed, rather than losing records.
Future<void> migrateLocalIdsToUuid(
  SharedPreferences prefs, {
  int maxKnownSchemaVersion = localSchemaVersion,
}) async {
  final schema = prefs.getString(localSchemaKey);
  final version = schema == null
      ? 0
      : (jsonDecode(schema) as Map<String, dynamic>)['version'] as int;
  if (version > maxKnownSchemaVersion) {
    throw StateError('Local data was written by a newer app schema');
  }

  final pending = prefs.getString(uuidMigrationJournalKey);
  if (version >= localSchemaVersion) {
    // A crash after committing the version may leave only journal cleanup.
    if (pending != null) {
      await writeRepositoryValue(prefs, uuidMigrationJournalKey, null);
    }
    return;
  }

  final Map<String, String> writes;
  if (pending != null) {
    writes = Map<String, String>.from(jsonDecode(pending) as Map);
    if (writes.keys.any((key) => !_collections.contains(key))) {
      throw const FormatException('Invalid UUID migration journal');
    }
    _validateWrites(writes);
  } else {
    final records = <String, List<Map<String, dynamic>>>{};
    for (final key in _collections) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      records[key] = [
        for (final row in jsonDecode(raw) as List)
          Map<String, dynamic>.from(row as Map),
      ];
    }

    final ids = <String, Map<String, String>>{};
    String remap(String collection, Object? oldId) {
      if (oldId is! int && (oldId is! String || oldId.isEmpty)) {
        throw FormatException('Invalid identity in $collection');
      }
      final value = oldId.toString();
      return ids
          .putIfAbsent(collection, () => {})
          .putIfAbsent(
            value,
            () => _uuidV4.hasMatch(value) ? value : const Uuid().v4(),
          );
    }

    // Register identities first: equal old numbers in different collections
    // belong to different records; references within one collection share a map.
    for (final entry in records.entries) {
      final seen = <String>{};
      for (final row in entry.value) {
        final oldId = row['id'];
        if (!seen.add(oldId.toString())) {
          throw FormatException('Duplicate identity in ${entry.key}');
        }
        remap(entry.key, oldId);
      }
    }

    writes = {};
    for (final entry in records.entries) {
      for (final row in entry.value) {
        final oldId = row['id'];
        row['id'] = remap(entry.key, oldId);
        if (entry.key == 'projects-list' &&
            row['customConstellationId'] != null) {
          row['customConstellationId'] = remap(
            'custom-constellations-list',
            row['customConstellationId'],
          );
        }
        if (entry.key == 'stars-list-v1' || entry.key == 'habits-list-v1') {
          row['projectId'] = remap('projects-list', row['projectId']);
        }
        if (entry.key == 'habit-completions-list-v1' ||
            entry.key == 'habit-cycles-v1') {
          row['habitId'] = remap('habits-list-v1', row['habitId']);
        }
        if (entry.key == 'habit-completions-list-v1' &&
            row['createdAt'] == null) {
          final numericId = int.tryParse(oldId.toString());
          row['createdAt'] = numericId == null
              ? row['date']
              : DateTime.fromMicrosecondsSinceEpoch(numericId)
                    .toIso8601String();
        }
      }
      writes[entry.key] = jsonEncode(entry.value);
    }
    _validateWrites(writes);
    await writeRepositoryValue(
      prefs,
      uuidMigrationJournalKey,
      jsonEncode(writes),
    );
  }

  for (final entry in writes.entries) {
    await writeRepositoryValue(prefs, entry.key, entry.value);
  }
  await writeRepositoryValue(
    prefs,
    localSchemaKey,
    jsonEncode({'version': localSchemaVersion}),
  );
  await writeRepositoryValue(prefs, uuidMigrationJournalKey, null);
}
