import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/constellation_lab_screen.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';

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

      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ConstellationLabScreen(),
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
      await tester.tap(find.text('Cornici navy'));
      await settle();
      final navyFrames = tester.widget<ConstellationMapView>(mapFinder);
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
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
