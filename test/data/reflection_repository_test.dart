import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:inner_stars/data/local_data_migration.dart';
import 'package:inner_stars/data/reflection_migration.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/data/uuid_migration.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';

Map<String, Object> snapshot(SharedPreferences prefs) => {
  for (final key in prefs.getKeys()) key: prefs.get(key)!,
};

Map<String, Object> legacy() => {
  localSchemaKey: jsonEncode({'version': 3}),
  'settings.locale': 'it',
  'reflection-answers-v1': jsonEncode({
    for (final question in ['0', '999'])
      'physical|$question': {
        'area': 'physical',
        'questionId': question,
        'answerText': 'Answer $question',
        'answeredDate': '2025-01-01T12:00:00.000Z',
        'updatedAt': '2025-02-01T12:00:00.000Z',
        'deleted': question == '999',
        'extra': 'preserve',
      },
  }),
};

class FailingStore extends InMemorySharedPreferencesStore {
  FailingStore(Map<String, Object> values, this.key, this.throwError)
    : super.withData({
        for (final entry in values.entries) 'flutter.${entry.key}': entry.value,
      });
  final String key;
  final bool throwError;
  bool armed = true;
  bool rejects(String storageKey) {
    if (!armed || storageKey != 'flutter.$key') return false;
    armed = false;
    if (throwError) throw StateError('Simulated failure');
    return true;
  }

  @override
  Future<bool> setValue(String type, String storageKey, Object value) =>
      rejects(storageKey)
      ? Future.value(false)
      : super.setValue(type, storageKey, value);
  @override
  Future<bool> remove(String storageKey) =>
      rejects(storageKey) ? Future.value(false) : super.remove(storageKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('free and suggested reflections coexist and edits preserve identity and origin', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ReflectionRepository(prefs);
    final first = await repo.add(
      area: LifeArea.physical,
      title: ' First ',
      body: ' Body ',
    );
    final second = await repo.add(
      area: LifeArea.physical,
      title: 'Question',
      body: 'Answer',
      origin: ReflectionOrigin.suggested,
      questionId: '0',
      questionText: 'Original question, independent of the title',
    );
    final third = await repo.add(
      area: LifeArea.social,
      title: 'Social',
      body: 'Other',
    );
    expect({first.id, second.id, third.id}.length, 3);
    expect(first.id, matches(RegExp(r'^[0-9a-f-]{14}4[0-9a-f-]{21}$')));
    expect(repo.getForArea(LifeArea.physical).map((r) => r.id), [
      second.id,
      first.id,
    ]);
    final changed = await repo.update(
      second.id,
      title: 'Reworded',
      body: 'New answer',
    );
    expect(changed.createdAt, second.createdAt);
    expect(changed.area, second.area);
    expect(changed.origin, ReflectionOrigin.suggested);
    expect(changed.questionId, '0');
    expect(changed.questionText, second.questionText);
    expect(repo.find(second.id)!.questionText, second.questionText);
    final oldJson = second.toJson()..remove('questionText');
    expect(Reflection.fromJson(oldJson).questionText, isNull);
    expect(changed.updatedAt.isAfter(second.updatedAt), isTrue);
    final unchanged = await repo.update(
      changed.id,
      title: changed.title,
      body: changed.body,
    );
    expect(unchanged.updatedAt, changed.updatedAt);
    expect(repo.find(first.id)!.title, 'First');
    expect(repo.find(first.id)!.updatedAt, first.updatedAt);
  });

  test(
    'delete and repeated reset retain tombstones without an archive',
    () async {
      final repo = await ReflectionRepository.create();
      final first = await repo.add(
        area: LifeArea.physical,
        title: 'Title',
        body: 'Body',
      );
      await repo.delete(first.id);
      expect(repo.find(first.id), isNull);
      expect(repo.getForArea(first.area), isEmpty);
      final deleted = repo.getAll(includeDeleted: true).single;
      expect(deleted.deleted, isTrue);
      expect(deleted.body, first.body);
      await repo.add(area: LifeArea.social, title: 'Other', body: 'Body');
      await repo.clear();
      await repo.clear();
      expect(repo.getAll(), isEmpty);
      expect(repo.getAll(includeDeleted: true).length, 2);
      expect(
        repo
            .getAll(includeDeleted: true)
            .firstWhere((r) => r.id == first.id)
            .updatedAt,
        deleted.updatedAt,
      );
      await expectLater(
        repo.update(first.id, title: 'No', body: 'Restore'),
        throwsStateError,
      );
    },
  );

  test(
    'rejects empty fields and suggested reflections without a question',
    () async {
      final repo = await ReflectionRepository.create();
      for (final fields in [('', 'Body'), ('Title', '  ')]) {
        await expectLater(
          repo.add(area: LifeArea.physical, title: fields.$1, body: fields.$2),
          throwsArgumentError,
        );
      }
      await expectLater(
        repo.add(
          area: LifeArea.physical,
          title: 'Q',
          body: 'A',
          origin: ReflectionOrigin.suggested,
        ),
        throwsArgumentError,
      );
      expect(repo.getAll(includeDeleted: true), isEmpty);
    },
  );

  test(
    'failed edit keeps persisted and cached data and emits no notification',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ReflectionRepository(prefs);
      final record = await repo.add(
        area: LifeArea.physical,
        title: 'Title',
        body: 'Body',
      );
      final before = snapshot(prefs);
      final store = SharedPreferencesStorePlatform.instance;
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      SharedPreferencesStorePlatform.instance = FailingStore(
        before,
        ReflectionRepository.storageKey,
        false,
      );
      var notifications = 0;
      repo.addListener(() => notifications++);
      await expectLater(
        repo.update(record.id, title: 'Changed', body: 'Changed'),
        throwsStateError,
      );
      expect(snapshot(prefs), before);
      expect(repo.find(record.id)!.body, 'Body');
      expect(notifications, 0);
    },
  );

  test('migration preserves answer dates, tombstones, content and localized questions', () async {
    SharedPreferences.setMockInitialValues(legacy());
    final prefs = await SharedPreferences.getInstance();
    await migrateLocalData(prefs);
    final records = ReflectionRepository(prefs).getAll(includeDeleted: true);
    expect(records.length, 2);
    expect(
      records.first.title,
      LifeArea.physical.reflectionQuestions(const StringsIt()).first,
    );
    expect(records.first.origin, ReflectionOrigin.suggested);
    expect(records.first.body, 'Answer 0');
    expect(records.first.createdAt, DateTime.utc(2025, 1, 1, 12));
    expect(records.first.updatedAt, DateTime.utc(2025, 2, 1, 12));
    expect(records.last.title, const StringsIt().areaReflectionsTitle);
    expect(records.last.deleted, isTrue);
    expect(prefs.containsKey('reflection-answers-v1'), isFalse);
    expect(
      (jsonDecode(
        prefs.getString(ReflectionRepository.storageKey)!,
      ) as List).first['extra'],
      'preserve',
    );
    final before = snapshot(prefs);
    await migrateLocalData(prefs);
    expect(snapshot(prefs), before);
  });

  for (final key in [
    reflectionMigrationJournalKey,
    ReflectionRepository.storageKey,
    'reflection-answers-v1',
    localSchemaKey,
  ]) {
    for (final throwError in [false, true]) {
      test(
        'migration resumes with stable UUIDs after $key failure ($throwError)',
        () async {
          SharedPreferences.setMockInitialValues(legacy());
          final prefs = await SharedPreferences.getInstance();
          final store = SharedPreferencesStorePlatform.instance;
          addTearDown(() => SharedPreferencesStorePlatform.instance = store);
          SharedPreferencesStorePlatform.instance = FailingStore(
            snapshot(prefs),
            key,
            throwError,
          );
          await expectLater(migrateLocalData(prefs), throwsStateError);
          expect(jsonDecode(prefs.getString(localSchemaKey)!)['version'], 3);
          final journal = prefs.getString(reflectionMigrationJournalKey);
          await prefs.reload();
          await migrateLocalData(prefs);
          if (journal != null) {
            expect(prefs.getString(ReflectionRepository.storageKey), journal);
          }
          expect(
            ReflectionRepository(prefs).getAll(includeDeleted: true).length,
            2,
          );
          expect(prefs.getString(reflectionMigrationJournalKey), isNull);
        },
      );
    }
  }

  test('malformed legacy data stops before any write', () async {
    final data = legacy();
    final rows = jsonDecode(data['reflection-answers-v1']! as String) as Map;
    rows['physical|0']['area'] = 'unknown';
    data['reflection-answers-v1'] = jsonEncode(rows);
    SharedPreferences.setMockInitialValues(data);
    final prefs = await SharedPreferences.getInstance();
    final before = snapshot(prefs);
    await expectLater(migrateLocalData(prefs), throwsArgumentError);
    expect(snapshot(prefs), before);
  });
}
