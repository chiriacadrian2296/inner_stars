import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts empty when nothing has been saved yet', () async {
    final repo = await ProjectRepository.create();

    expect(repo.getAll(), isEmpty);
  });

  test('add() persists name, area, and iconSlug', () async {
    final repo = await ProjectRepository.create();

    final project = await repo.add(name: 'Build this app', area: LifeArea.professional, iconSlug: 'rocket_launch');

    expect(project.name, 'Build this app');
    expect(project.area, LifeArea.professional);
    expect(project.iconSlug, 'rocket_launch');
  });

  test('add() persists a description, or null if left blank', () async {
    final repo = await ProjectRepository.create();

    final withDescription = await repo.add(
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
      description: 'A personal-growth app',
    );
    final withoutDescription = await repo.add(
      name: 'Bare',
      area: LifeArea.professional,
      iconSlug: 'work',
    );
    final withBlankDescription = await repo.add(
      name: 'Blank',
      area: LifeArea.professional,
      iconSlug: 'badge',
      description: '   ',
    );

    expect(withDescription.description, 'A personal-growth app');
    expect(withoutDescription.description, isNull);
    expect(withBlankDescription.description, isNull);
  });

  test('getProjectsForArea() only returns projects in that area', () async {
    final repo = await ProjectRepository.create();

    await repo.add(name: 'Build this app', area: LifeArea.professional, iconSlug: 'rocket_launch');
    await repo.add(name: 'Find a job', area: LifeArea.professional, iconSlug: 'work');
    await repo.add(name: 'Run a 10k', area: LifeArea.physical, iconSlug: 'fitness_center');

    expect(repo.getProjectsForArea(LifeArea.professional).map((p) => p.name), ['Find a job', 'Build this app']);
    expect(repo.getProjectsForArea(LifeArea.physical).map((p) => p.name), ['Run a 10k']);
    expect(repo.getProjectsForArea(LifeArea.spiritual), isEmpty);
  });

  test('data survives reloading the repository from the same storage', () async {
    final repo = await ProjectRepository.create();
    await repo.add(name: 'Build this app', area: LifeArea.professional, iconSlug: 'rocket_launch');

    final reloaded = await ProjectRepository.create();

    expect(reloaded.getAll(), hasLength(1));
    expect(reloaded.getAll().first.name, 'Build this app');
    expect(reloaded.getAll().first.area, LifeArea.professional);
  });

  test('assignStarsShape() sets the id and persists it', () async {
    final repo = await ProjectRepository.create();
    final project = await repo.add(name: 'Build this app', area: LifeArea.professional, iconSlug: 'rocket_launch');
    expect(project.starsShapeId, isNull);

    final updated = await repo.assignStarsShape(
      projectId: project.id,
      starsShapeId: 42,
    );

    expect(updated.starsShapeId, 42);
    expect(repo.getAll().single.starsShapeId, 42);
  });

  test('assignStarsShape() keeps the project in the same position in the list', () async {
    final repo = await ProjectRepository.create();
    final first = await repo.add(name: 'First', area: LifeArea.professional, iconSlug: 'rocket_launch');
    await repo.add(name: 'Second', area: LifeArea.professional, iconSlug: 'work');

    await repo.assignStarsShape(projectId: first.id, starsShapeId: 1);

    expect(repo.getAll().map((p) => p.name), ['Second', 'First']);
  });

  test('assignStarsShape() throws for an id that does not exist', () async {
    final repo = await ProjectRepository.create();

    expect(
      () => repo.assignStarsShape(projectId: -1, starsShapeId: 1),
      throwsStateError,
    );
  });

  test('clear() deletes every project, including from a repository reloaded afterward', () async {
    final repo = await ProjectRepository.create();
    await repo.add(name: 'Build this app', area: LifeArea.professional, iconSlug: 'rocket_launch');

    await repo.clear();

    expect(repo.getAll(), isEmpty);
    final reloaded = await ProjectRepository.create();
    expect(reloaded.getAll(), isEmpty);
  });
}
