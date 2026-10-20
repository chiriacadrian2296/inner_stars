import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/models/share_content.dart';
import 'package:inner_stars/screens/share_composer_screen.dart';
import 'package:inner_stars/screens/share_preview_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/area_hero_art.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';

const strings = StringsIt();
Widget app(Widget home, {bool english = false}) => StringsScope(
  strings: english ? const StringsEn() : strings,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

Future<void> selectCategory(WidgetTester tester, int category) async {
  final tab = find.byKey(ValueKey('share-category-$category'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
}

void main() {
  testWidgets(
    'common share entry uses the composer and edits only the shared excerpt',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2026);
      final record = Reflection(
        id: 'reflection',
        area: LifeArea.social,
        title: 'Il mio titolo',
        body: 'Il testo originale',
        origin: ReflectionOrigin.free,
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSharePreview(
                  context: context,
                  content: ShareableReflectionCard(reflection: record),
                  shareText: record.title,
                  fileName: 'reflection.png',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareComposerScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text(strings.sharePreviewTitle), findsNothing);
      expect(find.byKey(const ValueKey('scheda-contenuto-menu')), findsNothing);
      expect(find.text(record.title), findsWidgets);
      expect(find.text(record.body), findsWidgets);
      expect(find.text(LifeArea.social.displayName(strings)), findsWidgets);
      expect(find.text('Salute'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-reflection-excerpt')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('share-excerpt-field')),
        'Solo un estratto',
      );
      await tester.tap(find.text(strings.saveChanges.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('Solo un estratto'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('share-undo')));
      await tester.pump();
      expect(find.text(record.body), findsWidgets);
      expect(find.text('Solo un estratto'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-redo')));
      await tester.pump();
      expect(find.text('Solo un estratto'), findsWidgets);
      expect(record.body, 'Il testo originale');
      await selectCategory(tester, 1);
      await tester.pump();
      await tester.ensureVisible(find.text('Testo'));
      await tester.tap(find.text('Testo'));
      await tester.pump();
      expect(find.text('Solo un estratto'), findsNothing);
      expect(record.body, 'Il testo originale');
      await selectCategory(tester, 3);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsNothing);
      expect(find.byKey(const ValueKey('firma-colore-nome-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('firma-mostra-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo Logo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('firma-colore-nome-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('firma-posizione-8')));
      await tester.pump();
      expect(find.textContaining('Basso Destra'), findsOneWidget);
      await selectCategory(tester, 2);
      await tester.pump();
      expect(find.byKey(const ValueKey('sfondo-foto-menu')), findsNothing);
      expect(find.byKey(const ValueKey('watermark-misura-menu')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('watermark-tipo-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('watermark-misura-menu')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('sfondo-colori-3')));
      await tester.tap(find.byKey(const ValueKey('sfondo-colori-3')));
      await tester.pump();
      expect(find.text('Colori · Oro'), findsOneWidget);
      expect(find.byKey(const ValueKey('sfondo-colori-4')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history restores an entire preset and clears redo after a new edit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          const ShareComposerScreen(
            data: ShareContent(
              subject: ShareSubject.goal,
              title: 'Il mio obiettivo',
              typeLabel: 'Obiettivo',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final undo = find.byKey(const ValueKey('share-undo'));
      final redo = find.byKey(const ValueKey('share-redo'));
      expect(tester.widget<IconButton>(undo).onPressed, isNull);
      expect(tester.widget<IconButton>(redo).onPressed, isNull);
      final ocean = find.byKey(const ValueKey('stile-preset-3'));
      await tester.ensureVisible(ocean);
      await tester.tap(ocean);
      await tester.pump();
      await tester.tap(
        ocean,
      ); // Choosing the same preset must not add a history step.
      await tester.pump();
      await selectCategory(tester, 3);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsNothing);
      expect(tester.widget<IconButton>(undo).onPressed, isNull);
      await tester.tap(redo);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('firma-mostra-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nessuna'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('firma-posizione-0')), findsNothing);
      await tester.tap(undo);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      expect(find.byKey(const ValueKey('firma-logo-menu')), findsNothing);
      await selectCategory(tester, 0);
      await tester.pump();
      expect(find.text('Stile · Classico'), findsOneWidget);
      await selectCategory(tester, 2);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('sfondo-colori-3')));
      await tester.tap(find.byKey(const ValueKey('sfondo-colori-3')));
      await tester.pump();
      expect(tester.widget<IconButton>(redo).onPressed, isNull);
      await selectCategory(tester, 0);
      await tester.pump();
      expect(find.text('Stile · Personalizzato'), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      expect(find.text('Stile · Classico'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (var preset = 0; preset < 6; preset++) {
        final choice = find.byKey(ValueKey('stile-preset-$preset'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'preset $preset');
      }
    },
  );

  testWidgets(
    'watermark artwork follows the content area and undo restores it',
    (tester) async {
      const first = ShareContent(
        subject: ShareSubject.goal,
        title: 'Primo',
        typeLabel: 'Fisico',
        area: LifeArea.physical,
      );
      const second = ShareContent(
        subject: ShareSubject.goal,
        title: 'Secondo',
        typeLabel: 'Sociale',
        area: LifeArea.social,
      );
      await tester.pumpWidget(
        app(const ShareComposerScreen(data: first, variants: [first, second])),
      );
      await tester.pumpAndSettle();
      await selectCategory(tester, 2);
      await tester.pump();
      final artwork = find.byKey(const ValueKey('watermark-tipo-2'));
      await tester.ensureVisible(artwork);
      await tester.tap(artwork);
      await tester.pumpAndSettle();
      String asset() =>
          (tester
                      .widget<Image>(
                        find.descendant(
                          of: artwork,
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as AssetImage)
              .assetName;
      expect(asset(), kAreaHeroArt[LifeArea.physical]!.coverAsset);
      expect(find.byKey(const ValueKey('watermark-tipo-3')), findsNothing);
      await selectCategory(tester, 0);
      await tester.pump();
      final subject = find.byKey(const ValueKey('scheda-contenuto-menu'));
      await tester.ensureVisible(subject);
      await tester.tap(subject);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sociale').last);
      await tester.pumpAndSettle();
      await selectCategory(tester, 2);
      await tester.pumpAndSettle();
      expect(asset(), kAreaHeroArt[LifeArea.social]!.coverAsset);
      await tester.tap(find.byKey(const ValueKey('share-undo')));
      await tester.pumpAndSettle();
      expect(asset(), kAreaHeroArt[LifeArea.physical]!.coverAsset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reversing colors preserves every gradient shape and supports history',
    (tester) async {
      await tester.pumpWidget(
        app(
          const ShareComposerScreen(
            data: ShareContent(
              subject: ShareSubject.goal,
              title: 'Obiettivo',
              typeLabel: 'Obiettivo',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await selectCategory(tester, 2);
      await tester.pump();
      Gradient background() {
        final box = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(const ValueKey('share-preview')),
                matching: find.byType(DecoratedBox),
              ),
            )
            .firstWhere(
              (box) =>
                  box.decoration is BoxDecoration &&
                  (box.decoration as BoxDecoration).gradient != null,
            );
        return (box.decoration as BoxDecoration).gradient!;
      }

      expect(find.byKey(const ValueKey('sfondo-forma-4')), findsNothing);
      for (var shape = 0; shape < 4; shape++) {
        final choice = find.byKey(ValueKey('sfondo-forma-$shape'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
        final original = background();
        final reverse = find.byKey(const ValueKey('share-reverse-colors'));
        await tester.ensureVisible(reverse);
        await tester.tap(reverse);
        await tester.pump();
        final inverted = background();
        expect(inverted.colors, original.colors.reversed.toList());
        expect(inverted.stops, original.stops);
        if (original is RadialGradient) {
          expect(inverted, isA<RadialGradient>());
          expect((inverted as RadialGradient).center, original.center);
          expect(inverted.radius, original.radius);
        } else {
          expect(inverted, isA<LinearGradient>());
          expect(
            (inverted as LinearGradient).begin,
            (original as LinearGradient).begin,
          );
          expect(inverted.end, original.end);
        }
        await tester.tap(find.byKey(const ValueKey('share-undo')));
        await tester.pump();
        expect(background(), original);
        await tester.tap(find.byKey(const ValueKey('share-redo')));
        await tester.pump();
        expect(background(), inverted);
        await tester.tap(reverse);
        await tester.pump();
        expect(background(), original);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'production compositions fit $size with long content and no invented statistics',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final subject in ShareSubject.values) {
          await tester.pumpWidget(
            app(
              ShareComposerScreen(
                key: ValueKey(subject),
                data: ShareContent(
                  subject: subject,
                  typeLabel: subject.name,
                  title: List.filled(20, 'Titolo').join(' '),
                  description: List.filled(100, 'Testo').join(' '),
                  areaLabel: 'Area reale',
                  isReflection: subject == ShareSubject.vision,
                  artwork: const Icon(Icons.star),
                ),
              ),
              english: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('scheda-contenuto-menu')),
            findsNothing,
          );
          expect(find.text('7 stelle'), findsNothing);
          expect(find.text('Serie di 21 giorni'), findsNothing);
          final compositionCount = find
              .byWidgetPredicate((widget) {
                final key = widget.key;
                return key is ValueKey<String> &&
                    key.value.startsWith('scheda-composizione-');
              })
              .evaluate()
              .length;
          expect(
            compositionCount,
            3,
            reason: 'three compositions for ${subject.name}',
          );
          for (var i = 0; i < compositionCount; i++) {
            final next = find.byKey(ValueKey('scheda-composizione-$i'));
            await tester.ensureVisible(next);
            await tester.tap(next);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${subject.name}, composition $i, $size',
            );
          }
          final previewSize = tester.getSize(
            find.byKey(const ValueKey('share-preview')),
          );
          final previewPosition = tester.getTopLeft(
            find.byKey(const ValueKey('share-preview')),
          );
          for (final category in [1, 2, 3, 0]) {
            await selectCategory(tester, category);
            await tester.pump();
            expect(
              find.byKey(ValueKey('share-category-panel-$category')),
              findsOneWidget,
            );
            expect(
              tester.getSize(find.byKey(const ValueKey('share-preview'))),
              previewSize,
            );
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('share-preview'))),
              previewPosition,
            );
            expect(
              find.byKey(const ValueKey('scheda-composizione-0')),
              category == 0 ? findsOneWidget : findsNothing,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${subject.name}, category $category, $size',
            );
          }
          for (var format = 1; format < 5; format++) {
            final choice = find.byKey(ValueKey('scheda-formato-$format'));
            await tester.ensureVisible(choice);
            await tester.tap(choice);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${subject.name}, format $format, $size',
            );
          }
        }
      },
    );
  }
}
