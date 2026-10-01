import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/area_filter_sheet.dart';
import 'package:inner_stars/widgets/kind_filter_sheet.dart';

void main() {
  const strings = StringsIt();

  testWidgets('area filters start all on and only enable changed actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: TourScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showAreaFilterSheet(
                    context,
                    selectedAreas: {...LifeArea.values},
                  ),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Tutto'), findsOneWidget);
    expect(_textButton(tester, strings.clearFilterAction).onPressed, isNull);
    expect(
      _elevatedButton(tester, strings.applyFilterAction).onPressed,
      isNull,
    );

    await tester.tap(find.text(LifeArea.physical.displayName(strings)));
    await tester.pump();
    expect(_textButton(tester, strings.clearFilterAction).onPressed, isNotNull);
    expect(
      _elevatedButton(tester, strings.applyFilterAction).onPressed,
      isNotNull,
    );
    expect(
      tester.getCenter(find.text(strings.clearFilterAction)).dx,
      lessThan(tester.getCenter(find.text(strings.applyFilterAction)).dx),
    );

    await tester.tap(find.text(strings.clearFilterAction));
    await tester.pump();
    expect(_textButton(tester, strings.clearFilterAction).onPressed, isNull);
    expect(
      _elevatedButton(tester, strings.applyFilterAction).onPressed,
      isNull,
    );
  });

  testWidgets('kind All label follows selected and unselected chip colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: TourScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showKindFilterSheet(
                    context,
                    selectedKinds: {...kListableStarKinds},
                  ),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    Text label() => tester.widget<Text>(find.text('Tutto'));
    expect(label().style?.color, AppColors.dark.text);
    await tester.tap(find.text('Tutto'));
    await tester.pump();
    expect(label().style?.color, AppColors.dark.muted);
  });
}

TextButton _textButton(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

ElevatedButton _elevatedButton(WidgetTester tester, String label) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));
