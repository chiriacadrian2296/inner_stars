import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_cycle_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all six repositories create distinct UUID v4 IDs across rapid writes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final projects = ProjectRepository(prefs);
      final stars = StarRepository(prefs);
      final habits = HabitRepository(prefs);
      final completions = HabitCompletionRepository(prefs);
      final cycles = HabitCycleRepository(prefs);
      final shapes = StarsShapeRepository(prefs);
      final ids = <String>[];
      for (var i = 0; i < 20; i++) {
        final shape = await shapes.add(
          name: 'Shape $i',
          shape: const ConstellationShape(points: [], edges: []),
        );
        final project = await projects.add(
          name: 'Project $i',
          area: LifeArea.personal,
          iconSlug: '',
          starsShapeId: shape.id,
        );
        final star = await stars.add(title: 'Goal $i', projectId: project.id);
        final habit = await habits.add(
          title: 'Habit $i',
          projectId: project.id,
          cycleLength: 1,
        );
        await completions.markDone(habit.id);
        final completion = completions.getAllForHabit(habit.id).single;
        final cycle = await cycles.sync(habit, [completion]);
        ids.addAll([
          shape.id,
          project.id,
          star.id,
          habit.id,
          completion.id,
          cycle!.id,
        ]);
      }
      expect(ids, hasLength(120));
      expect(ids.toSet(), hasLength(120));
      for (final id in ids) {
        expect(
          id,
          matches(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        );
      }
    },
  );

  test(
    'undo removes the latest check-in by time rather than UUID sorting',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final day = DateTime(2026, 10, 19);
      final older = HabitCompletion(
        id: 'ffffffff-ffff-4fff-bfff-ffffffffffff',
        habitId: 'habit',
        date: day,
        createdAt: day.add(const Duration(hours: 8)),
      );
      final newer = HabitCompletion(
        id: '00000000-0000-4000-8000-000000000000',
        habitId: 'habit',
        date: day,
        createdAt: day.add(const Duration(hours: 9)),
      );
      await prefs.setString(
        'habit-completions-list-v1',
        jsonEncode([older.toJson(), newer.toJson()]),
      );
      final repo = HabitCompletionRepository(prefs);
      await repo.unlogLastInstance('habit', day);
      expect(repo.getAll(), [older]);
    },
  );

  test(
    'undo breaks equal logging times by newest-first storage order',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final day = DateTime(2026, 10, 19);
      final older = HabitCompletion(
        id: 'ffffffff-ffff-4fff-bfff-ffffffffffff',
        habitId: 'habit',
        date: day,
      );
      final newer = HabitCompletion(
        id: '00000000-0000-4000-8000-000000000000',
        habitId: 'habit',
        date: day,
      );
      await prefs.setString(
        'habit-completions-list-v1',
        jsonEncode([newer.toJson(), older.toJson()]),
      );
      final repo = HabitCompletionRepository(prefs);
      await repo.unlogLastInstance('habit', day);
      expect(repo.getAll(), [older]);
    },
  );
}
