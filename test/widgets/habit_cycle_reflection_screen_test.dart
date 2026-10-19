import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/habit_cycle_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_cycle.dart';
import 'package:inner_stars/screens/habit_cycle_reflection_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const strings = StringsIt();
  late HabitRepository habits;
  late HabitCycleRepository cycles;
  late Habit habit;
  late HabitCycle cycle;
  bool? popped;

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    habits = await HabitRepository.create();
    cycles = await HabitCycleRepository.create();
    habit = await habits.add(
      title: 'Camminata',
      projectId: '1',
      cycleLength: 7,
      intensity: 4,
      createdAt: DateTime(2026, 3, 1),
    );
    cycle = HabitCycle(
      id: '1',
      habitId: habit.id,
      startDate: DateTime(2026, 3, 1),
      completedDate: DateTime(2026, 3, 9),
      length: 7,
      intensity: 4,
    );
    await cycles.addMany([cycle]);
    popped = null;

    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => HabitCycleReflectionScreen(
                      habit: habit,
                      cycle: cycle,
                      habitRepository: habits,
                      cycleRepository: cycles,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapAction(WidgetTester tester, String label) =>
      tapText(tester, label.toUpperCase());

  testWidgets('congratulates and offers the three ways to go on', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(strings.cycleDoneTitle), findsOneWidget);
    expect(find.text(strings.cycleOptionRestartTitle), findsOneWidget);
    expect(find.text(strings.cycleOptionChangeTitle), findsOneWidget);
    expect(find.text(strings.cycleOptionCloseTitle), findsOneWidget);
  });

  testWidgets('Later leaves the cycle waiting for its reflection', (
    tester,
  ) async {
    await open(tester);

    await tapAction(tester, strings.cycleLaterAction);

    expect(popped, isFalse);
    expect(cycles.pendingFor(habit.id), isNotNull);
    expect(habits.getAll().single.cycleStart, isNull);
  });

  testWidgets('restarting keeps length and reward and starts the next day', (
    tester,
  ) async {
    await open(tester);

    await tapAction(tester, strings.cycleContinueAction);

    expect(popped, isTrue);
    expect(cycles.pendingFor(habit.id), isNull);
    final next = habits.getAll().single;
    expect(next.currentCycleStart, DateTime(2026, 3, 10));
    expect(next.cycleLength, 7);
    expect(next.intensity, 4);
  });

  testWidgets('changing it saves the new length and reward', (tester) async {
    await open(tester);
    await tapText(tester, strings.cycleOptionChangeTitle);
    await tapText(tester, '30');

    // The reward starts on the old one, inactive: until it's chosen again
    // Continue does nothing.
    await tapAction(tester, strings.cycleContinueAction);
    expect(habits.getAll().single.cycleLength, isNot(30));

    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();
    await tapAction(tester, strings.cycleContinueAction);

    final next = habits.getAll().single;
    expect(next.cycleLength, 30);
    expect(next.intensity, 5);
    expect(next.currentCycleStart, DateTime(2026, 3, 10));
  });

  testWidgets('wrapping the habit up archives it and keeps the reward', (
    tester,
  ) async {
    await open(tester);
    await tapText(tester, strings.cycleOptionCloseTitle);

    await tapAction(tester, strings.cycleArchiveAction);

    expect(popped, isTrue);
    expect(habits.getAll().single.dead, isTrue);
    expect(cycles.getAll().single.resolved, isTrue);
  });
}
