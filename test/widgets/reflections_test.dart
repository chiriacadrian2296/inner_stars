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
  testWidgets('title and body are both required', (tester) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await tester.tap(find.byKey(const ValueKey('reflection-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.reflectionFree.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reflection-body')),
      'Un pensiero da ritrovare\nIl resto della riflessione',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pump();
    expect(repo.getAll(), isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('reflection-title')),
      'Un pensiero da ritrovare',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    expect(repo.getAll().single.title, 'Un pensiero da ritrovare');
    expect(repo.getAll().single.origin, ReflectionOrigin.free);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggested question stays separate through saving and editing', (
    tester,
  ) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await tester.tap(find.byKey(const ValueKey('reflection-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.reflectionSuggested.toUpperCase()));
    await tester.pumpAndSettle();
    final immediate = find.byKey(
      const ValueKey('reflection-immediate-question'),
    );
    final questions = LifeArea.physical.reflectionQuestions(strings);
    String selected() => questions.singleWhere(
      (q) => find
          .descendant(of: immediate, matching: find.text(q))
          .evaluate()
          .isNotEmpty,
    );
    final first = selected();
    await tester.tap(find.byKey(const ValueKey('reflection-another-question')));
    await tester.pumpAndSettle();
    final question = selected();
    expect(question, isNot(first));
    await tester.tap(find.byKey(const ValueKey('reflection-write-question')));
    await tester.pumpAndSettle();
    final title = find.descendant(
      of: find.byKey(const ValueKey('reflection-title')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(title).controller!.text, isEmpty);
    expect(find.text(question), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reflection-title')),
      'Il mio titolo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reflection-body')),
      'La mia risposta',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    final record = repo.getAll().single;
    expect(record.questionText, question);
    expect(record.questionId, '${questions.indexOf(question)}');
    expect(find.text(question), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reflection-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reflection-title')),
      'Titolo rivisto',
    );
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    expect(repo.find(record.id)!.questionText, question);
    expect(find.text(question), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('larger collection searches titles and body and groups months', (
    tester,
  ) async {
    final repo = await ReflectionRepository.create();
    for (var i = 0; i < 6; i++) {
      await repo.add(
        area: LifeArea.physical,
        title: 'Pensiero $i',
        body: i == 0 ? 'Energia da ritrovare' : 'Una risposta',
      );
    }
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await tester.pumpAndSettle();
    final month = MaterialLocalizations.of(
      tester.element(find.byType(AreaReflectionsScreen)),
    ).formatMonthYear(DateTime.now());
    expect(find.text(month), findsOneWidget);
    final search = find.byKey(const ValueKey('reflection-search'));
    await tester.enterText(search, 'ENERGIA');
    await tester.pumpAndSettle();
    expect(find.text('Pensiero 0'), findsOneWidget);
    expect(find.text('Pensiero 1'), findsNothing);
    await tester.enterText(search, 'Pensiero 2');
    await tester.pumpAndSettle();
    expect(
      find
          .text('Pensiero 2', findRichText: false)
          .evaluate()
          .where((element) => element.widget is Text),
      hasLength(1),
    );
    await tester.enterText(search, 'inesistente');
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionNoResults), findsOneWidget);
    await tester.tap(find.byTooltip(strings.clearSearchTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Pensiero 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explored questions open their reflections and allow another answer',
    (tester) async {
      final repo = await ReflectionRepository.create();
      await repo.add(
        area: LifeArea.physical,
        title: 'Riflessione precedente',
        body: 'Una prima risposta',
        origin: ReflectionOrigin.suggested,
        questionId: '0',
      );
      await tester.pumpWidget(
        app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
      );
      await tester.tap(find.byKey(const ValueKey('reflection-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.reflectionSuggested.toUpperCase()));
      await tester.pumpAndSettle();
      final group = LifeArea.physical.reflectionGroups(strings).first;
      await tester.ensureVisible(find.text(group.title));
      await tester.tap(find.text(group.title));
      await tester.pumpAndSettle();
      final explored = find.text(strings.reflectionExplored.toUpperCase());
      await tester.ensureVisible(explored);
      await tester.tap(explored);
      await tester.pumpAndSettle();
      expect(find.text('Riflessione precedente'), findsOneWidget);
      await tester.tap(find.text(strings.reflectionWrite.toUpperCase()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reflection-title')),
        'Una nuova riflessione',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reflection-body')),
        'Una nuova risposta',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.getAll(), hasLength(2));
      expect(repo.getAll().every((r) => r.questionId == '0'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor keeps text and focus when keyboard compacts the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repo = await ReflectionRepository.create();
    final question = LifeArea.physical
        .reflectionQuestions(strings)
        .reduce((a, b) => a.length > b.length ? a : b);
    await tester.pumpWidget(
      app(
        ReflectionEditorScreen(
          area: LifeArea.physical,
          repository: repo,
          questionId: '0',
          suggestedTitle: question,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final body = find.byKey(const ValueKey('reflection-body'));
    await tester.enterText(body, 'Il mio testo resta qui');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionNew), findsNothing);
    expect(find.text(question), findsNothing);
    final field = find.descendant(of: body, matching: find.byType(TextField));
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Il mio testo resta qui',
    );
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Il mio testo resta qui',
    );
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text(strings.reflectionRequired), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('reflection-title')),
        'Un pensiero',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reflection-body')),
        'Il mio testo',
      );
      await tester.pump(); // the save button lights up
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ReflectionDetailScreen), findsOneWidget);
      expect(repo.getAll().single.origin, ReflectionOrigin.free);
      final id = repo.getAll().single.id;
      expect(find.byType(ElevatedButton), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('reflection-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reflection-body')),
        'Testo rivisto',
      );
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.find(id)!.body, 'Testo rivisto');
      expect(find.text('Testo rivisto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reflection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.cancel.toUpperCase()).last);
      await tester.pumpAndSettle();
      expect(repo.find(id), isNotNull);
      await tester.tap(find.byKey(const ValueKey('reflection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.deleteStarAction.toUpperCase()).last);
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
