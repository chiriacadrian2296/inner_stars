import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_editor_painter.dart';
import 'package:inner_stars/widgets/search_result_card.dart';

void main() {
  Future<void> pumpCards(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(320, 700),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, appChild) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: appChild!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SearchResultCard card({
    required String id,
    required SearchCardMenuController controller,
    required VoidCallback onOpen,
    required VoidCallback onNavigate,
  }) {
    return SearchResultCard(
      key: Key('card-$id'),
      menuId: id,
      menuController: controller,
      onTap: onOpen,
      visual: const SearchMissingVisual(icon: Icons.flare),
      content: const SearchCardTextContent(
        eyebrow: 'Stella accesa',
        title: 'Un titolo italiano molto lungo da troncare',
        breadcrumb: 'Crescita personale → Una costellazione molto lunga',
        primary: 'Intensità: 5',
      ),
      actions: [
        SearchCardAction(
          icon: Icons.open_in_new_rounded,
          label: 'Apri',
          onTap: onOpen,
        ),
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: 'Portami lì',
          onTap: onNavigate,
        ),
      ],
    );
  }

  testWidgets('opens a full-width drawer and runs only real actions', (
    tester,
  ) async {
    final controller = SearchCardMenuController();
    addTearDown(controller.dispose);
    var openCount = 0;
    var navigateCount = 0;
    await pumpCards(
      tester,
      child: SizedBox(
        width: 300,
        child: card(
          id: 'one',
          controller: controller,
          onOpen: () => openCount++,
          onNavigate: () => navigateCount++,
        ),
      ),
    );

    final surface = find.byKey(const Key('search-result-card-surface'));
    final body = find.byKey(const Key('search-result-card-body'));
    final toggle = find.byKey(const Key('search-card-quick-menu-toggle'));
    expect(tester.getSize(surface), const Size(300, 88));
    expect(tester.getSize(body), const Size(300, 88));
    expect(tester.getSize(toggle), const Size(20, 48));

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final drawer = find.byKey(const Key('search-card-quick-menu'));
    expect(tester.getSize(surface), const Size(300, 138));
    expect(tester.getSize(drawer).width, 300);
    expect(find.text('Apri'), findsOneWidget);
    expect(find.text('Portami lì'), findsOneWidget);
    expect(find.text('Modifica'), findsNothing);
    expect(find.text('Condividi'), findsNothing);

    await tester.tap(find.text('Portami lì'));
    await tester.pumpAndSettle();
    expect(navigateCount, 1);
    expect(openCount, 0);
    expect(tester.getSize(surface).height, 88);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps only one quick menu open', (tester) async {
    final controller = SearchCardMenuController();
    addTearDown(controller.dispose);
    await pumpCards(
      tester,
      child: Column(
        children: [
          card(
            id: 'one',
            controller: controller,
            onOpen: () {},
            onNavigate: () {},
          ),
          const SizedBox(height: 12),
          card(
            id: 'two',
            controller: controller,
            onOpen: () {},
            onNavigate: () {},
          ),
        ],
      ),
    );

    final firstCard = find.byKey(const Key('card-one'));
    final secondCard = find.byKey(const Key('card-two'));
    final firstToggle = find.descendant(
      of: firstCard,
      matching: find.byKey(const Key('search-card-quick-menu-toggle')),
    );
    final secondToggle = find.descendant(
      of: secondCard,
      matching: find.byKey(const Key('search-card-quick-menu-toggle')),
    );
    await tester.tap(firstToggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(firstCard).height, 138);
    expect(tester.getSize(secondCard).height, 88);

    await tester.tap(secondToggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(firstCard).height, 88);
    expect(tester.getSize(secondCard).height, 138);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the chosen glyph for every star state', (tester) async {
    await pumpCards(
      tester,
      child: const Row(
        children: [
          SizedBox(
            width: 70,
            height: 88,
            child: SearchStarVisual(kind: StarKind.lit),
          ),
          SizedBox(
            width: 70,
            height: 88,
            child: SearchStarVisual(kind: StarKind.unlit),
          ),
          SizedBox(
            width: 60,
            height: 88,
            child: SearchStarVisual(kind: StarKind.pulsar),
          ),
          SizedBox(
            width: 60,
            height: 88,
            child: SearchStarVisual(kind: StarKind.dead),
          ),
          SizedBox(
            width: 60,
            height: 88,
            child: SearchStarVisual(kind: StarKind.nascent),
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byIcon(Icons.hide_source), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers constellation shapes in the Shape Library style', (
    tester,
  ) async {
    const shape = ConstellationShape(
      points: [Offset(0.45, 0.05), Offset(0.5, 0.5), Offset(0.55, 0.95)],
      edges: [(0, 1), (1, 2)],
    );
    await pumpCards(
      tester,
      child: const SizedBox.square(
        dimension: 88,
        child: SearchConstellationVisual(shape: shape),
      ),
    );

    final preview = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is ConstellationEditorPainter,
    );
    final paint = tester.widget<CustomPaint>(preview);
    final painter = paint.painter! as ConstellationEditorPainter;
    expect(painter.pointColor, AppColors.dark.text);
    expect(painter.lineColor, AppColors.dark.muted.withValues(alpha: 0.6));
    expect(painter.pointRadius, 2.5);
    final xs = painter.points.map((point) => point.dx);
    expect(
      (xs.reduce((a, b) => a + b) / painter.points.length),
      closeTo(44, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow phone with enlarged text', (
    tester,
  ) async {
    final controller = SearchCardMenuController();
    addTearDown(controller.dispose);
    await pumpCards(
      tester,
      size: const Size(280, 640),
      textScale: 1.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: card(
          id: 'large-text',
          controller: controller,
          onOpen: () {},
          onNavigate: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('search-result-card-body'))).height,
      greaterThan(88),
    );
    expect(tester.takeException(), isNull);
  });
}
