import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/models/custom_constellation.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const shape = ConstellationShape(
    points: [Offset(0.2, 0.3), Offset(0.5, 0.7), Offset(0.8, 0.1)],
    edges: [(0, 1), (1, 2)],
  );

  test('starts empty when nothing has been saved yet', () async {
    final repo = await StarsShapeRepository.create();

    expect(repo.getAll(), isEmpty);
  });

  test('add() persists name, points, and edges', () async {
    final repo = await StarsShapeRepository.create();

    final created = await repo.add(name: 'My path', shape: shape);

    expect(created.name, 'My path');
    expect(created.shape.points, shape.points);
    expect(created.shape.edges, shape.edges);
  });

  test('getById() finds a saved shape by id, or null if it does not exist', () async {
    final repo = await StarsShapeRepository.create();
    final created = await repo.add(name: 'My path', shape: shape);

    expect(repo.getById(created.id)?.name, 'My path');
    expect(repo.getById(-1), isNull);
  });

  test('data survives reloading the repository from the same storage', () async {
    final repo = await StarsShapeRepository.create();
    await repo.add(name: 'My path', shape: shape);

    final reloaded = await StarsShapeRepository.create();

    expect(reloaded.getAll(), hasLength(1));
    final roundTripped = reloaded.getAll().first;
    expect(roundTripped.name, 'My path');
    expect(roundTripped.shape.points, shape.points);
    expect(roundTripped.shape.edges, shape.edges);
  });

  test('update() replaces name and shape but keeps id and createdAt', () async {
    final repo = await StarsShapeRepository.create();
    final created = await repo.add(name: 'My path', shape: shape);

    const revisedShape = ConstellationShape(
      points: [Offset(0.1, 0.1), Offset(0.9, 0.9)],
      edges: [(0, 1)],
    );
    final updated = await repo.update(
      id: created.id,
      name: 'My revised path',
      shape: revisedShape,
    );

    expect(updated.id, created.id);
    expect(updated.name, 'My revised path');
    expect(updated.shape.points, revisedShape.points);
    expect(updated.createdAt, created.createdAt);
  });

  test('update() persists in place, without moving the shape to the front of the list', () async {
    final repo = await StarsShapeRepository.create();
    final first = await repo.add(name: 'First', shape: shape);
    // Ids are millisecondsSinceEpoch — without this, two adds this close
    // together could mint the same id, which update()'s id-based lookup
    // assumes can't happen (see star_repository_test.dart's own note).
    await Future.delayed(const Duration(milliseconds: 2));
    await repo.add(name: 'Second', shape: shape);

    await repo.update(id: first.id, name: 'First, revised', shape: shape);

    final all = repo.getAll();
    expect(all.map((s) => s.name), ['Second', 'First, revised']);
  });

  test('update() throws for an id that does not exist', () async {
    final repo = await StarsShapeRepository.create();

    expect(
      () => repo.update(id: -1, name: 'Nope', shape: shape),
      throwsStateError,
    );
  });

  test('clear() deletes every custom shape, including from a repository reloaded afterward', () async {
    final repo = await StarsShapeRepository.create();
    await repo.add(name: 'My path', shape: shape);

    await repo.clear();

    expect(repo.getAll(), isEmpty);
    final reloaded = await StarsShapeRepository.create();
    expect(reloaded.getAll(), isEmpty);
  });

  test('StarsShape.fromJson/toJson round-trips points and edges exactly', () {
    final original = StarsShape(
      id: 1,
      name: 'My path',
      shape: shape,
      createdAt: DateTime(2026, 1, 1),
    );

    final roundTripped = StarsShape.fromJson(original.toJson());

    expect(roundTripped, original);
    expect(roundTripped.shape.points, original.shape.points);
    expect(roundTripped.shape.edges, original.shape.edges);
  });
}
