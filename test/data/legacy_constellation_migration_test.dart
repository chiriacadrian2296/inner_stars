import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/constellation_presets.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/legacy_constellation_migration.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('backfills a project with no starsShapeId, from its icon\'s own preset', () async {
    final projectRepository = await ProjectRepository.create();
    final starsShapeRepository = await StarsShapeRepository.create();
    await projectRepository.add(
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
    );

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );

    final migrated = projectRepository.getAll().single;
    expect(migrated.starsShapeId, isNotNull);
    final shape = starsShapeRepository.getById(migrated.starsShapeId!);
    expect(shape, isNotNull);
    expect(shape!.presetId, 'rocket');
    expect(shape.shape.points, presetById('rocket')!.shape.points);
    expect(shape.shape.edges, presetById('rocket')!.shape.edges);
  });

  test('leaves a project that already has a starsShapeId untouched', () async {
    final projectRepository = await ProjectRepository.create();
    final starsShapeRepository = await StarsShapeRepository.create();
    final custom = await starsShapeRepository.add(
      name: 'My own shape',
      shape: presetById('rocket')!.shape,
    );
    final project = await projectRepository.add(
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
      starsShapeId: custom.id,
    );

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );

    expect(projectRepository.getAll().single.starsShapeId, custom.id);
    expect(starsShapeRepository.getAll(), hasLength(1));
    expect(project.starsShapeId, custom.id);
  });

  test('running it twice does not create duplicate shapes', () async {
    final projectRepository = await ProjectRepository.create();
    final starsShapeRepository = await StarsShapeRepository.create();
    await projectRepository.add(
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
    );

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );
    final idAfterFirstRun = projectRepository.getAll().single.starsShapeId;

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );

    expect(projectRepository.getAll().single.starsShapeId, idAfterFirstRun);
    expect(starsShapeRepository.getAll(), hasLength(1));
  });

  test('two projects sharing an icon share one materialized preset copy', () async {
    final projectRepository = await ProjectRepository.create();
    final starsShapeRepository = await StarsShapeRepository.create();
    await projectRepository.add(
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
    );
    await projectRepository.add(
      name: 'Ship the sequel',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
    );

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );

    final ids = projectRepository
        .getAll()
        .map((p) => p.starsShapeId)
        .toSet();
    expect(ids, hasLength(1));
    expect(starsShapeRepository.getAll(), hasLength(1));
  });

  test('a project whose iconSlug is not in the catalogue still gets a shape', () async {
    final projectRepository = await ProjectRepository.create();
    final starsShapeRepository = await StarsShapeRepository.create();
    await projectRepository.add(
      name: 'Mystery project',
      area: LifeArea.professional,
      iconSlug: 'not_a_real_slug',
    );

    await backfillMissingConstellations(
      projectRepository: projectRepository,
      starsShapeRepository: starsShapeRepository,
    );

    final migrated = projectRepository.getAll().single;
    expect(migrated.starsShapeId, isNotNull);
    // Deterministic, not arbitrary: the same retired slug always lands on
    // the same fallback shape, so re-running never reshuffles anything.
    expect(
      starsShapeRepository.getById(migrated.starsShapeId!)!.presetId,
      presetForIconSlug('not_a_real_slug').id,
    );
  });
}
