import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/habit_cycle_repository.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/habit_cycle.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - offset);
}

Habit _habit({int cycleLength = 3, int intensity = 4, DateTime? cycleStart}) =>
    Habit(
      id: 1,
      projectId: 1,
      title: 'Walk',
      createdAt: _day(20),
      cycleLength: cycleLength,
      intensity: intensity,
      cycleStart: cycleStart,
    );

List<HabitCompletion> _done(Iterable<int> offsets, {int habitId = 1}) => [
  for (final offset in offsets)
    HabitCompletion(id: offset + 1, habitId: habitId, date: _day(offset)),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'sync() records a cycle once its length in distinct days is reached',
    () async {
      final repo = await HabitCycleRepository.create();
      final habit = _habit();

      expect(await repo.sync(habit, _done([3, 2])), isNull);
      expect(repo.getAll(), isEmpty);

      final cycle = await repo.sync(habit, _done([3, 2, 1]));

      expect(cycle, isNotNull);
      expect(cycle!.length, 3);
      expect(cycle.intensity, 4);
      expect(cycle.completedDate, _day(1));
      expect(cycle.resolved, isFalse);
      expect(repo.pendingFor(1)?.id, cycle.id);
    },
  );

  test('several check-ins on one day count as a single day', () async {
    final repo = await HabitCycleRepository.create();
    final completions = [
      ..._done([2, 1]),
      ..._done([1]),
    ];

    expect(await repo.sync(_habit(), completions), isNull);
  });

  test('sync() never records the same cycle twice', () async {
    final repo = await HabitCycleRepository.create();
    final habit = _habit();

    await repo.sync(habit, _done([3, 2, 1]));
    final again = await repo.sync(habit, _done([3, 2, 1, 0]));

    expect(again, isNull);
    expect(repo.getAll(), hasLength(1));
  });

  test(
    'undoing the check-in that finished it takes an unresolved cycle back',
    () async {
      final repo = await HabitCycleRepository.create();
      final habit = _habit();
      await repo.sync(habit, _done([3, 2, 1]));

      await repo.sync(habit, _done([3, 2]));

      expect(repo.getAll(), isEmpty);
    },
  );

  test('a cycle already reflected on is never taken back', () async {
    final repo = await HabitCycleRepository.create();
    final habit = _habit();
    final cycle = (await repo.sync(habit, _done([3, 2, 1])))!;
    await repo.resolve(cycle.id, whatHelped: '  routine  ');

    await repo.sync(habit, _done([3, 2]));

    final saved = repo.getAll().single;
    expect(saved.resolved, isTrue);
    expect(saved.whatHelped, 'routine');
    expect(saved.whatWasHard, isNull);
    expect(repo.pendingFor(1), isNull);
  });

  test('days before the cycle start do not count', () async {
    final repo = await HabitCycleRepository.create();
    final habit = _habit(cycleStart: _day(1));

    expect(await repo.sync(habit, _done([5, 4, 3, 2, 1])), isNull);
    expect(await repo.sync(habit, _done([5, 4, 3, 1, 0])), isNull);
  });

  test('a lowered reward does not rewrite an earned cycle', () async {
    final repo = await HabitCycleRepository.create();
    final habit = _habit(intensity: 5);
    await repo.sync(habit, _done([3, 2, 1]));

    await repo.sync(habit.copyWith(intensity: 1), _done([3, 2, 1]));

    expect(repo.getAll().single.intensity, 5);
  });

  test('a dead pulsar earns nothing new', () async {
    final repo = await HabitCycleRepository.create();

    final cycle = await repo.sync(
      _habit().copyWith(dead: true),
      _done([3, 2, 1]),
    );

    expect(cycle, isNull);
  });

  test('deleteAllForHabits() removes only those habits\' cycles', () async {
    final repo = await HabitCycleRepository.create();
    HabitCycle cycle(int id, int habitId) => HabitCycle(
      id: id,
      habitId: habitId,
      startDate: _day(5),
      completedDate: _day(1),
      length: 3,
      intensity: 2,
    );
    await repo.addMany([cycle(1, 1), cycle(2, 2), cycle(3, 1)]);

    await repo.deleteAllForHabits([1]);

    expect(repo.getAll().map((c) => c.id), [2]);
  });
}
