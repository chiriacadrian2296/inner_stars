import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/screens/constellation_screen.dart';
import 'package:inner_stars/screens/star_reader_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';

class _Data {
  _Data(SharedPreferences prefs)
    : projects = ProjectRepository(prefs),
      stars = StarRepository(prefs),
      habits = HabitRepository(prefs),
      completions = HabitCompletionRepository(prefs),
      shapes = StarsShapeRepository(prefs);
  final ProjectRepository projects;
  final StarRepository stars;
  final HabitRepository habits;
  final HabitCompletionRepository completions;
  final StarsShapeRepository shapes;
  late Project project;
  late Star first;
  late Star second;

  static Future<_Data> create() async {
    SharedPreferences.setMockInitialValues({});
    final data = _Data(await SharedPreferences.getInstance());
    final shape = await data.shapes.add(
      name: 'Forma',
      shape: const ConstellationShape(
        points: [Offset(0.2, 0.2), Offset(0.8, 0.8)],
        edges: [(0, 1)],
      ),
    );
    data.project = await data.projects.add(
      name: 'Progetto',
      area: LifeArea.values.first,
      iconSlug: '',
      starsShapeId: shape.id,
    );
    data.first = await data.stars.add(
      title: 'Prima',
      projectId: data.project.id,
      slotSequence: 1,
    );
    data.second = await data.stars.add(
      title: 'Seconda',
      projectId: data.project.id,
      slotSequence: 2,
    );
    return data;
  }

  Widget host(Widget child) => StringsScope(
    strings: const StringsIt(),
    child: TourScope(
      child: MaterialApp(theme: buildAppTheme(), home: child),
    ),
  );
}

void main() {
  testWidgets(
    'open project receives cloud titles and archives without moving its camera',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = await _Data.create();
      await tester.pumpWidget(
        data.host(
          ConstellationScreen(
            project: data.project,
            starRepository: data.stars,
            projectRepository: data.projects,
            habitRepository: data.habits,
            habitCompletionRepository: data.completions,
            starsShapeRepository: data.shapes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      ConstellationMapView map() =>
          tester.widget(find.byType(ConstellationMapView));
      final camera = map().transformation.value.storage.toList();
      await data.stars.applyRemote([
        {
          ...data.first.toJson(),
          'title': 'Prima Cloud',
          'updatedAt': '2027-01-01T00:00:00.000Z',
        },
      ]);
      await tester.pumpAndSettle();
      expect(
        map().stars.where((s) => s.entityId == data.first.id).single.label,
        'Prima Cloud',
      );
      expect(map().transformation.value.storage, camera);
      await data.stars.applyRemote([
        {
          ...data.first.toJson(),
          'title': 'Prima Cloud',
          'dead': true,
          'deadDate': '2027-01-01T00:00:01.000Z',
          'updatedAt': '2027-01-01T00:00:01.000Z',
        },
      ]);
      await data.projects.applyRemote([
        {
          ...data.project.toJson(),
          'name': 'Progetto Cloud',
          'updatedAt': '2027-01-01T00:00:01.000Z',
        },
      ]);
      await tester.pumpAndSettle();
      expect(
        map().stars.where((s) => s.entityId == data.first.id).single.kind,
        StarKind.dead,
      );
      expect(map().transformation.value.storage, camera);
      expect(find.text('Progetto Cloud'), findsWidgets);
    },
  );

  for (final scoped in [false, true]) {
    testWidgets(
      'open reader updates its current item from cloud (scoped: $scoped)',
      (tester) async {
        final data = await _Data.create();
        await tester.pumpWidget(
          data.host(
            StarReaderScreen(
              repository: data.stars,
              initialStars: [data.first, data.second],
              startIndex: 1,
              projectsById: {data.project.id: data.project},
              projectRepository: data.projects,
              refreshStars: scoped
                  ? () => data.stars.getAllForProject(data.project.id)
                  : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await data.stars.applyRemote([
          {
            ...data.second.toJson(),
            'title': 'Seconda Cloud',
            'updatedAt': '2027-01-01T00:00:00.000Z',
          },
        ]);
        await data.projects.applyRemote([
          {
            ...data.project.toJson(),
            'name': 'Progetto Cloud',
            'updatedAt': '2027-01-01T00:00:00.000Z',
          },
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Seconda Cloud'), findsWidgets);
        expect(find.text('Progetto Cloud'), findsWidgets);
        expect(find.text('Prima'), findsNothing);
      },
    );
  }
}
