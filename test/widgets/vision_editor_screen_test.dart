import '../support/rich_text_input.dart';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/screens/area_reflections_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/app_rich_text_editor.dart';
import 'package:inner_stars/widgets/vision_markdown.dart';
import 'package:inner_stars/widgets/shareable_reflection_card.dart';
import 'package:inner_stars/models/reflection.dart';

const s = StringsIt();
Widget app(Widget home) => StringsScope(
  strings: s,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);
AppRichTextEditor body(WidgetTester tester) =>
    tester.widget<AppRichTextEditor>(find.byType(AppRichTextEditor));
Future<void> type(WidgetTester tester, String value) async {
  await enterRichText(tester, body(tester), value);
}

Future<void> tool(WidgetTester tester, String name) async {
  await tester.pump();
  final finder = find.byTooltip(name);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final reflection in [false, true]) {
    final kind = reflection ? 'reflection' : 'vision';
    Future<(AreaVisionRepository, ReflectionRepository)> open(
      WidgetTester tester,
    ) async {
      final visions = await AreaVisionRepository.create();
      final reflections = await ReflectionRepository.create();
      await visions.setVision(LifeArea.physical, 'Testo iniziale');
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => reflection
                        ? ReflectionEditorScreen(
                            area: LifeArea.physical,
                            repository: reflections,
                          )
                        : VisionEditorScreen(
                            area: LifeArea.physical,
                            repository: visions,
                          ),
                  ),
                ),
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      if (reflection) {
        await tester.enterText(
          find.byKey(const ValueKey('reflection-title')),
          'Titolo',
        );
      }
      return (visions, reflections);
    }

    testWidgets('$kind: keyboard typing composes B/I/U and turns them off', (
      tester,
    ) async {
      final (visions, reflections) = await open(tester);
      await type(tester, '');
      final c = body(tester).controller;
      for (final name in [s.visionBold, s.visionItalic, s.visionUnderline]) {
        await tool(tester, name);
        expect(body(tester).focusNode.hasFocus, true);
      }
      await enterRichText(tester, body(tester), 'asd');
      await tester.pump();
      for (final key in ['b', 'i', 'u']) {
        expect(c.document.toDelta().first.attributes, containsPair(key, true));
      }
      for (final name in [s.visionBold, s.visionItalic, s.visionUnderline]) {
        await tool(tester, name);
      }
      await enterRichText(tester, body(tester), ' normale', append: true);
      await tester.pump();
      expect(c.plainText, 'asd normale');
      expect(c.document.collectStyle(4, 7).inlineAttributes, isEmpty);
      final expected = c.document.toJson();
      await tester.tap(find.text(s.saveChanges.toUpperCase()));
      await tester.pumpAndSettle();
      final saved = reflection
          ? reflections.getAll().single.richText
          : visions.getRichText(LifeArea.physical);
      expect(saved, isNotNull);
      expect(saved!.toParchment().toJson(), expected);
      expect(find.text('Apri'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$kind: repeated headings preserve content, selection and focus',
      (tester) async {
        await open(tester);
        await type(tester, 'Il mio testo');
        final c = body(tester).controller;
        c.updateSelection(const TextSelection.collapsed(offset: 5));
        for (final label in [
          '${s.visionHeading} 1',
          '${s.visionHeading} 2',
          '${s.visionHeading} 1',
          s.editorNormal,
        ]) {
          await tool(tester, s.visionHeading);
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(c.plainText, 'Il mio testo');
          expect(c.selection.baseOffset, 5);
          expect(body(tester).focusNode.hasFocus, true);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$kind: undo and redo preserve content and formatting', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'Testo');
      final c = body(tester).controller;
      await tester.pump(const Duration(milliseconds: 600));
      c.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 5));
      await tool(tester, s.visionBold);
      await tester.pump(const Duration(milliseconds: 600));
      await tool(tester, s.visionUndo);
      expect(c.plainText, 'Testo');
      expect(
        c.document.collectStyle(0, 5).containsSame(ParchmentAttribute.bold),
        false,
      );
      await tool(tester, s.visionRedo);
      expect(
        c.document.collectStyle(0, 5).containsSame(ParchmentAttribute.bold),
        true,
      );
    });

    testWidgets(
      '$kind: link dialog retains selection and applies/removes link',
      (tester) async {
        await open(tester);
        await type(tester, 'Collegamento');
        final c = body(tester).controller;
        c.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 12));
        await tool(tester, s.editorLink);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'https://example.com',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(s.saveChanges.toUpperCase()),
          ),
        );
        await tester.pumpAndSettle();
        expect(c.plainText, 'Collegamento');
        expect(
          c.document.collectStyle(0, 12).get(ParchmentAttribute.link)?.value,
          'https://example.com',
        );
        expect(body(tester).focusNode.hasFocus, true);
        await tool(tester, s.editorLink);
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.editorRemoveLink.toUpperCase()));
        await tester.pumpAndSettle();
        expect(
          c.document.collectStyle(0, 12).contains(ParchmentAttribute.link),
          false,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$kind: formatting-only draft triggers discard confirmation', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'Testo iniziale');
      final c = body(tester).controller;
      c.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 5));
      await tool(tester, s.visionBold);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(s.cancel.toUpperCase()));
      await tester.pumpAndSettle();
      expect(c.plainText, 'Testo iniziale');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.discardChangesAction.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('Apri'), findsOneWidget);
    });

    testWidgets(
      '$kind: narrow mobile keyboard leaves usable editor and bottom toolbar',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await open(tester);
        await type(tester, List.filled(80, 'Un paragrafo.\n').join());
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(AppRichTextEditor)).height,
          greaterThan(40),
        );
        expect(
          tester.getBottomLeft(find.byType(AppRichTextToolbar)).dy,
          closeTo(360, 1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'touch selection shows the app context menu and clipboard paste works',
    (tester) async {
      var clipboard = 'Incollato\nSeconda riga';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard.isNotEmpty};
          }
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = await AreaVisionRepository.create();
      await tester.pumpWidget(
        app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
      );
      await type(tester, 'Testo da copiare');
      final editor = body(tester);
      final rect = tester.getRect(find.byType(AppRichTextEditor));
      await tester.longPressAt(rect.topLeft + const Offset(50, 36));
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), null);
      final state = editor.editorKey.currentState!;
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 16),
      );
      await state.pasteText(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(editor.controller.plainText, 'Incollato\nSeconda riga');
    },
  );

  testWidgets(
    'divider handles a reverse selection without deleting surrounding text',
    (tester) async {
      final repo = await AreaVisionRepository.create();
      await tester.pumpWidget(
        app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
      );
      await type(tester, 'Prima\nTogli\nDopo');
      final c = body(tester).controller;
      c.updateSelection(const TextSelection(baseOffset: 11, extentOffset: 6));
      await tool(tester, s.visionDivider);
      expect(c.plainText, contains('Prima'));
      expect(c.plainText, contains('Dopo'));
      expect(c.plainText, isNot(contains('Togli')));
      expect(c.snapshot.operations.any((op) => op['insert'] is Map), true);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('blank space below the first line can focus the editor', (
    tester,
  ) async {
    final repo = await AreaVisionRepository.create();
    await tester.pumpWidget(
      app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(AppRichTextEditor));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 30));
    await tester.pump();
    expect(body(tester).focusNode.hasFocus, true);
  });

  testWidgets('clearing a formatted vision removes the stored record', (
    tester,
  ) async {
    final repo = await AreaVisionRepository.create();
    await repo.setVision(LifeArea.physical, '# Vecchia visione');
    await tester.pumpWidget(
      app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
    );
    await type(tester, '');
    await tester.tap(find.text(s.saveChanges.toUpperCase()));
    await tester.pumpAndSettle();
    expect(repo.getVision(LifeArea.physical), '');
    expect(repo.getRichText(LifeArea.physical), null);
  });

  testWidgets(
    'outside title click unfocuses editor; toolbar and link dialog keep editing appearance',
    (tester) async {
      final repo = await ReflectionRepository.create();
      await tester.pumpWidget(
        app(ReflectionEditorScreen(area: LifeArea.physical, repository: repo)),
      );
      await type(tester, 'Testo');
      final editor = body(tester);
      bool dimmed() => tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .any((w) => w.opacity == 0.68);
      expect(dimmed(), true);
      await tool(tester, s.visionBold);
      expect(editor.focusNode.hasFocus, true);
      expect(dimmed(), true);
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tool(tester, s.editorLink);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(dimmed(), true);
      await tester.tap(find.text(s.cancel.toUpperCase()));
      await tester.pumpAndSettle();
      expect(editor.focusNode.hasFocus, true);
      await tester.tap(find.byKey(const ValueKey('reflection-title')));
      await tester.pumpAndSettle();
      expect(editor.focusNode.hasFocus, false);
      expect(dimmed(), false);
    },
  );

  testWidgets(
    'reflection exceeding 5000 visible characters keeps text but disables save',
    (tester) async {
      final repo = await ReflectionRepository.create();
      await tester.pumpWidget(
        app(ReflectionEditorScreen(area: LifeArea.physical, repository: repo)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('reflection-title')),
        'Titolo',
      );
      await type(tester, 'a' * 5001);
      expect(body(tester).controller.characterCount, 5001);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('reflection-save')),
            )
            .onPressed,
        null,
      );
      expect(find.textContaining(s.editorTooLong), findsOneWidget);
      await type(tester, 'a' * 5000);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('reflection-save')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('desktop toolbar appears above the document', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repo = await AreaVisionRepository.create();
    await tester.pumpWidget(
      app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
    );
    expect(
      tester.getBottomLeft(find.byType(AppRichTextToolbar)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(AppRichTextEditor)).dy),
    );
    expect(find.byType(AppBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'read-only document and long sharing card render without interactive controls',
    (tester) async {
      final c = AppRichTextController(
        legacy: '<u>***Testo***</u>\n\n${'Paragrafo\n' * 80}',
      );
      final snap = c.snapshot;
      c.dispose();
      final now = DateTime.utc(2026);
      final r = Reflection(
        id: 'r',
        area: LifeArea.physical,
        title: 'Titolo',
        body: snap.legacyText,
        richText: snap,
        origin: ReflectionOrigin.free,
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        app(
          Center(
            child: SizedBox(
              width: 350,
              height: 500,
              child: ShareableReflectionCard(reflection: r),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<VisionMarkdown>(find.byType(VisionMarkdown));
      expect(view.interactive, false);
      expect(
        tester.widget<FleatherEditor>(find.byType(FleatherEditor)).showCursor,
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
