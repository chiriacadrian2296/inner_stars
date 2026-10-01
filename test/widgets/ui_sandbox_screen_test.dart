import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/debug/ui_audit_catalog.dart';
import 'package:inner_stars/debug/ui_audit_specimens.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/ui_sandbox_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  Future<void> pumpSandbox(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const UiSandboxScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder verticalScroll() => find
      .descendant(
        of: find.byKey(const Key('ui-sandbox-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('renders the audit and responsive specimens on a narrow phone', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(320, 700));
    expect(find.byKey(const Key('ui-sandbox-list')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ui-sandbox-viewport-frame')),
      300,
      scrollable: verticalScroll(),
    );
    expect(find.byKey(const Key('ui-sandbox-viewport-frame')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches viewport widths without overflow exceptions', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(1200, 900));
    await tester.tap(find.text('960'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('ui-sandbox-viewport-frame'))).width,
      960,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('isolated controls change state without leaving the screen', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(800, 1000));
    await tester.drag(
      find.byKey(const Key('ui-sandbox-list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold theme state'));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.byType(UiSandboxScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every comparison renders on a narrow content column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final item in uiAuditCatalog) {
      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 280,
                  child: UiAuditSpecimens(item: item),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: item.id);
    }
  });
}
