import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/data/shooting_star_wish_repository.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/sync/merge.dart';

String later(Object iso, [int minutes = 5]) =>
    DateTime.parse(iso as String)
        .add(Duration(minutes: minutes))
        .toIso8601String();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'visions: exported with an id, remote winner stored under its key',
    () async {
      final repo = await AreaVisionRepository.create();
      final area = LifeArea.values.first;
      await repo.setVision(area, 'Mine');
      var notified = 0;
      repo.addListener(() => notified++);

      final exported = repo.syncCollection.readAll().single;
      expect(exported['id'], area.name);
      expect(exported['value'], 'Mine');

      await repo.applyRemote([
        {
          ...exported,
          'value': 'Theirs',
          'updatedAt': later(exported['updatedAt']),
        },
      ]);
      expect(repo.getVision(area), 'Theirs');
      expect(notified, 1);
      // Stored shape is unchanged: no id inside the keyed record.
      final raw = (await SharedPreferences.getInstance()).getString(
        'area-visions',
      )!;
      expect(raw.contains('"id"'), isFalse);
    },
  );

  test(
    'visions: a legacy string value is exported as the oldest record',
    () async {
      SharedPreferences.setMockInitialValues({
        'area-visions': '{"${LifeArea.values.first.name}":"old text"}',
      });
      final repo = await AreaVisionRepository.create();
      final exported = repo.syncCollection.readAll().single;
      expect(exported['value'], 'old text');
      expect(
        DateTime.parse(exported['updatedAt'] as String).millisecondsSinceEpoch,
        0,
      );
    },
  );

  test('wish: single record syncs and a remote tombstone clears it', () async {
    final repo = await ShootingStarWishRepository.create();
    await repo.save('Wish');
    final exported = repo.syncCollection.readAll().single;
    expect(exported['id'], 'current');
    await repo.applyRemote([
      {...exported, 'deleted': true, 'updatedAt': later(exported['updatedAt'])},
    ]);
    expect(repo.wish, isNull);
    // Other ids are ignored.
    expect(
      await repo.applyRemote([
        {
          ...exported,
          'id': 'other',
          'updatedAt': later(exported['updatedAt'], 99),
        },
      ]),
      0,
    );
  });

  test('moodboard: remote item arrives, keeps its own id field', () async {
    final repo = await MoodboardRepository.create();
    final area = LifeArea.values.first;
    await repo.save(area, [
      const MoodboardItem(id: 'a', kind: MoodboardKind.quote, content: 'Hi'),
    ]);
    final exported = repo.syncCollection.readAll().single;
    final remoteItem = <String, dynamic>{
      ...exported,
      'id': 'b',
      'content': 'From another device',
      'position': 1,
    };
    final changed = await repo.applyRemote([remoteItem]);
    expect(changed, 1);
    final contents = repo.getAll().map((i) => i.content).toSet();
    expect(contents, {'Hi', 'From another device'});
    // Merge is stable afterwards.
    final merge = mergeCollections(repo.syncCollection.readAll(), [
      exported,
      remoteItem,
    ]);
    expect(merge.applyLocally, isEmpty);
    expect(merge.pushRemotely, isEmpty);
  });
}
