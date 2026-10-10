import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/area_filter_sheet.dart';
import 'package:inner_stars/widgets/kind_filter_sheet.dart';

void main() {
  const strings = StringsIt();

  Future<void> open(
    WidgetTester tester,
    Widget Function(BuildContext) button,
  ) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: TourScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(body: button(context)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('area filter starts with nothing chosen and has no All switch', (
    tester,
  ) async {
    Set<LifeArea>? result;
    await open(
      tester,
      (context) => ElevatedButton(
        onPressed: () async => result = await showAreaFilterSheet(
          context,
          selectedAreas: {...LifeArea.values},
        ),
        child: const Text('Apri'),
      ),
    );

    expect(find.byType(Switch), findsNothing);
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

    await tester.tap(find.text(strings.applyFilterAction.toUpperCase()));
    await tester.pumpAndSettle();
    expect(result, {LifeArea.physical});
  });

  testWidgets('area filter: clearing, or choosing none, means every area', (
    tester,
  ) async {
    Set<LifeArea>? result;
    await open(
      tester,
      (context) => ElevatedButton(
        onPressed: () async => result = await showAreaFilterSheet(
          context,
          selectedAreas: {LifeArea.physical, LifeArea.professional},
        ),
        child: const Text('Apri'),
      ),
    );

    await tester.tap(find.text(strings.clearFilterAction.toUpperCase()));
    await tester.pump();
    expect(_textButton(tester, strings.clearFilterAction).onPressed, isNull);
    await tester.tap(find.text(strings.applyFilterAction.toUpperCase()));
    await tester.pumpAndSettle();
    expect(result, {...LifeArea.values});
  });

  testWidgets('kind filter works the same way', (tester) async {
    Set<StarKind>? result;
    await open(
      tester,
      (context) => ElevatedButton(
        onPressed: () async => result = await showKindFilterSheet(
          context,
          selectedKinds: {...kListableStarKinds},
        ),
        child: const Text('Apri'),
      ),
    );

    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text(kListableStarKinds.first.plural(strings)));
    await tester.pump();
    await tester.tap(find.text(strings.applyFilterAction.toUpperCase()));
    await tester.pumpAndSettle();
    expect(result, {kListableStarKinds.first});
  });
}

TextButton _textButton(WidgetTester tester, String label) => tester
    .widget<TextButton>(find.widgetWithText(TextButton, label.toUpperCase()));

ElevatedButton _elevatedButton(WidgetTester tester, String label) =>
    tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, label.toUpperCase()),
    );
