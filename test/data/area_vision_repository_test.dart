import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getVision() is blank for an area that has never been set', () async {
    final repo = await AreaVisionRepository.create();

    expect(repo.getVision(LifeArea.physical), isEmpty);
  });

  test('setVision() persists and getVision() reads it back', () async {
    final repo = await AreaVisionRepository.create();

    await repo.setVision(LifeArea.physical, 'Strong and healthy.');

    expect(repo.getVision(LifeArea.physical), 'Strong and healthy.');
  });

  test('each area keeps its own vision independently', () async {
    final repo = await AreaVisionRepository.create();

    await repo.setVision(LifeArea.physical, 'Physical vision');
    await repo.setVision(LifeArea.financial, 'Financial vision');

    expect(repo.getVision(LifeArea.physical), 'Physical vision');
    expect(repo.getVision(LifeArea.financial), 'Financial vision');
    expect(repo.getVision(LifeArea.social), isEmpty);
  });

  test('setVision() trims whitespace', () async {
    final repo = await AreaVisionRepository.create();

    await repo.setVision(LifeArea.social, '  Deep friendships.  ');

    expect(repo.getVision(LifeArea.social), 'Deep friendships.');
  });

  test(
    'setVision() with a blank string clears the entry rather than storing it',
    () async {
      final repo = await AreaVisionRepository.create();
      await repo.setVision(LifeArea.spiritual, 'Something');

      await repo.setVision(LifeArea.spiritual, '   ');

      expect(repo.getVision(LifeArea.spiritual), isEmpty);
    },
  );

  test('clear() removes every saved vision', () async {
    final repo = await AreaVisionRepository.create();
    await repo.setVision(LifeArea.physical, 'A');
    await repo.setVision(LifeArea.social, 'B');

    await repo.clear();

    expect(repo.getVision(LifeArea.physical), isEmpty);
    expect(repo.getVision(LifeArea.social), isEmpty);
  });

  test(
    'a vision persists across repository instances (same storage)',
    () async {
      final first = await AreaVisionRepository.create();
      await first.setVision(LifeArea.professional, 'Meaningful work.');

      final second = await AreaVisionRepository.create();

      expect(second.getVision(LifeArea.professional), 'Meaningful work.');
    },
  );
}
