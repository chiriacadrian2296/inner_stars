// Run explicitly: flutter test tool/capture_landing_test.dart
// Captures the current production widgets with isolated demonstration data.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/constellation_screen.dart';
import 'package:inner_stars/screens/new_project_screen.dart';
import 'package:inner_stars/screens/star_reader_screen.dart';
import 'package:inner_stars/settings/settings_controller.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/sky_explorer_view.dart';

void main() {
  for (final lang in ['it', 'en']) {
    testWidgets('capture current landing screens $lang', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        for (final entry in {
          'Instrument Sans': 'InstrumentSans-Variable.ttf',
          'Newsreader': 'Newsreader-Variable.ttf',
          'Gloock': 'Gloock-Regular.ttf',
          'Fragment Mono': 'FragmentMono-Regular.ttf',
        }.entries) {
          await (FontLoader(
            entry.key,
          )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
        }
      });
      // This explicit flutter-test entry lives in tool/ to avoid regenerating
      // marketing assets during the regular test suite.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final projects = ProjectRepository(prefs);
      final stars = StarRepository(prefs);
      final habits = HabitRepository(prefs);
      final completions = HabitCompletionRepository(prefs);
      final shapes = StarsShapeRepository(prefs);
      final visions = AreaVisionRepository(prefs);
      final reflections = ReflectionRepository(prefs);
      final settings = SettingsController(SettingsRepository(prefs));
      settings.tutorialsEnabled = false;
      final it = lang == 'it';
      final shape = await shapes.add(
        name: it ? 'Casa' : 'Home',
        shape: const ConstellationShape(
          points: [
            Offset(.15, .42),
            Offset(.5, .15),
            Offset(.85, .42),
            Offset(.85, .85),
            Offset(.6, .85),
            Offset(.6, .62),
            Offset(.4, .62),
            Offset(.4, .85),
            Offset(.15, .85),
          ],
          edges: [
            (0, 1),
            (1, 2),
            (2, 3),
            (3, 4),
            (4, 5),
            (5, 6),
            (6, 7),
            (7, 8),
            (8, 0),
            (0, 2),
          ],
        ),
      );
      final project = await projects.add(
        name: it ? 'Un progetto mio' : 'A project of my own',
        area: LifeArea.professional,
        iconSlug: 'work',
        starsShapeId: shape.id,
      );
      final first = await stars.add(
        title: it ? 'Ho fatto il primo passo' : 'I took the first step',
        projectId: project.id,
        achievedDate: DateTime(2026, 10, 16),
        intensity: 4,
        iconSlug: 'flag',
        description: it
            ? 'Ho dedicato un’ora a quell’idea che rimandavo. Non era tutto chiaro, ma ho iniziato lo stesso.'
            : 'I spent an hour on the idea I had been putting off. I didn’t have it all figured out, but I started anyway.',
      );
      await stars.add(
        title: it ? 'Ho chiesto un confronto' : 'I asked for feedback',
        projectId: project.id,
        achievedDate: DateTime(2026, 10, 17),
        intensity: 3,
        iconSlug: 'chat',
      );
      await stars.add(
        title: it ? 'Presentare la mia idea' : 'Present my idea',
        projectId: project.id,
        targetDate: DateTime(2026, 11, 1),
        iconSlug: 'lightbulb',
      );
      await habits.add(
        title: it ? 'Un po’ ogni giorno' : 'A little every day',
        projectId: project.id,
      );
      await projects.add(
        name: it ? 'Prendermi cura di me' : 'Taking care of myself',
        area: LifeArea.physical,
        iconSlug: 'favorite',
        starsShapeId: shape.id,
      );
      final output = Directory('landing/src/assets/current')
        ..createSync(recursive: true);
      final key = GlobalKey();
      var generation = 0;
      Future<void> capture(String name, Widget screen) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          StringsScope(
            strings: it ? const StringsIt() : const StringsEn(),
            child: TourScope(
              storage: InMemoryTourStorage(),
              child: MaterialApp(
                key: ValueKey(generation++),
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                home: RepaintBoundary(key: key, child: screen),
              ),
            ),
          ),
        );
        // Pulsars keep animating, so waiting for complete stillness never ends.
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${output.path}/$lang-$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (var mode = 0; mode < 3; mode++) {
        await capture(
          ['areas', 'projects', 'activities'][mode],
          Scaffold(
            body: SkyExplorerView(
              projectRepository: projects,
              starRepository: stars,
              habitRepository: habits,
              habitCompletionRepository: completions,
              starsShapeRepository: shapes,
              areaVisionRepository: visions,
              reflectionAnswerRepository: reflections,
              settings: settings,
              session: SkyExplorerSession()..modeIndex = mode,
              onNavigateTo: (_) {},
            ),
          ),
        );
      }
      await capture(
        'constellation',
        ConstellationScreen(
          project: project,
          starRepository: stars,
          projectRepository: projects,
          habitRepository: habits,
          habitCompletionRepository: completions,
          starsShapeRepository: shapes,
          settings: settings,
        ),
      );
      await capture(
        'reader',
        StarReaderScreen(
          repository: stars,
          initialStars: [first],
          startIndex: 0,
          projectsById: {project.id: project},
          settings: settings,
        ),
      );
      await capture(
        'customize',
        NewProjectScreen(
          projectRepository: projects,
          starsShapeRepository: shapes,
          existingProject: project,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    });
  }
}
