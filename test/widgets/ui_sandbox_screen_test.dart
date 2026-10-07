import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/debug/ui_audit_catalog.dart';
import 'package:inner_stars/debug/ui_audit_specimens.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/ui_sandbox_screen.dart';
import 'package:inner_stars/theme/app_colors.dart';
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const UiSandboxScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder verticalScroll({bool parked = false}) => find
      .descendant(
        of: find.byKey(
          Key(parked ? 'ui-sandbox-parked-list' : 'ui-sandbox-list'),
        ),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> openParkedStudies(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('moon-sandbox-open-parked')));
    await tester.pumpAndSettle();
  }

  testWidgets('keeps Moon focused and parks old studies on a narrow phone', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(320, 700));
    expect(find.byKey(const Key('ui-sandbox-list')), findsOneWidget);
    expect(find.byKey(const Key('moon-mascot-preview')), findsOneWidget);
    expect(find.byKey(const Key('ui-sandbox-viewport-frame')), findsNothing);

    await openParkedStudies(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ui-sandbox-viewport-frame')),
      300,
      scrollable: verticalScroll(parked: true),
    );
    expect(find.byKey(const Key('ui-sandbox-viewport-frame')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches viewport widths without overflow exceptions', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(1200, 900));
    await openParkedStudies(tester);
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
    await openParkedStudies(tester);
    await tester.drag(
      find.byKey(const Key('ui-sandbox-parked-list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold theme state'));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.byType(UiSandboxScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Moon preview exposes every expression and reaction', (
    tester,
  ) async {
    await pumpSandbox(tester, const Size(800, 1100));
    await tester.scrollUntilVisible(
      find.byKey(const Key('moon-mascot-preview')),
      500,
      scrollable: verticalScroll(),
    );
    for (final label in [
      'Neutral',
      'Happy',
      'Sleepy',
      'Curious',
      'Concerned',
      'Surprised',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Curious'));
    await tester.pump(const Duration(milliseconds: 400));
    final curiousChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('moon-expression-curious')),
    );
    final colors = Theme.of(
      tester.element(find.byKey(const ValueKey('moon-expression-curious'))),
    ).extension<AppColors>()!;
    expect(curiousChip.selectedColor, colors.gold);
    expect(find.byKey(const Key('moon-appearance-editor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('moon-layer-mouth')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('moon-layer-mouth')))
          .selected,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('moon-hue-body')),
      180,
      scrollable: verticalScroll(),
    );
    await tester.drag(
      find.byKey(const ValueKey('moon-hue-body')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('moon-56')), findsOneWidget);
    expect(find.byKey(const ValueKey('moon-112')), findsOneWidget);
    expect(find.byKey(const ValueKey('moon-220')), findsOneWidget);
    await tester.tap(find.byKey(const Key('moon-reaction-acknowledge')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moon-reaction-celebrate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moon-animation-toggle')));
    await tester.pump();
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
