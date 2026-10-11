import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/area_icon_lab_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(1200, 900),
  ]) {
    testWidgets('all area proposals fit without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const strings = StringsIt();
      await tester.pumpWidget(
        StringsScope(
          strings: strings,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AreaIconLabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      for (final area in LifeArea.values) {
        final panel = find.byKey(ValueKey('area-panel-${area.name}'));
        expect(panel, findsOneWidget);
        final rect = tester.getRect(panel);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        final tiles = find.descendant(
          of: panel,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is InkWell &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'area-icon-',
                ),
          ),
        );
        expect(tiles, findsNWidgets(14));
        for (final tile in tiles.evaluate()) {
          final tileRect = tester.getRect(find.byWidget(tile.widget));
          expect(tileRect.top, greaterThanOrEqualTo(rect.top));
          expect(tileRect.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
        }
        final gridState = tester.state<ScrollableState>(
          find.descendant(of: panel, matching: find.byType(Scrollable)),
        );
        expect(gridState.position.maxScrollExtent, closeTo(0, 0.01));
      }
      expect(tester.takeException(), isNull);

      final proposal = find.byKey(
        const ValueKey('area-icon-social-diversity_1'),
      );
      await tester.tap(proposal);
      await tester.pumpAndSettle();
      expect(find.text('diversity_1'), findsWidgets);
      expect(
        find.text(
          'La tua proposta: persone e cuore, unisce comunità e affetto.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(strings.closeAction.toUpperCase()));
      await tester.pumpAndSettle();
      expect(LifeArea.social.icon, Icons.groups);
      expect(tester.takeException(), isNull);
    });
  }
}
