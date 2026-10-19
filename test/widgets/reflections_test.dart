import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/screens/area_reflections_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/share_arrangement.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';

const strings = StringsIt();
Widget app(Widget home) => StringsScope(
  strings: strings,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'create free reflection, edit, cancel deletion, then permanently delete',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await ReflectionRepository.create();
      await tester.pumpWidget(
        app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
      );
      expect(find.text(strings.reflectionEmpty), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reflection-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.reflectionFree.toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.getAll(), isEmpty);
      expect(find.text(strings.reflectionRequired), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const ValueKey('reflection-title')),
        'Un pensiero',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reflection-body')),
        'Il mio testo',
      );
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ReflectionDetailScreen), findsOneWidget);
      expect(repo.getAll().single.origin, ReflectionOrigin.free);
      final id = repo.getAll().single.id;
      await tester.tap(find.byTooltip(strings.starQuickLookEditAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reflection-body')),
        'Testo rivisto',
      );
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.find(id)!.body, 'Testo rivisto');
      expect(find.text('Testo rivisto'), findsOneWidget);
      await tester.tap(find.byTooltip(strings.deleteStarAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.cancel.toUpperCase()).last);
      await tester.pumpAndSettle();
      expect(repo.find(id), isNotNull);
      await tester.tap(find.byTooltip(strings.deleteStarAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.deleteStarAction.toUpperCase()));
      await tester.pumpAndSettle();
      expect(repo.getAll(), isEmpty);
      expect(repo.getAll(includeDeleted: true).single.deleted, isTrue);
      expect(find.byType(AreaReflectionsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back asks before discarding an unsaved reflection', (
    tester,
  ) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await tester.tap(find.byKey(const ValueKey('reflection-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.reflectionFree.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reflection-title')),
      'Draft',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(strings.discardChangesConfirmTitle), findsOneWidget);
    await tester.tap(find.text(strings.cancel.toUpperCase()).last);
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.discardChangesAction.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionEditorScreen), findsNothing);
    expect(repo.getAll(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final arrangement in ShareArrangement.values) {
    testWidgets(
      'long reflection card fits ${arrangement.name} and supports hidden body',
      (tester) async {
        final now = DateTime.utc(2026);
        final record = Reflection(
          id: 'test',
          area: LifeArea.physical,
          title: List.filled(30, 'Titolo').join(' '),
          body: List.filled(400, 'Testo').join(' '),
          origin: ReflectionOrigin.free,
          createdAt: now,
          updatedAt: now,
        );
        await tester.pumpWidget(
          app(
            Center(
              child: SizedBox(
                width: 320,
                height: 480,
                child: ShareArrangementScope(
                  arrangement: arrangement,
                  child: ShareableReflectionCard(reflection: record),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(record.body), findsOneWidget);
        await tester.pumpWidget(
          app(
            Center(
              child: SizedBox(
                width: 320,
                height: 480,
                child: ShareArrangementScope(
                  arrangement: arrangement,
                  child: ShareableReflectionCard(
                    reflection: record,
                    showBody: false,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(record.body), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
