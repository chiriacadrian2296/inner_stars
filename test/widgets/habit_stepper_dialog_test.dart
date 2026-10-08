import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/habit_stepper_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Save is on only after a change, and writes the difference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await HabitCompletionRepository.create();
    final habit = Habit(
      id: 7,
      projectId: 1,
      title: 'Bere acqua',
      createdAt: DateTime(2026, 1, 1),
      targetPerPeriod: 3,
    );
    await repository.logInstance(habit.id);
    var changed = 0;

    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHabitStepperDialog(
                context: context,
                habit: habit,
                repository: repository,
                onChanged: () => changed++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    ElevatedButton save() => tester.widget<ElevatedButton>(
      find.byKey(const Key('habit-stepper-save')),
    );
    expect(find.text('1/3'), findsOneWidget);
    expect(save().onPressed, isNull);

    await tester.tap(find.byKey(const Key('habit-stepper-plus')));
    await tester.tap(find.byKey(const Key('habit-stepper-plus')));
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
    expect(save().onPressed, isNotNull);

    // Back to the starting value: nothing to save again.
    await tester.tap(find.byKey(const Key('habit-stepper-minus')));
    await tester.tap(find.byKey(const Key('habit-stepper-minus')));
    await tester.pump();
    expect(save().onPressed, isNull);
    expect(repository.getAllForHabit(habit.id).length, 1);

    await tester.tap(find.byKey(const Key('habit-stepper-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('habit-stepper-save')));
    await tester.pumpAndSettle();
    expect(repository.getAllForHabit(habit.id).length, 2);
    expect(changed, 1);
  });
}
