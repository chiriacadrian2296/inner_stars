import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  test(
    'applyRemote writes winners, keeps the remote clock and notifies',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await ReflectionRepository.create();
      final local = await repo.add(
        area: LifeArea.values.first,
        title: 'T',
        body: 'B',
      );
      var notified = 0;
      repo.addListener(() => notified++);

      final newer = {
        ...repo.syncCollection.readAll().single,
        'title': 'Remote',
        'updatedAt': local.updatedAt
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      };
      expect(await repo.applyRemote([newer]), 1);
      expect(notified, 1);
      expect(repo.find(local.id)!.title, 'Remote');
      expect(
        repo.find(local.id)!.updatedAt,
        local.updatedAt.add(const Duration(minutes: 5)),
      );

      // An older remote copy changes nothing and stays silent.
      final older = {
        ...newer,
        'title': 'Old',
        'updatedAt': local.updatedAt.toIso8601String(),
      };
      expect(await repo.applyRemote([older]), 0);
      expect(notified, 1);
      expect(repo.find(local.id)!.title, 'Remote');
    },
  );

  test('a remote tombstone hides the record', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await ReflectionRepository.create();
    final local = await repo.add(
      area: LifeArea.values.first,
      title: 'T',
      body: 'B',
    );
    final dead = {
      ...repo.syncCollection.readAll().single,
      'deleted': true,
      'updatedAt': local.updatedAt
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };
    await repo.applyRemote([dead]);
    expect(repo.find(local.id), isNull);
    expect(repo.getAll(includeDeleted: true), hasLength(1));
  });
}
