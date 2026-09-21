import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/star_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts empty when nothing has been saved yet', () async {
    final repo = await StarRepository.create();

    expect(repo.getAll(), isEmpty);
  });

  test(
    'add() with an achievedDate logs a victory and assigns a number',
    () async {
      final repo = await StarRepository.create();

      final first = await repo.add(
        title: 'First step',
        projectId: 1,
        achievedDate: DateTime(2024, 1, 1),
        intensity: 3,
      );
      final second = await repo.add(
        title: 'Second step',
        projectId: 1,
        achievedDate: DateTime(2024, 1, 2),
        intensity: 3,
      );

      expect(first.number, 1);
      expect(second.number, 2);
      expect(first.isLit, isTrue);
      expect(repo.getAll().map((s) => s.title), ['Second step', 'First step']);
    },
  );

  test(
    'add() without an achievedDate creates an unlit goal with no number',
    () async {
      final repo = await StarRepository.create();

      final goal = await repo.add(title: 'Someday', projectId: 1);

      expect(goal.isUnlit, isTrue);
      expect(goal.number, isNull);
      expect(goal.achievedDate, isNull);
    },
  );

  test('add() assigns a per-project slotSequence, starting at 1', () async {
    final repo = await StarRepository.create();

    final a = await repo.add(title: 'A', projectId: 1);
    final b = await repo.add(title: 'B', projectId: 1);
    final c = await repo.add(title: 'C', projectId: 2);

    expect(a.slotSequence, 1);
    expect(b.slotSequence, 2);
    expect(c.slotSequence, 1);
  });

  test('blank description is stored as null, not an empty string', () async {
    final repo = await StarRepository.create();

    final star = await repo.add(
      title: 'A star',
      description: '   ',
      projectId: 1,
      achievedDate: DateTime.now(),
      intensity: 3,
    );

    expect(star.description, isNull);
  });

  test(
    'data survives reloading the repository from the same storage',
    () async {
      final repo = await StarRepository.create();
      await repo.add(
        title: 'A star',
        description: 'Some details',
        projectId: 1,
        achievedDate: DateTime.now(),
        intensity: 4,
      );

      final reloaded = await StarRepository.create();

      expect(reloaded.getAll(), hasLength(1));
      expect(reloaded.getAll().first.title, 'A star');
      expect(reloaded.getAll().first.description, 'Some details');
      expect(reloaded.getAll().first.intensity, 4);
    },
  );

  test('update() changes title/description/intensity but keeps id, slotSequence, and number', () async {
    final repo = await StarRepository.create();
    final original = await repo.add(
      title: 'Original',
      description: 'Original details',
      projectId: 1,
      achievedDate: DateTime(2024, 1, 1),
      intensity: 2,
    );

    final updated = await repo.update(
      id: original.id,
      title: 'Updated',
      description: '',
      projectId: 1,
      achievedDate: original.achievedDate,
      intensity: 5,
    );

    expect(updated.id, original.id);
    expect(updated.slotSequence, original.slotSequence);
    expect(updated.number, original.number);
    expect(updated.title, 'Updated');
    expect(updated.description, isNull);
    expect(updated.intensity, 5);
    expect(repo.getAll().single.title, 'Updated');
  });

  test(
    'update() assigns a fresh number when it first achieves a goal',
    () async {
      final repo = await StarRepository.create();
      await repo.add(
        title: 'Already a victory',
        projectId: 1,
        achievedDate: DateTime.now(),
        intensity: 3,
      );
      final goal = await repo.add(title: 'A goal', projectId: 1);

      final achieved = await repo.update(
        id: goal.id,
        title: goal.title,
        projectId: goal.projectId,
        achievedDate: DateTime.now(),
        intensity: 4,
      );

      expect(achieved.number, 2);
      expect(achieved.slotSequence, goal.slotSequence);
    },
  );

  test('update() clears the number when it un-achieves a star', () async {
    final repo = await StarRepository.create();
    final star = await repo.add(
      title: 'A victory',
      projectId: 1,
      achievedDate: DateTime.now(),
      intensity: 3,
    );

    final unachieved = await repo.update(
      id: star.id,
      title: star.title,
      projectId: star.projectId,
    );

    expect(unachieved.achievedDate, isNull);
    expect(unachieved.intensity, isNull);
    expect(unachieved.number, isNull);
  });

  test(
    'update() never changes slotSequence, even across a project reassignment',
    () async {
      final repo = await StarRepository.create();
      final original = await repo.add(title: 'A star', projectId: 1);

      final updated = await repo.update(
        id: original.id,
        title: original.title,
        projectId: 2,
      );

      expect(updated.projectId, 2);
      expect(updated.slotSequence, original.slotSequence);
      expect(repo.getAllForProject(1), isEmpty);
      expect(repo.getAllForProject(2).map((s) => s.id), [original.id]);
    },
  );

  test('update() throws for an id that does not exist', () async {
    final repo = await StarRepository.create();

    expect(
      () => repo.update(id: 999, title: 'Nope', projectId: 1),
      throwsStateError,
    );
  });

  test('getAllForProject() returns only that project\'s stars, ordered by slotSequence', () async {
    final repo = await StarRepository.create();

    await repo.add(title: 'Project 1, star A', projectId: 1);
    await repo.add(title: 'Project 2, star A', projectId: 2);
    await repo.add(title: 'Project 1, star B', projectId: 1);

    expect(repo.getAllForProject(1).map((s) => s.title), [
      'Project 1, star A',
      'Project 1, star B',
    ]);
    expect(repo.getAllForProject(2).map((s) => s.title), ['Project 2, star A']);
    expect(repo.getAllForProject(3), isEmpty);
  });

  test('markAchieved() lights up a goal and assigns a number', () async {
    final repo = await StarRepository.create();
    final goal = await repo.add(title: 'A goal', projectId: 1);

    final achieved = await repo.markAchieved(goal.id, intensity: 4);

    expect(achieved.isLit, isTrue);
    expect(achieved.intensity, 4);
    expect(achieved.number, 1);
    expect(achieved.slotSequence, goal.slotSequence);
  });

  test('markNotAchieved() turns a victory back into an unlit goal', () async {
    final repo = await StarRepository.create();
    final star = await repo.add(
      title: 'A victory',
      projectId: 1,
      achievedDate: DateTime.now(),
      intensity: 3,
    );

    final reverted = await repo.markNotAchieved(star.id);

    expect(reverted.isUnlit, isTrue);
    expect(reverted.number, isNull);
    expect(reverted.intensity, isNull);
  });

  test(
    'delete() tombstones a star instead of removing it, keeping its slot',
    () async {
      final repo = await StarRepository.create();
      final keep = await repo.add(title: 'Keep me', projectId: 1);
      // Star ids are millisecondsSinceEpoch — without this, two adds this
      // close together could mint the same id, which the id-based lookups
      // below assume can't happen (see debug/seed_data.dart's own note).
      await Future.delayed(const Duration(milliseconds: 2));
      final remove = await repo.add(title: 'Remove me', projectId: 1);

      final deleted = await repo.delete(remove.id);

      expect(deleted.dead, isTrue);
      expect(deleted.deadDate, isNotNull);
      expect(repo.getAllForProject(1).map((s) => s.id), [keep.id, remove.id]);
      expect(
        repo.getAllForProject(1).firstWhere((s) => s.id == remove.id).dead,
        isTrue,
      );

      final reloaded = await StarRepository.create();
      expect(reloaded.getAllForProject(1).map((s) => s.id), [
        keep.id,
        remove.id,
      ]);
    },
  );

  test('resurrect() revives a dead star with new content, same id and slotSequence', () async {
    final repo = await StarRepository.create();
    final star = await repo.add(title: 'Original', projectId: 1);
    await repo.delete(star.id);

    final resurrected = await repo.resurrect(
      star.id,
      title: 'Reborn',
      projectId: 1,
      achievedDate: DateTime.now(),
      intensity: 5,
    );

    expect(resurrected.id, star.id);
    expect(resurrected.slotSequence, star.slotSequence);
    expect(resurrected.dead, isFalse);
    expect(resurrected.deadDate, isNull);
    expect(resurrected.title, 'Reborn');
    expect(resurrected.isLit, isTrue);
    expect(resurrected.number, 1);
  });

  test('clear() deletes every star, including from a repository reloaded afterward', () async {
    final repo = await StarRepository.create();
    await repo.add(title: 'A star', projectId: 1);

    await repo.clear();

    expect(repo.getAll(), isEmpty);
    final reloaded = await StarRepository.create();
    expect(reloaded.getAll(), isEmpty);
  });

  test('add() with an explicit slotSequence lands on exactly that slot — how '
      'a nascent star gets configured', () async {
    final repo = await StarRepository.create();
    await repo.add(title: 'First', projectId: 1);

    final placed = await repo.add(
      title: 'Fourth slot',
      projectId: 1,
      slotSequence: 4,
    );

    expect(placed.slotSequence, 4);
    // Slots 2 and 3 stay free, so their nascent stars are still there to be
    // configured later; the next unplaced star appends past the highest.
    final next = await repo.add(title: 'Next', projectId: 1);
    expect(next.slotSequence, 5);
  });

  test('add() falls back to appending when the requested slot is already '
      'taken', () async {
    final repo = await StarRepository.create();
    final first = await repo.add(title: 'First', projectId: 1);

    final second = await repo.add(
      title: 'Second',
      projectId: 1,
      slotSequence: first.slotSequence,
    );

    expect(second.slotSequence, first.slotSequence + 1);
  });
}
