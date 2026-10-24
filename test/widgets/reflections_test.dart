import '../support/rich_text_input.dart';

import 'package:inner_stars/widgets/app_rich_text_editor.dart';
import 'package:inner_stars/widgets/vision_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/screens/area_reflections_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/share_arrangement.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';

const strings = StringsIt();
Widget app(Widget home) => StringsScope(
  strings: strings,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

Future<void> startReflection(
  WidgetTester tester, {
  required bool suggested,
}) async {
  await tester.tap(find.byKey(const ValueKey('reflection-new')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(
      ValueKey(suggested ? 'reflection-new-suggested' : 'reflection-new-free'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('title and body are both required', (tester) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await startReflection(tester, suggested: false);
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-body')),
      'Un pensiero da ritrovare\nIl resto della riflessione',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pump();
    expect(repo.getAll(), isEmpty);
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-title')),
      'Un pensiero da ritrovare',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    expect(repo.getAll().single.title, 'Un pensiero da ritrovare');
    expect(repo.getAll().single.origin, ReflectionOrigin.free);
    await tester.tap(find.byKey(const ValueKey('reflection-next-not-now')));
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionDetailScreen), findsNothing);
    expect(find.byType(ReflectionEditorScreen), findsNothing);
    expect(find.byKey(const ValueKey('reflection-new')), findsOneWidget);
    expect(find.text(strings.reflectionNextStepTitle), findsNothing);
    expect(find.text('Un pensiero da ritrovare'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggested question becomes the topic and stays linked', (
    tester,
  ) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await startReflection(tester, suggested: true);
    final immediate = find.byKey(
      const ValueKey('reflection-immediate-question'),
    );
    final immediateContainer = tester.widget<Container>(immediate);
    expect((immediateContainer.decoration! as BoxDecoration).gradient, isNull);
    expect(find.byTooltip(strings.reflectionNextQuestion), findsOneWidget);
    final nextRect = tester.getRect(
      find.byKey(const ValueKey('reflection-next-question')),
    );
    final previousRect = tester.getRect(
      find.byKey(const ValueKey('reflection-previous-question')),
    );
    expect(
      (previousRect.left + nextRect.right) / 2,
      closeTo(tester.getCenter(immediate).dx, 0.1),
    );
    final questions = LifeArea.physical.reflectionQuestions(strings);
    String selected() => questions.singleWhere(
      (q) => find
          .descendant(of: immediate, matching: find.text(q))
          .evaluate()
          .isNotEmpty,
    );
    final first = selected();
    await tester.tap(find.byKey(const ValueKey('reflection-next-question')));
    await tester.pumpAndSettle();
    final question = selected();
    final firstIndex = questions.indexOf(first);
    expect(question, questions[(firstIndex + 1) % questions.length]);
    await tester.tap(
      find.byKey(const ValueKey('reflection-previous-question')),
    );
    await tester.pumpAndSettle();
    expect(selected(), first);
    await tester.tap(
      find.byKey(const ValueKey('reflection-previous-question')),
    );
    await tester.pumpAndSettle();
    expect(selected(), questions[(firstIndex - 1) % questions.length]);
    await tester.tap(find.byKey(const ValueKey('reflection-next-question')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reflection-next-question')));
    await tester.pumpAndSettle();
    expect(selected(), question);
    await tester.tap(find.byKey(const ValueKey('reflection-write-question')));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('reflection-title'));
    expect(tester.widget<TextField>(title).controller!.text, question);
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-title')),
      'Il mio titolo',
    );
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-body')),
      'La mia risposta',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionNextStepTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reflection-next-not-now')));
    await tester.pumpAndSettle();
    final record = repo.getAll().single;
    expect(record.questionText, question);
    expect(record.questionId, '${questions.indexOf(question)}');
    expect(find.byType(ReflectionDetailScreen), findsNothing);
    await tester.tap(find.text('Il mio titolo'));
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reflection-edit')));
    await tester.pumpAndSettle();
    await enterEditorText(
      tester,
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
    expect(find.text(strings.reflectionLatestLabel), findsOneWidget);
    expect(find.text(strings.reflectionEarlierLabel), findsOneWidget);
    final month = MaterialLocalizations.of(
      tester.element(find.byType(AreaReflectionsScreen)),
    ).formatMonthYear(DateTime.now());
    expect(find.text(month), findsOneWidget);
    final search = find.byKey(const ValueKey('reflection-search'));
    await enterEditorText(tester, search, 'ENERGIA');
    await tester.pumpAndSettle();
    expect(find.text('Pensiero 0'), findsOneWidget);
    expect(find.text('Pensiero 1'), findsNothing);
    await enterEditorText(tester, search, 'Pensiero 2');
    await tester.pumpAndSettle();
    expect(
      find
          .text('Pensiero 2', findRichText: false)
          .evaluate()
          .where((element) => element.widget is Text),
      hasLength(1),
    );
    await enterEditorText(tester, search, 'inesistente');
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionNoResults), findsOneWidget);
    await tester.tap(find.byTooltip(strings.clearSearchTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Pensiero 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post-save star action opens the shared all-kind creator', (
    tester,
  ) async {
    final repo = await ReflectionRepository.create();
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await startReflection(tester, suggested: false);
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-title')),
      'Un passo concreto',
    );
    await enterEditorText(
      tester,
      find.byKey(const ValueKey('reflection-body')),
      'Trasformo la riflessione in azione.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reflection-next-star')));
    await tester.pumpAndSettle();
    final creator = tester.widget<StarFormScreen>(find.byType(StarFormScreen));
    expect(creator.startWithoutSelection, isTrue);
    expect(creator.presetArea, LifeArea.physical);
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
      final explored = find.text(strings.reflectionExplored).last;
      await tester.ensureVisible(explored);
      await tester.tap(explored);
      await tester.pumpAndSettle();
      expect(find.text('Riflessione precedente'), findsOneWidget);
      await tester.tap(find.text(strings.reflectionWrite.toUpperCase()));
      await tester.pumpAndSettle();
      await enterEditorText(
        tester,
        find.byKey(const ValueKey('reflection-title')),
        'Una nuova riflessione',
      );
      await enterEditorText(
        tester,
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

  testWidgets('explored moment separates status from one row of actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await ReflectionRepository.create();
    final questions = LifeArea.physical.reflectionQuestions(strings);
    for (var i = 0; i < questions.length; i++) {
      await repo.add(
        area: LifeArea.physical,
        title: 'Riflessione $i',
        body: 'Una risposta',
        origin: ReflectionOrigin.suggested,
        questionId: '$i',
      );
    }
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await startReflection(tester, suggested: true);
    final panel = find.byKey(const ValueKey('reflection-immediate-question'));
    final status = find.descendant(
      of: panel,
      matching: find.text(strings.reflectionExplored),
    );
    expect(status, findsOneWidget);
    expect(
      find.ancestor(of: status, matching: find.byType(TextButton)),
      findsNothing,
    );
    final next = find.byKey(const ValueKey('reflection-next-question'));
    final read = find.byKey(const ValueKey('reflection-read-question'));
    final write = find.byKey(const ValueKey('reflection-write-question'));
    expect(tester.getTopLeft(next).dy, tester.getTopLeft(read).dy);
    expect(tester.getTopLeft(read).dy, tester.getTopLeft(write).dy);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(read);
    await tester.tap(read);
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionRelatedDescription), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question navigation stays fixed across lengths and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await ReflectionRepository.create();
    await repo.add(
      area: LifeArea.physical,
      title: 'Una riflessione',
      body: 'Una risposta',
      origin: ReflectionOrigin.suggested,
      questionId: '0',
    );
    await tester.pumpWidget(
      app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
    );
    await startReflection(tester, suggested: true);
    final panel = find.byKey(const ValueKey('reflection-immediate-question'));
    final previous = find.byKey(const ValueKey('reflection-previous-question'));
    final next = find.byKey(const ValueKey('reflection-next-question'));
    final read = find.byKey(const ValueKey('reflection-read-question'));
    final write = find.byKey(const ValueKey('reflection-write-question'));
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    final previousRect = tester.getRect(previous);
    final nextRect = tester.getRect(next);
    final panelSize = tester.getSize(panel);
    var sawRead = false;
    var sawWriteOnly = false;
    final questions = LifeArea.physical.reflectionQuestions(strings);
    for (var i = 0; i <= questions.length; i++) {
      expect(tester.getRect(previous), previousRect);
      expect(tester.getRect(next), nextRect);
      expect(tester.getSize(panel), panelSize);
      if (read.evaluate().isEmpty) {
        sawWriteOnly = true;
        expect(
          tester.getCenter(write).dx,
          closeTo(tester.getCenter(panel).dx, 0.1),
        );
      } else {
        sawRead = true;
      }
      expect(tester.takeException(), isNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(sawRead, isTrue);
    expect(sawWriteOnly, isTrue);
  });

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
    await enterEditorText(tester, body, 'Il mio testo resta qui');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.text(strings.reflectionNew), findsNothing);
    expect(find.text(question), findsOneWidget);
    final field = body;
    expect(
      tester.widget<AppRichTextEditor>(field).controller.plainText,
      'Il mio testo resta qui',
    );
    expect(tester.widget<AppRichTextEditor>(field).focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    expect(
      tester.widget<AppRichTextEditor>(field).controller.plainText,
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
      expect(find.byKey(const ValueKey('reflection-new')), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
      expect(find.byKey(const ValueKey('reflection-new-free')), findsNothing);
      expect(
        find.byKey(const ValueKey('reflection-new-suggested')),
        findsNothing,
      );
      await startReflection(tester, suggested: false);
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.getAll(), isEmpty);
      expect(find.text(strings.reflectionRequired), findsNothing);
      await enterEditorText(
        tester,
        find.byKey(const ValueKey('reflection-title')),
        'Un pensiero',
      );
      await enterEditorText(
        tester,
        find.byKey(const ValueKey('reflection-body')),
        'Il mio testo',
      );
      await tester.pump(); // the save button lights up
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(find.text(strings.reflectionNextStepTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reflection-next-star')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reflection-next-vision')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reflection-next-moodboard')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('reflection-next-not-now')));
      await tester.pumpAndSettle();
      expect(find.byType(ReflectionDetailScreen), findsNothing);
      expect(find.byKey(const ValueKey('reflection-new')), findsOneWidget);
      await tester.tap(find.text('Un pensiero'));
      await tester.pumpAndSettle();
      expect(find.byType(ReflectionDetailScreen), findsOneWidget);
      expect(repo.getAll().single.origin, ReflectionOrigin.free);
      expect(
        find.byKey(const ValueKey('reflection-follow-star')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('reflection-follow-vision')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('reflection-follow-moodboard')),
        findsNothing,
      );
      final id = repo.getAll().single.id;
      expect(find.byType(ElevatedButton), findsNWidgets(4));
      expect(
        tester
            .widgetList<ElevatedButton>(find.byType(ElevatedButton))
            .map((button) => button.key),
        const [
          ValueKey('reflection-edit'),
          ValueKey('reflection-share'),
          ValueKey('reflection-continue'),
          ValueKey('reflection-delete'),
        ],
      );
      final editTop = tester
          .getTopLeft(find.byKey(const ValueKey('reflection-edit')))
          .dy;
      final shareTop = tester
          .getTopLeft(find.byKey(const ValueKey('reflection-share')))
          .dy;
      final developTop = tester
          .getTopLeft(find.byKey(const ValueKey('reflection-continue')))
          .dy;
      final deleteTop = tester
          .getTopLeft(find.byKey(const ValueKey('reflection-delete')))
          .dy;
      expect(shareTop, editTop);
      expect(developTop, editTop);
      expect(deleteTop, greaterThan(editTop));
      expect(
        tester.getCenter(find.byKey(const ValueKey('reflection-delete'))).dx,
        closeTo(195, 0.1),
      );
      tester.view.physicalSize = const Size(1000, 844);
      await tester.pumpAndSettle();
      final wideDelete = tester.getTopLeft(
        find.byKey(const ValueKey('reflection-delete')),
      );
      final wideEdit = tester.getTopLeft(
        find.byKey(const ValueKey('reflection-edit')),
      );
      final wideShare = tester.getTopLeft(
        find.byKey(const ValueKey('reflection-share')),
      );
      final wideDevelop = tester.getTopLeft(
        find.byKey(const ValueKey('reflection-continue')),
      );
      expect(wideEdit.dy, wideDelete.dy);
      expect(wideShare.dy, wideDelete.dy);
      expect(wideDevelop.dy, wideDelete.dy);
      expect(wideDelete.dx, lessThan(wideEdit.dx));
      expect(wideEdit.dx, lessThan(wideShare.dx));
      expect(wideShare.dx, lessThan(wideDevelop.dx));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reflection-continue')));
      await tester.pumpAndSettle();
      expect(find.text(strings.reflectionNextStepTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reflection-next-star')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reflection-next-vision')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reflection-next-moodboard')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('reflection-next-not-now')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reflection-edit')));
      await tester.pumpAndSettle();
      await enterEditorText(
        tester,
        find.byKey(const ValueKey('reflection-body')),
        'Testo rivisto',
      );
      await tester.tap(find.byKey(const ValueKey('reflection-save')));
      await tester.pumpAndSettle();
      expect(repo.find(id)!.body, 'Testo rivisto');
      expect(
        tester.widget<VisionMarkdown>(find.byType(VisionMarkdown)).data,
        'Testo rivisto',
      );
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

  testWidgets(
    'untouched suggested reflection closes without a discard warning',
    (tester) async {
      final repo = await ReflectionRepository.create();
      await tester.pumpWidget(
        app(AreaReflectionsScreen(area: LifeArea.physical, repository: repo)),
      );
      await startReflection(tester, suggested: true);
      await tester.tap(find.byKey(const ValueKey('reflection-write-question')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ReflectionEditorScreen), findsNothing);
      expect(find.byType(AreaReflectionsScreen), findsOneWidget);
      expect(repo.getAll(), isEmpty);
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
    await startReflection(tester, suggested: false);
    await enterEditorText(
      tester,
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
        expect(
          tester.widget<VisionMarkdown>(find.byType(VisionMarkdown)).data,
          record.body,
        );
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
