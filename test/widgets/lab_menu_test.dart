import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/sky_menu_drawer.dart';

void main() {
  for (final detailed in [false, true]) {
    testWidgets(
      'only three independent labs are visible (detailed: $detailed)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        void noop() {}
        await tester.pumpWidget(
          StringsScope(
            strings: const StringsIt(),
            child: TourScope(
              child: MaterialApp(
                theme: buildAppTheme(),
                home: Scaffold(
                  body: SkyMenuContent(
                    detailed: detailed,
                    onLightAStar: noop,
                    onNewConstellation: noop,
                    onVisions: noop,
                    onShootingStars: noop,
                    onNightlight: noop,
                    onSearch: noop,
                    onStatistics: noop,
                    onFriends: noop,
                    onMetaphor: noop,
                    onSettings: noop,
                    onMoonLab: () => calls.add('moon'),
                    onCardBackLab: () => calls.add('cards'),
                    onConstellationLab: () => calls.add('constellation'),
                    onBadgeLab: noop,
                    onUiStudiesLab: noop,
                    onSoundLab: noop,
                    onAreaIconLab: noop,
                    onFabIconLab: noop,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'MOON LAB',
          'CARD BACK LAB',
          'CONSTELLATION LAB',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        for (final label in [
          'BADGE LAB',
          'UI STUDIES LAB',
          'SOUND LAB',
          'FAB ICON LAB',
          'ICONE DELLE AREE',
        ]) {
          expect(find.text(label), findsNothing);
        }
        if (detailed) {
          for (final label in [
            'MOON LAB',
            'CARD BACK LAB',
            'CONSTELLATION LAB',
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await tester.pump();
          }
          expect(calls, ['moon', 'cards', 'constellation']);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
