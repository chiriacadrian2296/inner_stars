import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/models/share_content.dart';
import 'package:inner_stars/data/photo_storage.dart';
import 'package:inner_stars/screens/share_composer_screen.dart';
import 'package:inner_stars/screens/share_preview_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/utils/area_hero_art.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';

const strings = StringsIt();
Widget app(Widget home, {bool english = false}) => StringsScope(
  strings: english ? const StringsEn() : strings,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

Future<void> scrollToSection(WidgetTester tester, int category) async {
  await tester.ensureVisible(find.byKey(ValueKey('share-section-$category')));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

bool choiceSelected(WidgetTester tester, String key) => tester
    .widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(ValueKey(key)),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected != null,
            ),
          )
          .first,
    )
    .properties
    .selected!;

void main() {
  testWidgets(
    'excerpt editing leaves source intact and composition owns content options',
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
      await tapVisible(tester, find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareComposerScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text(strings.sharePreviewTitle), findsNothing);
      for (final key in [
        'testo-colore-0',
        'testo-posizione-0',
        'testo-badge-menu',
        'firma-logo-menu',
        'firma-misura-menu',
        'firma-posizione-0',
        'firma-colore-nome-0',
        'watermark-colore-0',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('share-reflection-excerpt')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('share-excerpt-field')),
        'Solo un estratto',
      );
      await tapVisible(tester, find.text(strings.saveChanges.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('Solo un estratto'), findsWidgets);
      expect(record.body, 'Il testo originale');
      await tapVisible(tester, find.byKey(const ValueKey('share-undo')));
      await tester.pump();
      expect(find.text(record.body), findsWidgets);
      expect(find.text('Solo un estratto'), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('share-redo')));
      await tester.pump();
      expect(find.text('Solo un estratto'), findsWidgets);
      expect(record.body, 'Il testo originale');
      expect(
        find.byKey(const ValueKey('firma-disposizione-2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('firma-disposizione-3')), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('firma-disposizione-0')),
      );
      await tester.pump();
      expect(choiceSelected(tester, 'firma-disposizione-0'), isTrue);
      final size = find.byKey(const ValueKey('watermark-misura-menu'));
      expect((tester.widget(size) as dynamic).onChanged, isNull);
      await tapVisible(tester, find.byKey(const ValueKey('watermark-tipo-1')));
      await tester.pump();
      expect((tester.widget(size) as dynamic).onChanged, isNotNull);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('watermark-tipo-tile-1')))
            .center
            .dy,
        closeTo(tester.getRect(size).center.dy, 2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compositions choose linked element colors while leaving the title unchanged',
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
              title: 'Una direzione',
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
      expect(find.byKey(const ValueKey('stile-preset-2')), findsNothing);
      final golden = find.byKey(const ValueKey('stile-preset-1'));
      await tapVisible(tester, golden);
      await tester.pump();
      await tapVisible(tester, golden);
      await tester.pump();
      void expectLinked(Color color) {
        final preview = find.byKey(const ValueKey('share-preview'));
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: preview,
                  matching: find.text('Una direzione'),
                ),
              )
              .style!
              .color,
          AppColors.dark.text,
        );
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: preview,
                  matching: find.text('Inner Stars'),
                ),
              )
              .style!
              .color,
          color,
        );
        final logos = tester
            .widgetList<SvgPicture>(
              find.descendant(of: preview, matching: find.byType(SvgPicture)),
            )
            .where(
              (picture) =>
                  picture.bytesLoader is SvgAssetLoader &&
                  (picture.bytesLoader as SvgAssetLoader).assetName ==
                      'assets/icon/Logo.svg',
            );
        expect(logos.length, greaterThanOrEqualTo(2));
        for (final logo in logos) {
          expect(logo.colorFilter, ColorFilter.mode(color, BlendMode.srcIn));
        }
      }

      expectLinked(AppColors.dark.gold);
      expect(find.byKey(const ValueKey('colore-elementi-1')), findsNothing);
      await tapVisible(tester, undo);
      await tester.pump();
      expect(choiceSelected(tester, 'stile-preset-0'), isTrue);
      expect(tester.widget<IconButton>(undo).onPressed, isNull);
      await tapVisible(tester, redo);
      await tester.pump();
      expectLinked(AppColors.dark.gold);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('firma-disposizione-2')),
      );
      await tester.pump();
      await tapVisible(tester, undo);
      await tester.pump();
      expect(choiceSelected(tester, 'firma-disposizione-1'), isTrue);
      expect(choiceSelected(tester, 'stile-preset-1'), isTrue);
      await tapVisible(tester, undo);
      await tester.pump();
      expect(choiceSelected(tester, 'stile-preset-0'), isTrue);
      await tapVisible(tester, redo);
      await tester.pump();
      await tapVisible(
        tester,
        find.byKey(const ValueKey('scheda-composizione-1')),
      );
      await tester.pump();
      expectLinked(AppColors.dark.text);
      expect(tester.widget<IconButton>(redo).onPressed, isNull);
      expect(choiceSelected(tester, 'stile-preset-1'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'signature choices use the same logo and typography as the post',
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
      for (final format in [0, 4]) {
        await tapVisible(
          tester,
          find.byKey(ValueKey('scheda-formato-$format')),
        );
        await tester.pump();
        for (var arrangement = 0; arrangement < 3; arrangement++) {
          final choice = find.byKey(
            ValueKey('firma-disposizione-$arrangement'),
          );
          await tapVisible(tester, choice);
          await tester.pump();
          final preview = find.byKey(const ValueKey('share-preview'));
          SvgPicture logo(Finder scope) => tester
              .widgetList<SvgPicture>(
                find.descendant(of: scope, matching: find.byType(SvgPicture)),
              )
              .lastWhere(
                (picture) =>
                    picture.bytesLoader is SvgAssetLoader &&
                    (picture.bytesLoader as SvgAssetLoader).assetName ==
                        'assets/icon/Logo.svg',
              );
          final actual = logo(preview);
          final sample = logo(choice);
          expect(sample.width, actual.width);
          expect(sample.height, actual.height);
          expect(sample.colorFilter, actual.colorFilter);
          if (arrangement == 0) {
            expect(
              find.descendant(of: preview, matching: find.text('Inner Stars')),
              findsNothing,
            );
          } else {
            expect(
              tester
                  .widget<Text>(
                    find.descendant(
                      of: choice,
                      matching: find.text('Inner Stars'),
                    ),
                  )
                  .style,
              tester
                  .widget<Text>(
                    find.descendant(
                      of: preview,
                      matching: find.text('Inner Stars'),
                    ),
                  )
                  .style,
            );
          }
        }
      }
      expect(find.text('Contenuto'), findsNothing);
      for (var section = 0; section < 3; section++) {
        final heading = find
            .descendant(
              of: find.byKey(ValueKey('share-section-$section')),
              matching: find.byType(Text),
            )
            .first;
        final description = find.byKey(
          ValueKey('share-section-description-$section'),
        );
        expect(
          tester.getCenter(description).dy,
          closeTo(tester.getCenter(heading).dy, 1),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(ValueKey('share-section-description-$section')),
              )
              .maxLines,
          1,
        );
      }
      for (final field in [
        'scheda-composizione',
        'scheda-formato',
        'stile-preset',
        'sfondo-forma',
        'sfondo-colori',
        'firma-disposizione',
        'watermark-tipo',
      ]) {
        final label = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('$field-label')),
            matching: find.byType(Text),
          ),
        );
        final caption = find.byKey(ValueKey('$field-caption-0'));
        final captionStyle = tester.widget<Text>(caption).style!;
        expect(label.style!.fontSize, greaterThan(captionStyle.fontSize!));
        expect(captionStyle.color, AppColors.dark.muted);
        expect(
          tester.getTopLeft(caption).dy,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.byKey(ValueKey('$field-tile-0'))).dy,
          ),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo choices show graphical modes compatible with the composition',
    (tester) async {
      final photo = File(kAreaHeroArt[LifeArea.social]!.coverAsset)
          .absolute
          .path;
      expect(
        await tester.runAsync(() => PhotoStorage.readBytes(photo)),
        isNotNull,
      );
      await tester.pumpWidget(
        app(
          ShareComposerScreen(
            data: ShareContent(
              subject: ShareSubject.victory,
              title: 'Una vittoria',
              typeLabel: 'Vittoria',
              photos: [photo],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sfondo-foto-menu')), findsNothing);
      for (final mode in ['none', 'circle']) {
        final sample = tester.widget<Container>(
          find.byKey(ValueKey('share-photo-sample-$mode')),
        );
        final background = sample.decoration! as BoxDecoration;
        final foreground = sample.foregroundDecoration! as BoxDecoration;
        expect(foreground.borderRadius, background.borderRadius);
        expect(foreground.border, isNotNull);
      }
      final circleSample = find.byKey(
        const ValueKey('share-photo-sample-circle'),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: circleSample,
                matching: find.byType(ClipOval),
              ),
            )
            .width,
        lessThan(tester.getSize(circleSample).width * .4),
      );
      await tapVisible(tester, find.byKey(const ValueKey('sfondo-foto-1')));
      await tester.pumpAndSettle();
      List<Gradient> gradients(Finder scope) => tester
          .widgetList<DecoratedBox>(
            find.descendant(of: scope, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<Gradient>()
          .toList();
      final photoGradients = gradients(
        find.byKey(const ValueKey('share-photo-sample-background')),
      );
      expect(photoGradients, hasLength(2));
      expect(
        gradients(find.byKey(const ValueKey('share-preview'))),
        containsAll(photoGradients),
      );
      expect(find.byKey(const ValueKey('sfondo-foto-2')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('sfondo-foto-2')));
      await tester.pumpAndSettle();
      expect(choiceSelected(tester, 'sfondo-foto-2'), isTrue);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('scheda-composizione-2')),
      );
      await tester.pumpAndSettle();
      expect(choiceSelected(tester, 'sfondo-foto-0'), isTrue);
      await tapVisible(tester, find.byKey(const ValueKey('sfondo-foto-2')));
      await tester.pumpAndSettle();
      expect(choiceSelected(tester, 'sfondo-foto-2'), isTrue);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('scheda-composizione-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sfondo-foto-2')), findsNothing);
      expect(choiceSelected(tester, 'sfondo-foto-0'), isTrue);
      expect(tester.takeException(), isNull);
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
      await scrollToSection(tester, 1);
      await tester.pump();
      final artwork = find.byKey(const ValueKey('watermark-tipo-2'));
      await tester.ensureVisible(artwork);
      await tapVisible(tester, artwork);
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
      await scrollToSection(tester, 0);
      await tester.pump();
      final subject = find.byKey(const ValueKey('scheda-contenuto-menu'));
      await tester.ensureVisible(subject);
      await tapVisible(tester, subject);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Sociale').last);
      await tester.pumpAndSettle();
      await scrollToSection(tester, 1);
      await tester.pumpAndSettle();
      expect(asset(), kAreaHeroArt[LifeArea.social]!.coverAsset);
      await tapVisible(tester, find.byKey(const ValueKey('share-undo')));
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
      await scrollToSection(tester, 1);
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
        await tapVisible(tester, choice);
        await tester.pump();
        final original = background();
        final reverse = find.byKey(const ValueKey('share-reverse-colors'));
        await tester.ensureVisible(reverse);
        await tapVisible(tester, reverse);
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
        await tapVisible(tester, find.byKey(const ValueKey('share-undo')));
        await tester.pump();
        expect(background(), original);
        await tapVisible(tester, find.byKey(const ValueKey('share-redo')));
        await tester.pump();
        expect(background(), inverted);
        await tapVisible(tester, reverse);
        await tester.pump();
        expect(background(), original);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 740),
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
                return widget is InkWell &&
                    key is ValueKey<String> &&
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
            await tapVisible(tester, next);
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
          for (final category in [1, 2, 0]) {
            await scrollToSection(tester, category);
            await tester.pump();
            expect(
              find.byKey(ValueKey('share-section-$category')),
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
              findsOneWidget,
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
            await tapVisible(tester, choice);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${subject.name}, format $format, $size',
            );
          }
          expect(
            tester
                .widgetList<SingleChildScrollView>(
                  find.byType(SingleChildScrollView),
                )
                .every((scroll) => scroll.scrollDirection == Axis.vertical),
            isTrue,
          );
          final controlsRect = tester.getRect(
            find.byKey(const ValueKey('share-controls')),
          );
          final formats = [
            for (var i = 0; i < 5; i++)
              tester.getRect(find.byKey(ValueKey('scheda-formato-$i'))),
          ];
          expect(formats.map((rect) => rect.top).toSet(), hasLength(1));
          expect(formats.first.left, greaterThanOrEqualTo(controlsRect.left));
          expect(formats.last.right, lessThanOrEqualTo(controlsRect.right));
          for (var signature = 0; signature < 3; signature++) {
            await tapVisible(
              tester,
              find.byKey(ValueKey('firma-disposizione-$signature')),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${subject.name}, signature $signature, $size',
            );
          }
        }
      },
    );
  }
}
