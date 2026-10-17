import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/screens/share_lab_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const ShareLabScreen()),
  );
}

/// Taps a stepper's right arrow [times] times.
Future<void> _next(WidgetTester tester, String field, [int times = 1]) async {
  final finder = find.byKey(ValueKey('$field-next'));
  for (var i = 0; i < times; i++) {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }
}

void main() {
  testWidgets('composer groups options in blocks with steppers', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));

    expect(find.text('CONDIVIDI'), findsOneWidget);
    for (final block in [
      'SCHEDA',
      'STILE',
      'SFONDO',
      'TESTO E DATI',
      'FIRMA',
      'WATERMARK',
    ]) {
      expect(find.text(block), findsOneWidget);
    }
    expect(find.text('Celebrazione'), findsOneWidget);

    // Arrows flip to the next subject and its own compositions.
    await _next(tester, 'scheda-contenuto', 5); // moodboard
    expect(find.text('Moodboard'), findsOneWidget);
    expect(find.text('Collage'), findsOneWidget);
    expect(find.text('Celebrazione'), findsNothing);

    // The dropdown lists every choice.
    await tester.tap(find.byKey(const ValueKey('scheda-formato-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Orizzontale · 16:9'), findsOneWidget);
    await tester.tap(find.text('Orizzontale · 16:9'));
    await tester.pumpAndSettle();

    // A manual change turns the style into "Personalizzato".
    expect(find.text('Personalizzato'), findsOneWidget);
    await _next(tester, 'stile-preset');
    expect(find.text('Dorato'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('style, background, signature and watermark options all work', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));

    await _next(tester, 'stile-preset', 6);
    await _next(tester, 'stile-marchio', 5);
    await _next(tester, 'stile-titolo', 5);
    await _next(tester, 'sfondo-forma', 7);
    await _next(tester, 'sfondo-colori', 15);
    await _next(tester, 'sfondo-foto', 4);

    await _next(tester, 'firma-mostra', 5);
    await _next(tester, 'firma-mostra', 1); // solo logo
    await _next(tester, 'firma-logo', 3);
    await _next(tester, 'firma-misura', 3);
    await _next(tester, 'firma-colore-logo', 6);
    await _next(tester, 'firma-mostra', 2); // logo e nome
    await _next(tester, 'firma-mostra', 1); // logo sopra nome
    await _next(tester, 'firma-posizione', 9);
    await _next(tester, 'firma-colore-nome', 6);
    await _next(tester, 'watermark-tipo', 12); // every type and area
    await _next(tester, 'watermark-tipo', 8); // an area artwork
    await _next(tester, 'watermark-misura', 3);
    await _next(tester, 'watermark-colore', 6);

    await tester.ensureVisible(find.text('Descrizione'));
    await tester.tap(find.text('Descrizione'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('every subject and composition lays out in every format', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));

    for (var subject = 0; subject < 7; subject++) {
      for (var format = 0; format < 5; format++) {
        for (var composition = 0; composition < 5; composition++) {
          expect(
            tester.takeException(),
            isNull,
            reason:
                'subject $subject · format $format · composition $composition',
          );
          await _next(tester, 'scheda-composizione');
        }
        await _next(tester, 'scheda-formato');
      }
      await _next(tester, 'scheda-contenuto');
    }
  });

  testWidgets('narrow screens get a sideways bar of blocks', (tester) async {
    await _pump(tester, const Size(390, 844));

    expect(find.text('SCHEDA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('FIRMA'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('FIRMA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
