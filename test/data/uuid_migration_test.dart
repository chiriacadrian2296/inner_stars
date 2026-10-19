import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_cycle_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/data/uuid_migration.dart';

final _uuid = matches(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Map<String, Object> legacyData() {
  const created = '2026-01-01T10:00:00.000';
  String rows(Map<String, Object?> row) => jsonEncode([row]);
  return {
    'unrelated-setting': 'keep me',
    'projects-list': rows({
      'id': 1,
      'name': 'Casa',
      'area': 'personal',
      'iconSlug': 'home',
      'customConstellationId': 1,
      'createdAt': created,
    }),
    'stars-list-v1': rows({
      'id': 1,
      'projectId': 1,
      'title': 'Vittoria',
      'slotSequence': 4,
      'number': 9,
      'intensity': 3,
      'achievedDate': created,
      'createdAt': created,
      'dead': true,
      'photoPath': 'local/photo.jpg',
      'media': [
        {
          'id': 'audio-original',
          'kind': 'voice',
          'path': 'local/audio.m4a',
          'createdAt': created,
        },
      ],
    }),
    'habits-list-v1': rows({
      'id': 1,
      'projectId': 1,
      'title': 'Camminare',
      'createdAt': created,
    }),
    'habit-completions-list-v1': rows({
      'id': 1767261600000000,
      'habitId': 1,
      'date': '2026-01-01T00:00:00.000',
    }),
    'habit-cycles-v1': rows({
      'id': 1,
      'habitId': 1,
      'startDate': created,
      'completedDate': created,
      'length': 1,
      'intensity': 3,
      'resolved': true,
      'whatHelped': 'Costanza',
    }),
    'custom-constellations-list': rows({
      'id': 1,
      'name': 'Forma',
      'points': [
        [0.2, 0.3],
      ],
      'edges': [],
      'presetId': 'heart',
      'createdAt': created,
    }),
  };
}

Map<String, dynamic> row(SharedPreferences prefs, String key) =>
    Map<String, dynamic>.from(
      (jsonDecode(prefs.getString(key)!) as List).single as Map,
    );

void verifyRelations(SharedPreferences prefs) {
  final projects = ProjectRepository(prefs).getAll();
  final stars = StarRepository(prefs).getAll();
  final habits = HabitRepository(prefs).getAll();
  final completions = HabitCompletionRepository(prefs).getAll();
  final cycles = HabitCycleRepository(prefs).getAll();
  final shapes = StarsShapeRepository(prefs).getAll();
  final ids = [
    projects.single.id,
    stars.single.id,
    habits.single.id,
    completions.single.id,
    cycles.single.id,
    shapes.single.id,
  ];
  for (final id in ids) {
    expect(id, _uuid);
  }
  expect(ids.toSet(), hasLength(6));
  expect(stars.single.projectId, projects.single.id);
  expect(habits.single.projectId, projects.single.id);
  expect(completions.single.habitId, habits.single.id);
  expect(cycles.single.habitId, habits.single.id);
  expect(projects.single.starsShapeId, shapes.single.id);
  expect(stars.single.slotSequence, 4);
  expect(stars.single.number, 9);
  expect(stars.single.dead, isTrue);
  expect(stars.single.media.single.id, 'audio-original');
  expect(prefs.getString('unrelated-setting'), 'keep me');
  expect(prefs.getString(uuidMigrationJournalKey), isNull);
}

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(Map<String, Object> data, this.blocked, this.throwsError)
    : super.withData({
        for (final entry in data.entries) 'flutter.${entry.key}': entry.value,
      });

  final String blocked;
  final bool throwsError;
  bool armed = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (armed && key == 'flutter.$blocked') {
      armed = false;
      if (throwsError) throw StateError('Simulated storage failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (armed && key == 'flutter.$blocked') {
      armed = false;
      if (throwsError) throw StateError('Simulated storage failure');
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'migrates all six collections, preserving content and foreign keys',
    () async {
      final data = legacyData();
      SharedPreferences.setMockInitialValues(data);
      final prefs = await SharedPreferences.getInstance();
      await migrateLocalIdsToUuid(prefs);
      verifyRelations(prefs);
      final star = row(prefs, 'stars-list-v1');
      final before = Map<String, dynamic>.from(
        (jsonDecode(data['stars-list-v1']! as String) as List).single as Map,
      );
      before['id'] = star['id'];
      before['projectId'] = star['projectId'];
      expect(star, before);
      expect(
        row(prefs, 'habit-completions-list-v1')['createdAt'],
        DateTime.fromMicrosecondsSinceEpoch(1767261600000000).toIso8601String(),
      );
      final snapshot = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      await migrateLocalIdsToUuid(prefs);
      expect({
        for (final key in prefs.getKeys()) key: prefs.get(key),
      }, snapshot);
    },
  );

  test(
    'keeps UUIDs already present while remapping legacy references',
    () async {
      final data = legacyData();
      const existingId = '613382c2-1ffc-4be4-89ee-58cd69307164';
      final project = Map<String, dynamic>.from(
        (jsonDecode(data['projects-list']! as String) as List).single as Map,
      );
      project['id'] = existingId;
      data['projects-list'] = jsonEncode([project]);
      final star = Map<String, dynamic>.from(
        (jsonDecode(data['stars-list-v1']! as String) as List).single as Map,
      );
      star['projectId'] = existingId;
      data['stars-list-v1'] = jsonEncode([star]);
      SharedPreferences.setMockInitialValues(data);
      final prefs = await SharedPreferences.getInstance();
      await migrateLocalIdsToUuid(prefs);
      expect(ProjectRepository(prefs).getAll().single.id, existingId);
      expect(StarRepository(prefs).getAll().single.projectId, existingId);
    },
  );

  for (final key in [
    ...legacyData().keys.where((key) => key != 'unrelated-setting'),
    localSchemaKey,
    uuidMigrationJournalKey,
  ]) {
    for (final throwsError in [false, true]) {
      test(
        'resumes after write failure at $key (throws=$throwsError)',
        () async {
          final data = legacyData();
          SharedPreferences.setMockInitialValues(data);
          final prefs = await SharedPreferences.getInstance();
          final previousStore = SharedPreferencesStorePlatform.instance;
          addTearDown(
            () => SharedPreferencesStorePlatform.instance = previousStore,
          );
          SharedPreferencesStorePlatform.instance = _FailingStore(
            data,
            key,
            throwsError,
          );
          await expectLater(migrateLocalIdsToUuid(prefs), throwsStateError);
          expect(prefs.getString(localSchemaKey), isNull);
          final journal = prefs.getString(uuidMigrationJournalKey);
          await prefs
              .reload(); // Simulate reading the durable state on restart.
          await migrateLocalIdsToUuid(prefs);
          verifyRelations(prefs);
          if (journal != null) {
            final target = Map<String, String>.from(jsonDecode(journal) as Map);
            for (final entry in target.entries) {
              expect(prefs.getString(entry.key), entry.value);
            }
          }
        },
      );
    }
  }

  for (final invalid in [
    'broken JSON',
    '{}',
    '[{"id":null}]',
    '[{"id":1},{"id":1}]',
  ]) {
    test('malformed data is left untouched: $invalid', () async {
      final data = legacyData()..['habits-list-v1'] = invalid;
      SharedPreferences.setMockInitialValues(data);
      final prefs = await SharedPreferences.getInstance();
      await expectLater(migrateLocalIdsToUuid(prefs), throwsA(anything));
      for (final entry in data.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
      expect(prefs.getString(uuidMigrationJournalKey), isNull);
      expect(prefs.getString(localSchemaKey), isNull);
    });
  }

  test(
    'initializes an empty database without creating fake collections',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await migrateLocalIdsToUuid(prefs);
      expect(prefs.getKeys(), {localSchemaKey});
      await migrateLocalIdsToUuid(prefs);
      expect(prefs.getKeys(), {localSchemaKey});
    },
  );

  test('cleans up a journal after the version was already committed', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      localSchemaKey,
      jsonEncode({'version': localSchemaVersion}),
    );
    await prefs.setString(uuidMigrationJournalKey, '{}');
    await migrateLocalIdsToUuid(prefs);
    expect(prefs.getString(uuidMigrationJournalKey), isNull);
  });

  test('does not downgrade a newer schema', () async {
    final prefs = await SharedPreferences.getInstance();
    final schema = jsonEncode({'version': localSchemaVersion + 1});
    await prefs.setString(localSchemaKey, schema);
    await expectLater(migrateLocalIdsToUuid(prefs), throwsStateError);
    expect(prefs.getString(localSchemaKey), schema);
  });

  test('orphan references keep their identity and are not dropped', () async {
    final data = legacyData();
    final star = Map<String, dynamic>.from(
      (jsonDecode(data['stars-list-v1']! as String) as List).single as Map,
    );
    star['projectId'] = 99;
    data['stars-list-v1'] = jsonEncode([
      star,
      {...star, 'id': 2, 'projectId': '99'},
    ]);
    SharedPreferences.setMockInitialValues(data);
    final prefs = await SharedPreferences.getInstance();
    await migrateLocalIdsToUuid(prefs);
    final stars = StarRepository(prefs).getAll();
    expect(stars, hasLength(2));
    expect(stars[0].projectId, stars[1].projectId);
    expect(stars[0].projectId, _uuid);
    expect(
      stars[0].projectId,
      isNot(ProjectRepository(prefs).getAll().single.id),
    );
  });

  test(
    'retries failed journal cleanup after the schema is committed',
    () async {
      final data = {
        localSchemaKey: jsonEncode({'version': localSchemaVersion}),
        uuidMigrationJournalKey: '{}',
      };
      SharedPreferences.setMockInitialValues(data);
      final prefs = await SharedPreferences.getInstance();
      final previousStore = SharedPreferencesStorePlatform.instance;
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = previousStore,
      );
      SharedPreferencesStorePlatform.instance = _FailingStore(
        data,
        uuidMigrationJournalKey,
        false,
      );
      await expectLater(migrateLocalIdsToUuid(prefs), throwsStateError);
      expect(prefs.getString(uuidMigrationJournalKey), '{}');
      await prefs.reload();
      await migrateLocalIdsToUuid(prefs);
      expect(prefs.getKeys(), {localSchemaKey});
    },
  );
}
