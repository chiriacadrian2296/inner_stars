import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit_cycle.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/habit_cycle_detail_dialog.dart';

void main() {
  const strings = StringsIt();

  Future<void> open(WidgetTester tester, HabitCycle cycle) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHabitCycleDetail(context, cycle),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  HabitCycle cycle({String? helped, String? hard, String? feel}) => HabitCycle(
    id: 1,
    habitId: 1,
    startDate: DateTime(2026, 3, 1),
    completedDate: DateTime(2026, 3, 9),
    length: 7,
    intensity: 4,
    resolved: true,
    whatHelped: helped,
    whatWasHard: hard,
    howItFeels: feel,
  );

  testWidgets('shows only the questions that were answered', (tester) async {
    await open(tester, cycle(helped: 'La routine', feel: 'Orgoglio'));

    expect(find.text(strings.cycleQuestionHelped), findsOneWidget);
    expect(find.text('La routine'), findsOneWidget);
    expect(find.text(strings.cycleQuestionFeel), findsOneWidget);
    expect(find.text('Orgoglio'), findsOneWidget);
    expect(find.text(strings.cycleQuestionHard), findsNothing);
  });

  testWidgets('closes with the neutral action', (tester) async {
    await open(tester, cycle(helped: 'La routine'));

    await tester.tap(find.text(strings.closeAction.toUpperCase()));
    await tester.pumpAndSettle();

    expect(find.text('La routine'), findsNothing);
  });
}
