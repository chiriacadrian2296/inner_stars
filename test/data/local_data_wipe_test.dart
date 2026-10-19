import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/local_data_wipe.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/data/shooting_star_wish_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  test(
    'wipes the content for real, keeps settings and markers, tells listeners',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.locale': 'it',
        'local-data-schema': '{"version":3}',
        'sync.settings-meta': '{}',
        'sync.uid-1.stars.pull': '2026-10-19T12:00:00.000Z',
        'reflection-answers-v1': '{}',
      });
      final prefs = await SharedPreferences.getInstance();
      final stars = await StarRepository.create();
      final projects = await ProjectRepository.create();
      final reflections = await ReflectionRepository.create();
      final visions = await AreaVisionRepository.create();
      final wish = await ShootingStarWishRepository.create();
      final moodboard = await MoodboardRepository.create();

      final area = LifeArea.values.first;
      final project = await projects.add(
        name: 'Project',
        area: area,
        iconSlug: 'star',
      );
      await stars.add(title: 'Star', projectId: project.id);
      await reflections.add(area: area, title: 'T', body: 'B');
      await visions.setVision(area, 'A vision');
      await wish.save('A wish');
      await moodboard.save(area, [
        const MoodboardItem(id: 'q1', kind: MoodboardKind.quote, content: 'Hi'),
      ]);
      expect(stars.getAll(), hasLength(1));
      expect(wish.wish, 'A wish');

      var notified = 0;
      stars.addListener(() => notified++);
      projects.addListener(() => notified++);

      await wipeLocalData(
        prefs: prefs,
        stars: stars,
        moodboard: moodboard,
        repositories: [stars, projects, reflections, visions, wish, moodboard],
      );

      // Gone outright: not even deletion records are left to sync.
      expect(stars.getAll(includeDeleted: true), isEmpty);
      expect(projects.getAll(includeDeleted: true), isEmpty);
      expect(reflections.getAll(includeDeleted: true), isEmpty);
      expect(visions.getAll(includeDeleted: true), isEmpty);
      expect(wish.getRecord(includeDeleted: true), isNull);
      expect(moodboard.getAll(includeDeleted: true), isEmpty);
      expect(prefs.containsKey('reflection-answers-v1'), isFalse);

      // Settings stay; so does the settings' own bookkeeping.
      expect(prefs.getString('settings.locale'), 'it');
      expect(prefs.getString('local-data-schema'), '{"version":3}');
      expect(prefs.containsKey('sync.settings-meta'), isTrue);
      expect(notified, 2);
    },
  );
}
