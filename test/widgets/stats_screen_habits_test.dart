import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/stats_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('statistics separates pulsars from stars and opens archive', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final starRepository = await StarRepository.create();
    final projectRepository = await ProjectRepository.create();
    final habitRepository = await HabitRepository.create();
    final completionRepository = await HabitCompletionRepository.create();
    final shapeRepository = await StarsShapeRepository.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: StringsScope(
          strings: const StringsEn(),
          child: StatsScreen(
            starRepository: starRepository,
            projectRepository: projectRepository,
            habitRepository: habitRepository,
            habitCompletionRepository: completionRepository,
            starsShapeRepository: shapeRepository,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Pulsars'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '7'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '30'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '90'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No past pulsars yet.'), findsOneWidget);
  });
}
