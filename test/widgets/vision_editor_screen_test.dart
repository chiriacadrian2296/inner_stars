import '../support/rich_text_input.dart';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as fleather_ui;
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/widgets/logo_watermark.dart';
import 'package:inner_stars/widgets/area_section_header.dart';
import 'package:inner_stars/widgets/app_field.dart';
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

void testDesktopWidgets(String name, WidgetTesterCallback callback) =>
    testWidgets(
      name,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

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

    testDesktopWidgets(
      '$kind: keyboard typing composes B/I/U and turns them off',
      (tester) async {
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
          expect(
            c.document.toDelta().first.attributes,
            containsPair(key, true),
          );
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
      },
    );

    testDesktopWidgets(
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

    testDesktopWidgets('$kind: undo and redo preserve content and formatting', (
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

    testDesktopWidgets(
      '$kind: link dialog retains selection and applies/removes link',
      (tester) async {
        await open(tester);
        await type(tester, 'Collegamento');
        final c = body(tester).controller;
        c.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 12));
        await tool(tester, s.editorLink);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(AppTextField),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<AppTextField>(find.byType(AppTextField)).keyboardType,
          TextInputType.url,
        );
        expect(find.text(s.editorLinkHint), findsOneWidget);
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

    testDesktopWidgets(
      '$kind: formatting-only draft triggers discard confirmation',
      (tester) async {
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
      },
    );

    testWidgets(
      '$kind: mobile tools join keyboard; cursor stays visible and watermark stays in document',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetViewPadding);
        await open(tester);
        expect(find.byType(AppRichTextToolbar), findsNothing);
        final save = find.text(s.saveChanges.toUpperCase());
        final share = find.text(s.starQuickLookShareAction.toUpperCase());
        final saveRect = tester.getRect(save);
        final shareRect = tester.getRect(share);
        final headerRect = tester.getRect(find.byType(AreaSectionHeader));
        final divider = find.byKey(const ValueKey('rich-text-editor-divider'));
        final backdrop = find.byKey(
          const ValueKey('rich-text-editor-backdrop'),
        );
        expect(
          tester.getBottomLeft(find.byType(AreaSectionHeader)).dy,
          lessThanOrEqualTo(tester.getTopLeft(divider).dy),
        );
        expect(
          tester.getTopLeft(find.byType(LogoWatermark)).dy,
          greaterThanOrEqualTo(tester.getTopLeft(backdrop).dy),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 120);
        await tester.pump();
        expect(find.byType(AppRichTextToolbar), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(AppRichTextToolbar), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await type(tester, List.filled(80, 'Un paragrafo.\n').join());
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AreaSectionHeader)), headerRect.size);
        expect(
          tester
              .widget<AreaSectionHeader>(find.byType(AreaSectionHeader))
              .compact,
          false,
        );
        if (reflection) {
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('reflection-title')),
                )
                .maxLines,
            3,
          );
          expect(find.text(s.reflectionTitleLabel), findsWidgets);
        }
        expect(tester.getRect(save), saveRect);
        expect(tester.getRect(share), shareRect);
        expect(saveRect.top, greaterThan(360));
        expect(
          tester.getSize(find.byType(AppRichTextEditor)).height,
          greaterThan(40),
        );
        expect(
          tester.getBottomLeft(find.byType(AppRichTextToolbar)).dy,
          closeTo(360, 1),
        );
        final editorState =
            body(tester).editorKey.currentState! as RawEditorState;
        final caret = editorState.renderEditor.getLocalRectForCaret(
          body(tester).controller.selection.extent,
        );
        final globalCaret = MatrixUtils.transformRect(
          editorState.renderEditor.getTransformTo(null),
          caret,
        );
        expect(
          globalCaret.bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byType(AppRichTextToolbar)).dy,
          ),
        );
        final raw = tester.widget<RawEditor>(find.byType(RawEditor));
        final gold = tester.element(find.byType(AppRichTextEditor)).colors.gold;
        expect(raw.cursorStyle.color, gold);
        expect(raw.selectionColor, gold.withValues(alpha: 0.3));
        expect(
          fleather_ui.TextSelectionTheme.of(
            tester.element(find.byType(RawEditor)),
          ).selectionHandleColor,
          gold,
        );
        await tool(tester, s.visionHeading);
        await tester.pumpAndSettle();
        for (final label in [
          s.editorNormal,
          for (var i = 1; i <= 3; i++) '${s.visionHeading} $i',
        ]) {
          expect(
            tester.getRect(find.text(label)).bottom,
            lessThanOrEqualTo(360),
          );
        }
        await tester.tap(find.text('${s.visionHeading} 2'));
        await tester.pumpAndSettle();
        expect(body(tester).focusNode.hasFocus, true);
        expect(
          body(tester).controller.document.toJson().toString(),
          contains('heading: 2'),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pump();
        expect(find.byType(AppRichTextToolbar), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 40);
        await tester.pump();
        expect(find.byType(AppRichTextToolbar), findsOneWidget);
        expect(
          tester.getRect(find.byType(AppRichTextEditor)).bottom,
          lessThanOrEqualTo(saveRect.top),
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(find.byType(AppRichTextToolbar), findsNothing);
        expect(tester.getRect(save), saveRect);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testDesktopWidgets(
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

  testWidgets('mobile selection handles inherit gold inside the root overlay', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    final repo = await AreaVisionRepository.create();
    await tester.pumpWidget(
      app(VisionEditorScreen(area: LifeArea.physical, repository: repo)),
    );
    await type(tester, 'Testo da selezionare');
    await tester.pump(const Duration(milliseconds: 200));
    final rect = tester.getRect(find.byType(AppRichTextEditor));
    await tester.longPressAt(rect.topLeft + const Offset(50, 36));
    await tester.pumpAndSettle();
    final handles = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'SelectionHandleOverlay',
    );
    expect(handles, findsNWidgets(2));
    final gold = tester.element(find.byType(AppRichTextEditor)).colors.gold;
    for (final element in handles.evaluate()) {
      expect(
        fleather_ui.TextSelectionTheme.of(element).selectionHandleColor,
        gold,
      );
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testDesktopWidgets(
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

  testDesktopWidgets('blank space below the first line can focus the editor', (
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

  testDesktopWidgets('clearing a formatted vision removes the stored record', (
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

  testDesktopWidgets(
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

  testDesktopWidgets(
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

  testDesktopWidgets('desktop toolbar appears above the document', (
    tester,
  ) async {
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
  });

  testDesktopWidgets(
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
