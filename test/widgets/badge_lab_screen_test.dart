import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/badge_lab_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  testWidgets('the badge lab renders at every zoom without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const BadgeLabScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
