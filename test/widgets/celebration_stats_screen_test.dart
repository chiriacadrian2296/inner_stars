import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/celebration_stats_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('empty and populated narrow page supports period changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final stars = await StarRepository.create();
    final habits = await HabitRepository.create();
    final completions = await HabitCompletionRepository.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: StringsScope(
          strings: const StringsIt(),
          child: CelebrationStatsScreen(
            starRepository: stars,
            habitRepository: habits,
            completionRepository: completions,
          ),
        ),
      ),
    );
    expect(find.text('Qui prenderà forma la tua luce'), findsOneWidget);
    await stars.add(
      title: 'Done',
      projectId: 1,
      achievedDate: DateTime.now(),
      intensity: 3,
    );
    await tester.tap(find.text('7 giorni'));
    await tester.pumpAndSettle();
    expect(find.text('Guarda quanto hai fatto.'), findsOneWidget);
    expect(find.text('Il tuo percorso, un passo alla volta'), findsOneWidget);
    expect(find.text('Azioni completate · totale cumulativo'), findsOneWidget);
    expect(find.text('cose che hai fatto'), findsNothing);
    expect(find.text('stelle che hai acceso'), findsOneWidget);
    expect(find.text('gesti dei tuoi Pulsar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
