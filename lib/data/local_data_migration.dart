import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_constellation.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_cycle.dart';
import '../models/project.dart';
import '../models/reflection_answer.dart';
import '../models/star.dart';
import 'repository_write.dart';
import 'uuid_migration.dart';
import 'area_content_migration.dart';
import 'reflection_migration.dart';

const currentLocalSchemaVersion = 4;
const metadataMigrationJournalKey = 'local-data-metadata-migration';

final _decoders = <String, Object Function(Map<String, dynamic>)>{
  'projects-list': Project.fromJson,
  'stars-list-v1': Star.fromJson,
  'habits-list-v1': Habit.fromJson,
  'habit-completions-list-v1': HabitCompletion.fromJson,
  'habit-cycles-v1': HabitCycle.fromJson,
  'custom-constellations-list': StarsShape.fromJson,
  'reflection-answers-v1': ReflectionAnswer.fromJson,
};

/// Run all local upgrades before constructing repositories or revealing the UI.
/// Each step commits its schema only after its complete journal is persisted.
Future<void> migrateLocalData(SharedPreferences prefs) async {
  await migrateLocalIdsToUuid(
    prefs,
    maxKnownSchemaVersion: currentLocalSchemaVersion,
  );
  await _migrateRecordMetadata(prefs);
  await migrateAreaContent(prefs);
  await migrateReflections(prefs);
}

Future<void> _migrateRecordMetadata(SharedPreferences prefs) async {
  final schema = jsonDecode(prefs.getString(localSchemaKey)!) as Map;
  if ((schema['version'] as int) >= 2) {
    if (prefs.containsKey(metadataMigrationJournalKey)) {
      await writeRepositoryValue(prefs, metadataMigrationJournalKey, null);
    }
    return;
  }

  final pending = prefs.getString(metadataMigrationJournalKey);
  final writes = pending == null
      ? <String, String>{}
      : Map<String, String>.from(jsonDecode(pending) as Map);
  if (writes.keys.any((key) => !_decoders.containsKey(key))) {
    throw const FormatException('Invalid metadata migration journal');
  }
  if (pending == null) {
    for (final key in _decoders.keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      final rows = key == 'reflection-answers-v1'
          ? (decoded as Map<String, dynamic>).values
          : decoded as List;
      for (final value in rows) {
        final row = value as Map<String, dynamic>;
        row['updatedAt'] ??=
            row['createdAt'] ?? row['completedDate'] ?? row['answeredDate'];
        row['deleted'] ??= false;
        _decoders[key]!(row);
      }
      writes[key] = jsonEncode(decoded);
    }
  } else {
    // Validate the whole persisted target before resuming any partial writes.
    for (final entry in writes.entries) {
      final decoded = jsonDecode(entry.value);
      final rows = entry.key == 'reflection-answers-v1'
          ? (decoded as Map<String, dynamic>).values
          : decoded as List;
      for (final row in rows) {
        _decoders[entry.key]!(Map<String, dynamic>.from(row as Map));
      }
    }
  }
  if (pending == null) {
    await writeRepositoryValue(
      prefs,
      metadataMigrationJournalKey,
      jsonEncode(writes),
    );
  }
  for (final entry in writes.entries) {
    await writeRepositoryValue(prefs, entry.key, entry.value);
  }
  await writeRepositoryValue(prefs, localSchemaKey, jsonEncode({'version': 2}));
  await writeRepositoryValue(prefs, metadataMigrationJournalKey, null);
}
