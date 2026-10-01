import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/star_heatmap.dart';

Widget app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: StringsScope(
    strings: const StringsEn(),
    child: Scaffold(body: SizedBox(width: 500, child: child)),
  ),
);

void main() {
  testWidgets('habit calendar distinguishes partial and completed days', (
    tester,
  ) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - 1);
    final partial = DateTime(month.year, month.month, 1);
    final complete = DateTime(month.year, month.month, 2);

    await tester.pumpWidget(
      app(
        StarHeatmap(
          month: month,
          countsByDay: {partial: 1, complete: 2},
          intensityByDay: {partial: 1, complete: 2},
          progressByDay: {partial: .5, complete: 1},
        ),
      ),
    );

    expect(find.byIcon(Icons.star_half), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('days outside the habit lifetime are not interactive stars', (
    tester,
  ) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - 1);
    final first = DateTime(month.year, month.month, 1);

    await tester.pumpWidget(
      app(
        StarHeatmap(
          month: month,
          countsByDay: {first: 1},
          intensityByDay: {first: 1},
          progressByDay: {first: 1},
          availableFrom: first.add(const Duration(days: 1)),
        ),
      ),
    );

    expect(find.byIcon(Icons.star), findsNothing);
  });
}
