import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/rich_text_document.dart';
import 'package:inner_stars/models/reflection.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/sync_text_value.dart';
import 'package:inner_stars/widgets/app_rich_text_editor.dart';

void main() {
  test('imports nested underline and bold/italic without exposed markers', () {
    final c = AppRichTextController(legacy: '<u>***Ciao*** mondo</u>');
    addTearDown(c.dispose);
    expect(c.plainText, 'Ciao mondo');
    final first = c.document.toDelta().first;
    expect(first.attributes, containsPair('b', true));
    expect(first.attributes, containsPair('i', true));
    expect(first.attributes, containsPair('u', true));
    expect(c.hasChanges, false);
    final snapshot = c.snapshot;
    final restored = AppRichTextController(
      legacy: snapshot.legacyText,
      richText: RichTextDocument.tryParse(
        jsonDecode(jsonEncode(snapshot.toJson())),
      ),
    );
    addTearDown(restored.dispose);
    expect(restored.document.toJson(), c.document.toJson());
  });

  for (final source in [
    '*<u>**asd*asd**</u>',
    '<u>**as*dasd***</u>',
    'Unmatched **text <u> kept',
    'a < b & c',
    'letterale \\* e \\_',
  ]) {
    test('old irregular source stays readable: $source', () {
      final c = AppRichTextController(legacy: source);
      addTearDown(c.dispose);
      expect(c.plainText, isNotEmpty);
      final snap = c.snapshot;
      final restored = AppRichTextController(
        legacy: snap.legacyText,
        richText: snap,
      );
      addTearDown(restored.dispose);
      expect(restored.plainText, c.plainText);
      expect(restored.document.toJson(), c.document.toJson());
    });
  }

  test(
    'imports headings, legacy bullets, numbered lists, quote and divider',
    () {
      final c = AppRichTextController(
        legacy: '# Heading\n\n• One\n• Two\n\n1. Three\n\n> Quote\n\n---',
      );
      addTearDown(c.dispose);
      final encoded = jsonEncode(c.document.toJson());
      expect(encoded, contains('"heading":1'));
      expect(encoded, contains('"block":"ul"'));
      expect(encoded, contains('"block":"ol"'));
      expect(encoded, contains('"block":"quote"'));
      expect(encoded, contains('"_type":"hr"'));
      expect(RichTextDocument.tryParse(c.snapshot.toJson()), isNotNull);
    },
  );

  test('all seven B/I/U combinations can be typed and toggled off', () {
    final formats = [
      ParchmentAttribute.bold,
      ParchmentAttribute.italic,
      ParchmentAttribute.underline,
    ];
    for (var mask = 1; mask <= 7; mask++) {
      final c = AppRichTextController();
      for (var i = 0; i < 3; i++) {
        if ((mask & (1 << i)) != 0) c.formatSelection(formats[i]);
      }
      c.replaceText(
        0,
        0,
        'asd',
        selection: const TextSelection.collapsed(offset: 3),
      );
      for (var i = 0; i < 3; i++) {
        if ((mask & (1 << i)) != 0) {
          expect(
            c.document.toDelta().first.attributes,
            containsPair(formats[i].key, true),
          );
          c.formatSelection(formats[i].unset);
        }
      }
      c.replaceText(
        3,
        0,
        ' normal',
        selection: const TextSelection.collapsed(offset: 10),
      );
      expect(c.plainText, 'asd normal');
      final snap = c.snapshot;
      final restored = AppRichTextController(
        legacy: snap.legacyText,
        richText: snap,
      );
      expect(restored.document.toJson(), c.document.toJson());
      expect(restored.document.collectStyle(4, 6).inlineAttributes, isEmpty);
      c.dispose();
      restored.dispose();
    }
  });

  test('overlapping selection formatting does not change the text', () {
    final c = AppRichTextController(legacy: 'abcdef');
    addTearDown(c.dispose);
    c.formatText(0, 4, ParchmentAttribute.bold);
    c.formatText(2, 4, ParchmentAttribute.italic);
    c.formatText(1, 4, ParchmentAttribute.underline);
    c.formatText(2, 1, ParchmentAttribute.bold.unset);
    expect(c.plainText, 'abcdef');
    expect(
      c.document.collectStyle(1, 1).containsSame(ParchmentAttribute.bold),
      true,
    );
    expect(
      c.document.collectStyle(2, 1).containsSame(ParchmentAttribute.bold),
      false,
    );
    expect(
      c.document.collectStyle(2, 1).containsSame(ParchmentAttribute.italic),
      true,
    );
  });

  test('headings, blocks, alignment and links survive round trip', () {
    final c = AppRichTextController(legacy: 'Testo\nSeconda');
    addTearDown(c.dispose);
    for (final attr in [
      ParchmentAttribute.h1,
      ParchmentAttribute.h2,
      ParchmentAttribute.h1,
      ParchmentAttribute.heading.unset,
    ]) {
      c.formatSelection(attr);
      expect(c.plainText, 'Testo\nSeconda');
      expect(c.selection.isValid, true);
    }
    c.formatSelection(ParchmentAttribute.center);
    c.formatSelection(ParchmentAttribute.block.quote);
    c.formatText(
      0,
      5,
      ParchmentAttribute.link.fromString('https://example.com'),
    );
    final snap = c.snapshot;
    final restored = AppRichTextController(
      legacy: snap.legacyText,
      richText: snap,
    );
    addTearDown(restored.dispose);
    expect(restored.document.toJson(), c.document.toJson());
    expect(c.hasChanges, true);
  });

  test('selection and pending styles alone are not unsaved changes', () {
    final c = AppRichTextController(legacy: 'Testo');
    addTearDown(c.dispose);
    c.updateSelection(const TextSelection.collapsed(offset: 3));
    c.formatSelection(ParchmentAttribute.bold);
    expect(c.hasChanges, false);
    c.formatText(0, 1, ParchmentAttribute.bold);
    expect(c.hasChanges, true);
    c.formatText(0, 1, ParchmentAttribute.bold.unset);
    expect(c.hasChanges, false);
  });

  test('visible length counts graphemes and excludes terminal newline', () {
    final c = AppRichTextController(legacy: '👩‍👩‍👧‍👦é\nFine');
    addTearDown(c.dispose);
    expect(c.characterCount, 7);
    expect(c.plainText, '👩‍👩‍👧‍👦é\nFine');
    final blank = AppRichTextController();
    expect(blank.isEmpty, true);
    expect(blank.characterCount, 0);
    blank.dispose();
  });

  test('corrupt, unknown-version and stale payloads fall back to legacy', () {
    final c = AppRichTextController(legacy: 'Old');
    addTearDown(c.dispose);
    final snap = c.snapshot;
    final stale = AppRichTextController(
      legacy: 'Edited by old app',
      richText: snap,
    );
    addTearDown(stale.dispose);
    expect(stale.plainText, 'Edited by old app');
    expect(RichTextDocument.tryParse({...snap.toJson(), 'version': 99}), null);
    expect(
      RichTextDocument.tryParse({
        ...snap.toJson(),
        'delta': [
          {'insert': 3},
        ],
      }),
      null,
    );
    expect(
      RichTextDocument.tryParse({
        ...snap.toJson(),
        'delta': [
          {'retain': 2},
        ],
      }),
      null,
    );
    expect(
      RichTextDocument.tryParse({
        ...snap.toJson(),
        'delta': [
          {'insert': 'unterminated'},
        ],
      }),
      null,
    );
  });

  test('accessible replacements preserve existing formats, Unicode and native history', () {
    final c = AppRichTextController(legacy: '**Testo**');
    addTearDown(c.dispose);
    c.replaceAccessibleText('Testo extra');
    expect(c.plainText, 'Testo extra');
    expect(
      c.document.collectStyle(0, 5).containsSame(ParchmentAttribute.bold),
      true,
    );
    c.replaceAccessibleText('Testo 👩‍👩‍👧‍👦');
    expect(c.plainText, 'Testo 👩‍👩‍👧‍👦');
    c.replaceAccessibleText('Testo 😀');
    expect(c.plainText, 'Testo 😀');
    c.replaceAccessibleText('Testo 😃');
    expect(c.plainText, 'Testo 😃');
    c.replaceAccessibleText('Testo 😃!');
    expect(c.plainText, 'Testo 😃!');
    expect(
      c.document.collectStyle(0, 5).containsSame(ParchmentAttribute.bold),
      true,
    );
  });

  test('optional fields preserve old JSON and new model round trips', () {
    final c = AppRichTextController(legacy: '**Testo**');
    addTearDown(c.dispose);
    final snap = c.snapshot;
    final now = DateTime.utc(2026);
    final r = Reflection(
      id: 'r',
      area: LifeArea.physical,
      title: 'Title',
      body: snap.legacyText,
      richText: snap,
      origin: ReflectionOrigin.free,
      createdAt: now,
      updatedAt: now,
    );
    expect(Reflection.fromJson(r.toJson()).richText!.toJson(), snap.toJson());
    expect(Reflection.fromJson(r.toJson()..remove('richText')).richText, null);
    expect(r.edit(title: 'Changed title', body: r.body).richText, snap);
    expect(
      r.edit(title: 'Changed title', body: 'Old client edit').richText,
      null,
    );
    final v = SyncTextValue(
      value: snap.legacyText,
      richText: snap,
      updatedAt: now,
    );
    expect(
      SyncTextValue.fromJson(v.toJson()).richText!.toJson(),
      snap.toJson(),
    );
    expect(
      SyncTextValue.fromJson(v.toJson()..remove('richText')).richText,
      null,
    );
  });
}
