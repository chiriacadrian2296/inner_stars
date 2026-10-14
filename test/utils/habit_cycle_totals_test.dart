import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_cycle.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/utils/project_card_info.dart';
import 'package:inner_stars/utils/star_stats.dart';

HabitCycle _cycle(int day, int intensity, {int habitId = 1}) => HabitCycle(
  id: day * 10 + intensity + habitId * 1000,
  habitId: habitId,
  startDate: DateTime(2026, 1, 1),
  completedDate: DateTime(2026, 2, day, 18, 30),
  length: 7,
  intensity: intensity,
);

void main() {
  group('pulsar cycles in the day totals', () {
    test('a cycle lights the day its goal was reached', () {
      final cycles = [_cycle(3, 4), _cycle(3, 2), _cycle(9, 5)];

      expect(cycleIntensityByDay(cycles), {
        DateTime(2026, 2, 3): 6,
        DateTime(2026, 2, 9): 5,
      });
      expect(cycleCountsByDay(cycles), {
        DateTime(2026, 2, 3): 2,
        DateTime(2026, 2, 9): 1,
      });
    });

    test("day totals add up with the stars' own", () {
      final merged = addDayTotals(
        {DateTime(2026, 2, 3): 3, DateTime(2026, 2, 4): 1},
        {DateTime(2026, 2, 3): 6},
      );

      expect(merged, {DateTime(2026, 2, 3): 9, DateTime(2026, 2, 4): 1});
    });

    test('the total can be limited to some pulsars', () {
      final cycles = [_cycle(3, 4), _cycle(9, 5)];

      expect(cycleIntensityTotal(cycles), 9);
      expect(cycleIntensityTotal(cycles, habitIds: {2}), 0);
    });
  });

  test('completed cycles add their reward to a card\'s intensity total', () {
    final created = DateTime(2026, 1, 1);
    final walk = Habit(id: 7, projectId: 1, title: 'Walk', createdAt: created);
    Star victory(int intensity) => Star(
      id: intensity,
      slotSequence: intensity,
      projectId: 1,
      title: 'Win',
      createdAt: created,
      achievedDate: created,
      intensity: intensity,
    );

    final badges = areaCardBadges(
      constellationCount: 1,
      stars: [victory(2), victory(3)],
      habits: [walk],
      emptySlots: 0,
      colors: AppColors.dark,
      strings: const StringsIt(),
      // The second cycle belongs to a pulsar of another area: left out.
      cycles: [_cycle(3, 5, habitId: 7), _cycle(4, 4, habitId: 8)],
    );

    expect(badges.intensity!.value, '10');
  });
}
