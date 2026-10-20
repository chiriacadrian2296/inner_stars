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
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final choice = find.byKey(ValueKey(key));
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String key) => tester
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

Future<void> _subject(WidgetTester tester, String label) async {
  await _tap(tester, 'scheda-contenuto-menu');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lab exposes sample subjects through the current composer', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));
    for (final title in ['Scheda', 'Sfondo', 'Firma']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    await _subject(tester, 'Moodboard');
    expect(find.text('Collage'), findsOneWidget);
    expect(find.text('Celebrazione'), findsNothing);
    await _tap(tester, 'scheda-formato-4');
    expect(_selected(tester, 'scheda-formato-4'), isTrue);
    await _tap(tester, 'stile-preset-1');
    expect(_selected(tester, 'stile-preset-1'), isTrue);
    expect(_selected(tester, 'scheda-formato-4'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lab styles and individual visual choices support undo', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));
    await _tap(tester, 'stile-preset-4');
    await _tap(tester, 'sfondo-forma-1');
    await _tap(tester, 'sfondo-colori-11');
    await _tap(tester, 'firma-disposizione-2');
    await _tap(tester, 'watermark-tipo-1');
    expect(_selected(tester, 'watermark-tipo-1'), isTrue);
    expect(_selected(tester, 'firma-disposizione-2'), isTrue);
    expect(_selected(tester, 'sfondo-colori-11'), isTrue);
    expect(_selected(tester, 'stile-preset-4'), isFalse);
    expect(find.byKey(const ValueKey('sfondo-foto-label')), findsNothing);
    expect(find.byKey(const ValueKey('watermark-misura-menu')), findsNothing);
    await _tap(tester, 'share-undo');
    expect(_selected(tester, 'watermark-tipo-0'), isTrue);
    await _tap(tester, 'share-redo');
    expect(_selected(tester, 'watermark-tipo-1'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every sample exposes three usable compositions', (tester) async {
    await _pump(tester, const Size(1440, 1000));
    for (final label in [
      'Vittoria',
      'Obiettivo',
      'Abitudine',
      'Progetto',
      'Visione',
      'Moodboard',
      'Citazione',
    ]) {
      await _subject(tester, label);
      expect(find.byKey(const ValueKey('scheda-composizione-3')), findsNothing);
      for (var composition = 0; composition < 3; composition++) {
        await _tap(tester, 'scheda-composizione-$composition');
        expect(_selected(tester, 'scheda-composizione-$composition'), isTrue);
        expect(
          tester.takeException(),
          isNull,
          reason: '$label, composition $composition',
        );
      }
    }
  });

  testWidgets(
    'narrow lab uses one vertical panel and a compact preview toggle',
    (tester) async {
      await _pump(tester, const Size(390, 844));
      final preview = find.byKey(const ValueKey('share-preview'));
      final original = tester.getSize(preview);
      await _tap(tester, 'share-toggle-preview');
      expect(tester.getSize(preview).height, lessThan(original.height));
      await tester.ensureVisible(find.byKey(const ValueKey('share-section-2')));
      await tester.pumpAndSettle();
      expect(find.text('Firma'), findsOneWidget);
      await _tap(tester, 'firma-disposizione-0');
      expect(_selected(tester, 'firma-disposizione-0'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
