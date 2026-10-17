import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/constellation_lab_screen.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/theme/app_style.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';
import 'package:inner_stars/widgets/search_result_card.dart';
import 'package:inner_stars/screens/constellation_focus_lab.dart';
import 'package:inner_stars/widgets/intensity_dots.dart';
import 'package:inner_stars/widgets/photo_image.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_structure_glow.dart';
import 'package:inner_stars/widgets/sky_search_tooltip_card.dart';

void main() {
  testWidgets(
    'house lab compares white structure without changing cards or camera',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> settle() async {
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
      }

      final viewed = <(int, int?)>[];
      final flown = <(int, int?)>[];
      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ConstellationLabScreen(
              onViewStar: (s) => viewed.add((s.entityId, s.slotSequence)),
              onFlyStar: (s) => flown.add((s.entityId, s.slotSequence)),
            ),
          ),
        ),
      );
      await settle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Save for a house'), findsOneWidget);
      final mapFinder = find.byType(ConstellationMapView);
      final original = tester.widget<ConstellationMapView>(mapFinder);
      expect(original.structureColor, isNull);
      expect(original.luminousStructure, isFalse);
      expect(original.stars, hasLength(9));
      final background = find.byKey(const Key('constellation-lab-background'));
      BoxDecoration decoration() =>
          tester.widget<DecoratedBox>(background).decoration as BoxDecoration;
      expect(decoration().gradient, AppColors.dark.constellationGradient);
      original.transformation.value = original.transformation.value.clone()
        ..translateByDouble(12, 8, 0, 1)
        ..scaleByDouble(1.15, 1.15, 1, 1);
      await settle();
      final camera = original.transformation.value.storage.toList();
      await tester.ensureVisible(find.text('Bianco · notte'));
      await tester.tap(find.text('Bianco · notte'));
      await settle();
      final white = tester.widget<ConstellationMapView>(mapFinder);
      expect(white.structureColor, Colors.white);
      expect(white.luminousStructure, isFalse);
      expect(identical(white.stars, original.stars), isTrue);
      expect(white.transformation.value.storage.toList(), camera);
      expect(decoration().gradient, AppColors.dark.nightlightGradient);
      final frames = tester.widgetList<Material>(
        find.byWidgetPredicate((w) => w is Material && w.elevation == 8),
      );
      expect(frames, hasLength(9));
      expect(frames.every((frame) => frame.color == Colors.white), isTrue);
      final innerCards = tester.widgetList<Ink>(
        find.byKey(const Key('search-result-card-body')),
      );
      expect(
        innerCards.every(
          (card) =>
              (card.decoration as BoxDecoration).color ==
              AppColors.dark.nightPanel,
        ),
        isTrue,
      );
      final outerCircles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == Colors.white,
      );
      expect(outerCircles, findsNWidgets(9));
      await tester.ensureVisible(find.text('Cornici navy'));
      await tester.tap(find.text('Cornici navy'));
      await settle();
      final navyFrames = tester.widget<ConstellationMapView>(mapFinder);
      // The scene is drawn once at the fit zoom, so these are already
      // zoom-independent weights; the camera only scales them on screen.
      final navyEdgeWeight = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ConstellationStructureGlowPainter>()
          .single
          .strokeWidth;
      final navyRingWeight =
          (tester.widgetList<Container>(outerCircles).first.padding!
                  as EdgeInsets)
              .left;
      expect(navyFrames.structureColor, Colors.white);
      expect(navyFrames.luminousStructure, isTrue);
      expect(navyFrames.tooltipFrameColor, AppColors.dark.night);
      expect(navyFrames.transformation.value.storage.toList(), camera);
      expect(decoration().gradient, AppColors.dark.nightlightGradient);
      expect(outerCircles, findsNWidgets(9));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == AppColors.dark.night &&
              w.padding != null,
        ),
        findsNWidgets(9),
      );
      expect(
        tester
            .widgetList<Material>(
              find.byWidgetPredicate((w) => w is Material && w.elevation == 8),
            )
            .every((frame) => frame.color == AppColors.dark.night),
        isTrue,
      );
      await tester.ensureVisible(find.text('Originale'));
      await tester.tap(find.text('Originale'));
      await settle();
      expect(
        tester.widget<ConstellationMapView>(mapFinder).structureColor,
        isNull,
      );
      expect(
        tester
            .widget<ConstellationMapView>(mapFinder)
            .transformation
            .value
            .storage
            .toList(),
        camera,
      );
      expect(decoration().gradient, AppColors.dark.constellationGradient);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Leggera'));
      await tester.ensureVisible(find.text('Leggera'));
      await tester.tap(find.text('Leggera'));
      await settle();
      final refined = tester.widget<ConstellationMapView>(mapFinder);
      expect(refined.refinedPresentation, isTrue);
      expect(find.byType(SearchResultCard), findsNWidgets(9));
      refined.onStarTap(refined.stars[1]);
      await settle();
      expect(
        tester.widget<ConstellationMapView>(mapFinder).focusedStarIndex,
        1,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AnimatedOpacity &&
              w.opacity == 0.32 &&
              w.key.toString().contains('constellation-card-focus-'),
        ),
        findsNWidgets(8),
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('constellation-structure-focus-1')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('constellation-structure-focus-0')),
            )
            .opacity,
        0.32,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('constellation-structure-focus-null')),
            )
            .opacity,
        0.32,
      );
      await tester.ensureVisible(find.text('Atlante'));
      await tester.ensureVisible(find.text('Atlante'));
      await tester.tap(find.text('Atlante'));
      await settle();
      expect(find.byType(ConstellationFocusLab), findsOneWidget);
      expect(find.byType(SearchResultCard), findsOneWidget);
      expect(find.byType(SearchStarVisual), findsNothing);
      expect(find.text('1 / 9'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('atlas-node-3')));
      await settle();
      expect(find.text('4 / 9'), findsOneWidget);
      expect(find.text('Reach the down payment goal'), findsOneWidget);
      await tester.tap(find.byKey(const Key('search-card-quick-menu-toggle')));
      await settle();
      final atlasCard = tester.widget<SearchResultCard>(
        find.byType(SearchResultCard),
      );
      expect(atlasCard.menuController.isOpen(atlasCard.menuId), isTrue);
      await tester.tap(find.byTooltip('Successiva'));
      await settle();
      expect(find.text('5 / 9'), findsOneWidget);
      expect(atlasCard.menuController.openId, isNull);
      for (final (label, style) in [
        ('Punti luce', ConstellationNodeStyle.beacon),
        ('Fili', ConstellationNodeStyle.glyph),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await settle();
        final map = tester.widget<ConstellationMapView>(mapFinder);
        expect(map.nodeStyle, style);
        expect(map.selectionEnabled, isTrue);
        expect(find.byType(SearchResultCard), findsNWidgets(9));
        expect(find.byType(SearchStarVisual), findsNothing);
        final card = tester
            .widgetList<SearchResultCard>(find.byType(SearchResultCard))
            .first;
        card.onTap();
        await settle();
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is AnimatedOpacity &&
                w.opacity == 0.32 &&
                w.key.toString().contains('constellation-card-focus-'),
          ),
          findsNWidgets(8),
        );
      }
      await tester.ensureVisible(find.text('Card complete'));
      await tester.tap(find.text('Card complete'));
      await settle();
      final complete = tester.widget<ConstellationMapView>(mapFinder);
      expect(complete.showCardVisual, isTrue);
      expect(complete.simplifiedNodes, isTrue);
      expect(complete.uniformNodeSize, isTrue);
      expect(complete.refinedPresentation, isFalse);
      expect(complete.luminousStructure, isTrue);
      expect(complete.tooltipFrameColor, AppColors.dark.night);
      expect(find.byType(SearchStarVisual), findsNWidgets(9));
      final nodes = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_StarButton',
      );
      expect(nodes, findsNWidgets(9));
      final equalCircles = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == Colors.white,
        ),
      );
      expect(equalCircles, hasLength(9));
      expect(
        equalCircles.map((w) => w.constraints!.maxWidth).toSet(),
        hasLength(1),
      );
      expect(
        find.descendant(of: nodes, matching: find.byType(IntensityDots)),
        findsNothing,
      );
      expect(
        find.descendant(of: nodes, matching: find.byType(PhotoImage)),
        findsNothing,
      );
      for (final card in tester.widgetList<SearchResultCard>(
        find.byType(SearchResultCard),
      )) {
        expect(card.showVisual, isTrue);
        final content = card.content as SearchCardTextContent;
        expect(
          card.baseBodyHeight,
          content.badges == null
              ? SearchResultCard.defaultBodyHeight
              : SearchResultCard.bodyHeightFor(content.badges!),
        );
      }
      expect(
        tester
            .getSize(find.byKey(const Key('search-result-card-body')).first)
            .width,
        362,
      );
      await tester.tapAt(
        tester.getCenter(
          find.byKey(const Key('search-result-card-body')).first,
        ),
      );
      await settle();
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AnimatedOpacity &&
              w.opacity == 0.32 &&
              w.key.toString().contains('constellation-card-focus-'),
        ),
        findsNWidgets(8),
      );
      final selectedFrame = find.byWidgetPredicate(
        (w) => w is Material && w.elevation == 8 && w.color == Colors.white,
      );
      final nativeFrame =
          (tester.widget<Material>(selectedFrame).child! as Padding).padding
              as EdgeInsets;
      expect(nativeFrame.left, lessThan(8));
      final frameRender = tester.renderObject<RenderBox>(selectedFrame);
      final renderScale =
          (frameRender.localToGlobal(const Offset(1, 0)) -
                  frameRender.localToGlobal(Offset.zero))
              .distance;
      final completeUi =
          complete.transformation.value.entry(0, 0) / complete.fitScale;
      final ringWidth = (equalCircles.first.padding! as EdgeInsets).left;
      // Nodes are drawn in scene units; the camera scales the scene by
      // completeUi onto the screen, where they must match the card frame.
      expect(
        nativeFrame.left * renderScale,
        closeTo(ringWidth * completeUi, 0.01),
      );
      final navyBands = tester.widgetList<Container>(
        find.descendant(
          of: nodes,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.padding != null &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle &&
                (w.decoration as BoxDecoration).color == AppColors.dark.night,
          ),
        ),
      );
      expect(navyBands, hasLength(9));
      for (final band in navyBands) {
        expect(
          (band.padding! as EdgeInsets).left * completeUi,
          closeTo(nativeFrame.left * renderScale, 0.01),
        );
      }
      final lightBorders = tester.widgetList<Container>(
        find.descendant(
          of: nodes,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle &&
                (w.decoration as BoxDecoration).border != null,
          ),
        ),
      );
      expect(lightBorders, hasLength(9));
      for (final surface in lightBorders) {
        final border = (surface.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, AppColors.dark.nightBorder);
        expect(
          border.top.width * completeUi,
          closeTo(kBorderWidth * renderScale, 0.01),
        );
      }
      expect(ringWidth, closeTo(navyRingWeight, 0.01));
      final graphGlow = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ConstellationStructureGlowPainter>()
          .single;
      expect(graphGlow.strokeWidth, closeTo(navyEdgeWeight, 0.01));
      expect(
        find.byWidgetPredicate(
          (w) => w is Material && w.elevation == 8 && w.color == Colors.white,
        ),
        findsOneWidget,
      );
      final focusedConnector = find.byKey(
        const Key('constellation-focused-connector'),
      );
      expect(focusedConnector, findsOneWidget);
      expect(
        find.ancestor(
          of: focusedConnector,
          matching: find.byWidgetPredicate(
            (w) => w is AnimatedOpacity && w.opacity == 0.32,
          ),
        ),
        findsNothing,
      );
      expect(
        tester
            .widgetList<Ink>(find.byKey(const Key('search-result-card-body')))
            .every(
              (card) =>
                  (card.decoration as BoxDecoration).color ==
                  AppColors.dark.nightPanel,
            ),
        isTrue,
      );
      await tester.ensureVisible(find.text('Cornici navy'));
      await tester.tap(find.text('Cornici navy'));
      await settle();
      expect(find.byType(SearchStarVisual), findsNothing);
      expect(
        tester.widget<ConstellationMapView>(mapFinder).simplifiedNodes,
        isFalse,
      );
      for (final (label, style) in [
        ('Connettori discreti', ConstellationConnectorStyle.discreet),
        ('Riferimenti', ConstellationConnectorStyle.numbered),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await settle();
        final map = tester.widget<ConstellationMapView>(mapFinder);
        expect(map.connectorStyle, style);
        expect(map.showCardVisual, isTrue);
        expect(map.simplifiedNodes, isTrue);
        expect(find.byType(SearchResultCard), findsNWidgets(9));
        var card = tester
            .widgetList<SearchResultCard>(find.byType(SearchResultCard))
            .first;
        card.onTap();
        await settle();
        card = tester
            .widgetList<SearchResultCard>(find.byType(SearchResultCard))
            .first;
        final expectedEntity = tester
            .widget<SkyTooltipMenuScope>(
              find.ancestor(
                of: find.byWidget(card),
                matching: find.byType(SkyTooltipMenuScope),
              ),
            )
            .menuId;
        card.actions
            .singleWhere((a) => a.icon == Icons.open_in_new_rounded)
            .onTap();
        card.actions.singleWhere((a) => a.icon == Icons.navigation).onTap();
        expect(viewed.last, expectedEntity);
        expect(flown.last, viewed.last);
        expect(card.actions.first.icon, Icons.open_in_new_rounded);
        expect(card.actions.last.icon, Icons.navigation);
        expect(card.actions.last.group, 3);
        if (style == ConstellationConnectorStyle.numbered) {
          for (var i = 0; i < 9; i++) {
            expect(
              find.byKey(ValueKey('constellation-reference-$i')),
              findsNWidgets(2),
            );
          }
          expect(
            find.byKey(const Key('constellation-focused-connector')),
            findsNothing,
          );
        } else {
          expect(
            find.byKey(const Key('constellation-focused-connector')),
            findsOneWidget,
          );
        }
      }
      await tester.ensureVisible(find.text('Riferimenti · griglia'));
      await tester.tap(find.text('Riferimenti · griglia'));
      await settle();
      final grid = tester.widget<ConstellationMapView>(mapFinder);
      expect(grid.cardLayout, ConstellationCardLayout.bottomGrid);
      expect(grid.connectorStyle, ConstellationConnectorStyle.numbered);
      expect(find.byType(SearchResultCard), findsNWidgets(9));
      List<Rect> cardRects() => tester
          .widgetList<Positioned>(
            find.byWidgetPredicate((w) => w is Positioned && w.key is ValueKey),
          )
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();
      final closedGrid = cardRects();
      expect(closedGrid, hasLength(9));
      expect(closedGrid[0].top, closeTo(closedGrid[1].top, 0.01));
      for (var i = 0; i < 9; i++) {
        for (var j = i + 1; j < 9; j++) {
          expect(closedGrid[i].overlaps(closedGrid[j]), isFalse);
        }
      }
      final nodeBounds = tester
          .elementList(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_StarButton',
            ),
          )
          .map((e) => tester.getRect(find.byWidget(e.widget)));
      expect(nodeBounds.every((r) => r.bottom < closedGrid.first.top), isTrue);
      final gridCard = tester
          .widgetList<SearchResultCard>(find.byType(SearchResultCard))
          .first;
      gridCard.onTap();
      await settle();
      gridCard.menuController.toggle(gridCard.menuId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      final movingGrid = cardRects();
      expect(movingGrid[2].top, greaterThan(closedGrid[2].top));
      await settle();
      expect(cardRects()[2].top, greaterThan(movingGrid[2].top));
      await tester.ensureVisible(find.text('Riferimenti'));
      await tester.tap(find.text('Riferimenti'));
      await settle();
      expect(
        tester.widget<ConstellationMapView>(mapFinder).cardLayout,
        ConstellationCardLayout.aroundShape,
      );
      expect(find.byType(SearchResultCard), findsNWidgets(9));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
