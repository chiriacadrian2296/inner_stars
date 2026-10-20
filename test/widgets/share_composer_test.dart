import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/models/share_content.dart';
import 'package:inner_stars/screens/share_composer_screen.dart';
import 'package:inner_stars/screens/share_preview_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';

const strings = StringsIt();
Widget app(Widget home) => StringsScope(
  strings: strings,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

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
      expect(find.text(record.title), findsOneWidget);
      expect(find.text(record.body), findsOneWidget);
      expect(find.text(LifeArea.social.displayName(strings)), findsOneWidget);
      expect(find.text('Salute'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-reflection-excerpt')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('share-excerpt-field')),
        'Solo un estratto',
      );
      await tester.tap(find.text(strings.saveChanges.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('Solo un estratto'), findsOneWidget);
      expect(record.body, 'Il testo originale');
      await tester.tap(find.byKey(const ValueKey('share-category-1')));
      await tester.pump();
      await tester.ensureVisible(find.text('Testo'));
      await tester.tap(find.text('Testo'));
      await tester.pump();
      expect(find.text('Solo un estratto'), findsNothing);
      expect(record.body, 'Il testo originale');
      await tester.tap(find.byKey(const ValueKey('share-category-3')));
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
      await tester.tap(find.byKey(const ValueKey('share-category-2')));
      await tester.pump();
      expect(find.byKey(const ValueKey('sfondo-foto-menu')), findsNothing);
      expect(find.byKey(const ValueKey('watermark-misura-menu')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('watermark-tipo-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logo App'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('watermark-misura-menu')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sfondo-colori-3')));
      await tester.pump();
      expect(find.text('Colori · Tramonto'), findsOneWidget);
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
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('scheda-contenuto-menu')),
            findsNothing,
          );
          expect(find.text('7 stelle'), findsNothing);
          expect(find.text('Serie di 21 giorni'), findsNothing);
          for (var i = 0; i < 5; i++) {
            final next = find.byKey(const ValueKey('scheda-composizione-next'));
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
            await tester.tap(find.byKey(ValueKey('share-category-$category')));
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
              find.byKey(const ValueKey('scheda-composizione-next')),
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
