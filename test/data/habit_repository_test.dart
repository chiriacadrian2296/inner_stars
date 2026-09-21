import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/models/habit.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add() defaults a pulsar to the middle of the intensity scale', () async {
    final repo = await HabitRepository.create();

    final habit = await repo.add(title: 'Stretch', projectId: 1);

    expect(habit.intensity, 3);
  });

  test('delete() tombstones rather than erasing — the pulsar stays in the '
      'sky as a dead star', () async {
    final repo = await HabitRepository.create();
    final habit = await repo.add(title: 'Stretch', projectId: 1);

    final dead = await repo.delete(habit.id);

    expect(dead.dead, isTrue);
    expect(dead.deadDate, isNotNull);
    expect(repo.getAll(), hasLength(1));
    expect(repo.getAllForProject(1), hasLength(1));
    expect(repo.getActiveForProject(1), isEmpty);
  });

  test('resurrect() brings back a pulsar with the same id and a clean '
      'history', () async {
    final repo = await HabitRepository.create();
    final completions = await HabitCompletionRepository.create();
    final habit = await repo.add(
      title: 'Stretch',
      projectId: 1,
      intensity: 2,
    );
    await completions.markDone(habit.id);
    await repo.delete(habit.id);

    final revived = await repo.resurrect(
      habit.id,
      title: 'Stretch, properly this time',
      projectId: 1,
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
      'id': 1,
      'projectId': 2,
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
      id: 1,
      projectId: 2,
      title: 'Stretch',
      createdAt: DateTime(2024, 1, 1),
      intensity: 5,
      dead: true,
      deadDate: DateTime(2024, 3, 4),
    );

    expect(Habit.fromJson(habit.toJson()), habit);
  });
}
