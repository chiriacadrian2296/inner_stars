import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/models/habit.dart';

void main() {
  cycleRepositoryTests();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'add() defaults a pulsar to the middle of the intensity scale',
    () async {
      final repo = await HabitRepository.create();

      final habit = await repo.add(title: 'Stretch', projectId: '1');

      expect(habit.intensity, 3);
    },
  );

  test('delete() tombstones rather than erasing — the pulsar stays in the '
      'sky as a dead star', () async {
    final repo = await HabitRepository.create();
    final habit = await repo.add(title: 'Stretch', projectId: '1');

    final dead = await repo.delete(habit.id);

    expect(dead.dead, isTrue);
    expect(dead.deadDate, isNotNull);
    expect(repo.getAll(), hasLength(1));
    expect(repo.getAllForProject('1'), hasLength(1));
    expect(repo.getActiveForProject('1'), isEmpty);
  });

  test('resurrect() brings back a pulsar with the same id and a clean '
      'history', () async {
    final repo = await HabitRepository.create();
    final completions = await HabitCompletionRepository.create();
    final habit = await repo.add(
      title: 'Stretch',
      projectId: '1',
      intensity: 2,
    );
    await completions.markDone(habit.id);
    await repo.delete(habit.id);

    final revived = await repo.resurrect(
      habit.id,
      title: 'Stretch, properly this time',
      projectId: '1',
      intensity: 4,
      completionRepository: completions,
    );

    expect(revived.id, habit.id);
    expect(revived.dead, isFalse);
    expect(revived.deadDate, isNull);
    expect(revived.title, 'Stretch, properly this time');
    expect(revived.intensity, 4);
    // A reignited pulsar is a new pulsar: its old run doesn't carry over.
    expect(completions.getAllForHabit(habit.id), isEmpty);
  });

  test('a pulsar stored before intensity/dead existed still reads back', () {
    final habit = Habit.fromJson({
      'id': '1',
      'projectId': '2',
      'title': 'Stretch',
      'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      'frequency': 'daily',
      'targetPerPeriod': 1,
    });

    expect(habit.intensity, 3);
    expect(habit.dead, isFalse);
    expect(habit.deadDate, isNull);
  });

  test('toJson/fromJson round-trips a dead pulsar', () {
    final habit = Habit(
      id: '1',
      projectId: '2',
      title: 'Stretch',
      createdAt: DateTime(2024, 1, 1),
      intensity: 5,
      dead: true,
      deadDate: DateTime(2024, 3, 4),
    );

    expect(Habit.fromJson(habit.toJson()), habit);
  });
}

void cycleRepositoryTests() {
  group('cycles', () {
    test(
      'a new pulsar gets the default cycle and starts it on creation',
      () async {
        final repo = await HabitRepository.create();

        final habit = await repo.add(title: 'Stretch', projectId: '1');

        expect(habit.cycleLength, kDefaultCycleLength);
        expect(habit.cycleStart, isNull);
        expect(
          habit.currentCycleStart,
          DateTime(
            habit.createdAt.year,
            habit.createdAt.month,
            habit.createdAt.day,
          ),
        );
      },
    );

    test('a chosen length and reward are stored and read back', () async {
      final repo = await HabitRepository.create();

      await repo.add(
        title: 'Stretch',
        projectId: '1',
        cycleLength: 90,
        intensity: 5,
      );

      final saved = repo.getAll().single;
      expect(saved.cycleLength, 90);
      expect(saved.intensity, 5);
    });

    test(
      'update() keeps the running cycle when it changes other fields',
      () async {
        final repo = await HabitRepository.create();
        final habit = await repo.add(title: 'Stretch', projectId: '1');
        final started = await repo.startNextCycle(
          habit.id,
          start: DateTime(2026, 2, 3, 15),
        );

        final updated = await repo.update(
          id: habit.id,
          title: 'Stretch more',
          projectId: '1',
          cycleLength: 7,
        );

        expect(updated.cycleLength, 7);
        expect(updated.cycleStart, started.cycleStart);
      },
    );

    test(
      'startNextCycle() restarts on a day, optionally changing it',
      () async {
        final repo = await HabitRepository.create();
        final habit = await repo.add(
          title: 'Stretch',
          projectId: '1',
          cycleLength: 30,
          intensity: 2,
        );

        final restarted = await repo.startNextCycle(
          habit.id,
          start: DateTime(2026, 4, 9, 18, 30),
        );
        expect(restarted.currentCycleStart, DateTime(2026, 4, 9));
        expect(restarted.cycleLength, 30);
        expect(restarted.intensity, 2);

        final changed = await repo.startNextCycle(
          habit.id,
          start: DateTime(2026, 5, 1),
          cycleLength: 7,
          intensity: 5,
        );
        expect(changed.cycleLength, 7);
        expect(changed.intensity, 5);
      },
    );

    test('resurrect() begins a fresh cycle today', () async {
      final repo = await HabitRepository.create();
      final completions = await HabitCompletionRepository.create();
      final habit = await repo.add(
        title: 'Stretch',
        projectId: '1',
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.delete(habit.id);

      final back = await repo.resurrect(
        habit.id,
        title: 'Stretch',
        projectId: '1',
        cycleLength: 14,
        completionRepository: completions,
      );

      final now = DateTime.now();
      expect(back.cycleLength, 14);
      expect(back.currentCycleStart, DateTime(now.year, now.month, now.day));
    });
  });
}
