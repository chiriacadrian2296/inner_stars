import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/card_back_lab_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  testWidgets('every kind and option lays out without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) =>
            StringsScope(strings: StringsIt(), child: child!),
        home: const CardBackLabScreen(),
      ),
    );
    await tester.pumpAndSettle();
    for (final kind in ['Costellazione', 'Pulsar', 'Vittoria', 'Obiettivo']) {
      for (final toggle in [null, 'Cassetto Aperto', 'Titolo Lungo']) {
        await tester.tap(find.text(kind));
        if (toggle != null) await tester.tap(find.text(toggle));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$kind / $toggle');
      }
    }
  });
}
