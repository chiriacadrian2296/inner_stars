import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/debug/seed_area_content.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'seeds visions, reflections and a moodboard, once, not spiritual',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('inner_stars_seed');
      addTearDown(() => dir.deleteSync(recursive: true));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path,
          );
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        final visions = await AreaVisionRepository.create();
        final answers = await ReflectionAnswerRepository.create();
        final moodboard = await MoodboardRepository.create();

        Future<void> seed() => seedAreaContent(
          languageCode: 'it',
          areaVisionRepository: visions,
          reflectionAnswerRepository: answers,
          moodboardRepository: moodboard,
        );

        await seed();
        for (final area in LifeArea.values) {
          final seeded = area != LifeArea.spiritual;
          expect(visions.getVision(area).isNotEmpty, seeded, reason: '$area');
          expect(answers.getAnswersForArea(area).length, seeded ? 2 : 0);
          expect(moodboard.getItems(area).length, seeded ? 4 : 0);
        }

        // Running it again changes nothing.
        final before = moodboard.getItems(LifeArea.physical).map((i) => i.id);
        await seed();
        expect(moodboard.getItems(LifeArea.physical).map((i) => i.id), before);
      });
    },
  );
}
