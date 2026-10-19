import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:inner_stars/data/area_content_migration.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/local_data_migration.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/data/shooting_star_wish_repository.dart';
import 'package:inner_stars/data/uuid_migration.dart';
import 'package:inner_stars/models/life_area.dart';

Map<String, Object> snapshot(SharedPreferences prefs) => {
  for (final key in prefs.getKeys()) key: prefs.get(key)!,
};

Map<String, Object> legacyData() => {
  localSchemaKey: jsonEncode({'version': 2}),
  AreaVisionRepository.storageKey: jsonEncode({
    'physical': 'Vision',
    'personal': 'Another vision',
  }),
  ShootingStarWishRepository.legacyStorageKey: '  A wish  ',
  '${legacyMoodboardPrefix}physical': jsonEncode([
    for (var i = 0; i < 14; i++)
      {
        'id': 'old-$i',
        'kind': i == 0 ? 'video' : 'quote',
        'content': 'Content $i',
        'extra': 'keep',
      },
  ]),
  '${legacyMoodboardPrefix}social': jsonEncode([
    {
      'id': 'old-0',
      'kind': 'quote',
      'content': 'Social quote',
      'extra': 'keep',
    },
  ]),
};

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(
    Map<String, Object> data,
    this.key,
    this.throwsError, {
    this.removeOnly = false,
  }) : super.withData({
         for (final entry in data.entries) 'flutter.${entry.key}': entry.value,
       });
  final String key;
  final bool throwsError;
  final bool removeOnly;
  bool armed = true;
  bool rejects(String storageKey) {
    if (!armed || storageKey != 'flutter.$key') return false;
    armed = false;
    if (throwsError) throw StateError('Simulated failure');
    return true;
  }

  @override
  Future<bool> setValue(String type, String storageKey, Object value) {
    if (!removeOnly && rejects(storageKey)) return Future.value(false);
    return super.setValue(type, storageKey, value);
  }

  @override
  Future<bool> remove(String storageKey) {
    if (rejects(storageKey)) return Future.value(false);
    return super.remove(storageKey);
  }
}

MoodboardItem quote(String id) =>
    MoodboardItem(id: id, kind: MoodboardKind.quote, content: 'Quote $id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migrates text and moodboard records, retains legacy video and overflow tombstones', () async {
    SharedPreferences.setMockInitialValues(legacyData());
    final prefs = await SharedPreferences.getInstance();
    await migrateLocalData(prefs);
    expect(
      jsonDecode(prefs.getString(localSchemaKey)!)['version'],
      currentLocalSchemaVersion,
    );
    final visions = AreaVisionRepository(prefs);
    final wish = ShootingStarWishRepository(prefs);
    expect(visions.getVision(LifeArea.physical), 'Vision');
    expect(visions.getAll()['physical']!.updatedAt.year, greaterThan(1970));
    expect(wish.wish, 'A wish');
    expect(
      prefs.containsKey(ShootingStarWishRepository.legacyStorageKey),
      isFalse,
    );
    final repo = MoodboardRepository(prefs);
    expect(repo.getItems(LifeArea.physical), hasLength(12));
    expect(repo.getItems(LifeArea.physical).first.kind, MoodboardKind.video);
    expect(repo.getItems(LifeArea.physical).map((item) => item.content), [
      for (var i = 0; i < 12; i++) 'Content $i',
    ]);
    expect(repo.getItems(LifeArea.social).single.content, 'Social quote');
    final all = repo.getAll(includeDeleted: true);
    expect(all, hasLength(15));
    expect(all.where((item) => item.deleted), hasLength(2));
    expect(all.map((item) => item.id).toSet(), hasLength(15));
    for (final item in all) {
      expect(
        item.id,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
    }
    final raw = jsonDecode(prefs.getString(moodboardStorageKey)!) as Map;
    expect(raw.values.every((value) => value['extra'] == 'keep'), isTrue);
    expect(
      prefs.getKeys().where((key) => key.startsWith(legacyMoodboardPrefix)),
      isEmpty,
    );
    final after = snapshot(prefs);
    await migrateLocalData(prefs);
    expect(snapshot(prefs), after);
  });

  test('vision and wish clearing retains timestamps and tombstones across later saves', () async {
    final prefs = await SharedPreferences.getInstance();
    final visions = AreaVisionRepository(prefs);
    await visions.setVision(LifeArea.physical, 'A');
    final first = visions.getAll()['physical']!.updatedAt;
    await visions.setVision(LifeArea.social, 'B');
    expect(visions.getAll()['physical']!.updatedAt, first);
    await visions.setVision(LifeArea.physical, ' ');
    final removed = visions.getAll(includeDeleted: true)['physical']!;
    expect(removed.deleted, isTrue);
    expect(removed.updatedAt.isAfter(first), isTrue);
    await visions.setVision(LifeArea.social, 'C');
    expect(
      visions.getAll(includeDeleted: true)['physical']!.updatedAt,
      removed.updatedAt,
    );
    await visions.clear();
    expect(visions.getAll(), isEmpty);
    expect(visions.getAll(includeDeleted: true), hasLength(2));
    final wish = ShootingStarWishRepository(prefs);
    await wish.save('Wish');
    final wishTime = wish.getRecord()!.updatedAt;
    await wish.clear();
    expect(wish.wish, isNull);
    expect(wish.getRecord(includeDeleted: true)!.deleted, isTrue);
    expect(
      wish.getRecord(includeDeleted: true)!.updatedAt.isAfter(wishTime),
      isTrue,
    );
    final deletedTime = wish.getRecord(includeDeleted: true)!.updatedAt;
    await wish.clear();
    expect(wish.getRecord(includeDeleted: true)!.updatedAt, deletedTime);
  });

  test('repository enforces 12 active items per area and deleted items do not consume slots', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = MoodboardRepository(prefs);
    final items = [for (var i = 0; i < 12; i++) quote('q$i')];
    await repo.save(LifeArea.physical, items);
    final before = snapshot(prefs);
    await expectLater(
      repo.save(LifeArea.physical, [...items, quote('extra')]),
      throwsA(isA<MoodboardLimitException>()),
    );
    expect(snapshot(prefs), before);
    final untouchedTime = repo.getItems(LifeArea.physical).first.updatedAt;
    await repo.save(LifeArea.social, [quote('social')]);
    expect(repo.getItems(LifeArea.physical).first.updatedAt, untouchedTime);
    await repo.save(LifeArea.physical, items.skip(1).toList());
    await repo.save(LifeArea.physical, [
      ...repo.getItems(LifeArea.physical),
      quote('replacement'),
    ]);
    expect(repo.getItems(LifeArea.physical), hasLength(12));
    expect(
      repo
          .getAll(includeDeleted: true)
          .singleWhere((item) => item.id == 'q0')
          .deleted,
      isTrue,
    );
    await repo.clear();
    expect(repo.getAll(), isEmpty);
    expect(repo.getAll(includeDeleted: true), hasLength(14));
  });

  test('new videos are rejected but existing videos can remain while editing the board', () async {
    SharedPreferences.setMockInitialValues(legacyData());
    final prefs = await SharedPreferences.getInstance();
    await migrateLocalData(prefs);
    final repo = MoodboardRepository(prefs);
    final existing = repo.getItems(LifeArea.physical);
    await repo.save(LifeArea.physical, existing);
    final before = snapshot(prefs);
    await expectLater(
      repo.save(LifeArea.social, [
        const MoodboardItem(
          id: 'new-video',
          kind: MoodboardKind.video,
          content: 'new.mp4',
        ),
      ]),
      throwsUnsupportedError,
    );
    expect(snapshot(prefs), before);
  });

  test(
    'duplicate and cross-area identities fail without overwriting records',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = MoodboardRepository(prefs);
      await repo.save(LifeArea.physical, [quote('one')]);
      final before = snapshot(prefs);
      await expectLater(
        repo.save(LifeArea.physical, [quote('one'), quote('one')]),
        throwsStateError,
      );
      await expectLater(
        repo.save(LifeArea.social, [quote('one')]),
        throwsStateError,
      );
      expect(snapshot(prefs), before);
    },
  );

  for (final key in [
    AreaVisionRepository.storageKey,
    ShootingStarWishRepository.storageKey,
    moodboardStorageKey,
  ]) {
    test('failed edit preserves the stored record at $key', () async {
      final prefs = await SharedPreferences.getInstance();
      final visions = AreaVisionRepository(prefs);
      final wish = ShootingStarWishRepository(prefs);
      final moodboard = MoodboardRepository(prefs);
      await visions.setVision(LifeArea.physical, 'Vision');
      await wish.save('Wish');
      await moodboard.save(LifeArea.physical, [quote('quote')]);
      final before = snapshot(prefs);
      final store = SharedPreferencesStorePlatform.instance;
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      SharedPreferencesStorePlatform.instance = _FailingStore(
        before,
        key,
        false,
      );
      final operation = switch (key) {
        AreaVisionRepository.storageKey => visions.clear(),
        ShootingStarWishRepository.storageKey => wish.clear(),
        _ => moodboard.save(LifeArea.physical, []),
      };
      await expectLater(operation, throwsStateError);
      expect(snapshot(prefs), before);
    });
  }

  for (final key in [
    AreaVisionRepository.storageKey,
    ShootingStarWishRepository.storageKey,
    moodboardStorageKey,
    ShootingStarWishRepository.legacyStorageKey,
    '${legacyMoodboardPrefix}physical',
    '${legacyMoodboardPrefix}social',
    localSchemaKey,
    areaContentMigrationJournalKey,
  ]) {
    for (final throwsError in [false, true]) {
      test(
        'area migration resumes after failure at $key (throws=$throwsError)',
        () async {
          final data = legacyData();
          SharedPreferences.setMockInitialValues(data);
          final prefs = await SharedPreferences.getInstance();
          final store = SharedPreferencesStorePlatform.instance;
          addTearDown(() => SharedPreferencesStorePlatform.instance = store);
          SharedPreferencesStorePlatform.instance = _FailingStore(
            data,
            key,
            throwsError,
          );
          await expectLater(migrateLocalData(prefs), throwsStateError);
          expect(jsonDecode(prefs.getString(localSchemaKey)!)['version'], 2);
          final pending = prefs.getString(areaContentMigrationJournalKey);
          await prefs.reload();
          await migrateLocalData(prefs);
          expect(
            jsonDecode(prefs.getString(localSchemaKey)!)['version'],
            currentLocalSchemaVersion,
          );
          expect(
            MoodboardRepository(prefs).getAll(includeDeleted: true),
            hasLength(15),
          );
          expect(prefs.containsKey(areaContentMigrationJournalKey), isFalse);
          if (pending != null) {
            for (final entry
                in (jsonDecode(pending) as Map<String, dynamic>).entries) {
              expect(prefs.getString(entry.key), entry.value);
            }
          }
        },
      );
    }
  }

  test('failed cleanup after schema commit is retried without replaying old values', () async {
    final data = legacyData();
    SharedPreferences.setMockInitialValues(data);
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStorePlatform.instance;
    addTearDown(() => SharedPreferencesStorePlatform.instance = store);
    SharedPreferencesStorePlatform.instance = _FailingStore(
      data,
      areaContentMigrationJournalKey,
      false,
      removeOnly: true,
    );
    await expectLater(migrateLocalData(prefs), throwsStateError);
    expect(jsonDecode(prefs.getString(localSchemaKey)!)['version'], 3);
    await AreaVisionRepository(prefs)
        .setVision(LifeArea.physical, 'A newer edit');
    await migrateLocalData(prefs);
    expect(
      AreaVisionRepository(prefs).getVision(LifeArea.physical),
      'A newer edit',
    );
    expect(prefs.containsKey(areaContentMigrationJournalKey), isFalse);
  });
}
