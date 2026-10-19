import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection.dart';
import '../models/reflection_answer.dart';
import 'reflection_repository.dart';
import 'repository_write.dart';
import 'uuid_migration.dart';

const reflectionMigrationJournalKey = 'local-data-reflection-migration';
const _legacyKey = 'reflection-answers-v1';

/// Preserve each legacy answer, including deletion records, with a stable UUID
/// in the journal. Commit the new collection before removing the old one.
Future<void> migrateReflections(SharedPreferences prefs) async {
  final schema =
      (jsonDecode(prefs.getString(localSchemaKey)!) as Map)['version'] as int;
  if (schema >= 4) {
    if (prefs.containsKey(reflectionMigrationJournalKey)) {
      await writeRepositoryValue(prefs, reflectionMigrationJournalKey, null);
    }
    return;
  }
  if (schema != 3) throw StateError('Area content must be migrated first');
  final pending = prefs.getString(reflectionMigrationJournalKey);
  late final String target;
  if (pending != null) {
    target = pending;
  } else {
    if (prefs.containsKey(ReflectionRepository.storageKey)) {
      throw StateError('Unexpected reflection collection before migration');
    }
    final strings = stringsForLocale(
      prefs.getString('settings.locale') ?? 'en',
    );
    final legacy = prefs.getString(_legacyKey);
    final answers = legacy == null
        ? <String, dynamic>{}
        : jsonDecode(legacy) as Map<String, dynamic>;
    final records = <Map<String, dynamic>>[];
    for (final entry in answers.entries) {
      final raw = Map<String, dynamic>.from(entry.value as Map);
      final answer = ReflectionAnswer.fromJson(raw);
      if (entry.key != '${answer.area.name}|${answer.questionId}') {
        throw const FormatException('Reflection answer identity mismatch');
      }
      final questions = answer.area.reflectionQuestions(strings);
      final index = int.tryParse(answer.questionId);
      final title = index != null && index >= 0 && index < questions.length
          ? questions[index]
          : strings.areaReflectionsTitle;
      records.add({
        ...raw,
        ...Reflection(
          id: const Uuid().v4(),
          area: answer.area,
          title: title,
          body: answer.answerText,
          origin: ReflectionOrigin.suggested,
          questionId: answer.questionId,
          createdAt: answer.answeredDate,
          updatedAt: answer.updatedAt,
          deleted: answer.deleted,
        ).toJson(),
      });
    }
    target = jsonEncode(records);
  }
  final identities = <String>{};
  for (final value in jsonDecode(target) as List) {
    final record = Reflection.fromJson(Map<String, dynamic>.from(value as Map));
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(record.id) ||
        !identities.add(record.id)) {
      throw const FormatException('Invalid reflection migration identity');
    }
  }
  if (pending == null) {
    await writeRepositoryValue(prefs, reflectionMigrationJournalKey, target);
  }
  await writeRepositoryValue(prefs, ReflectionRepository.storageKey, target);
  await writeRepositoryValue(prefs, _legacyKey, null);
  await writeRepositoryValue(prefs, localSchemaKey, jsonEncode({'version': 4}));
  await writeRepositoryValue(prefs, reflectionMigrationJournalKey, null);
}
