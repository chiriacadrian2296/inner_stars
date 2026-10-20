import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/app_field.dart';
import 'package:inner_stars/widgets/star_media_editor.dart';

/// What the form gives the column: as tall as the photo column beside it, the
/// photo's name row, the gap and the photo at 9:16. [width] is half of the
/// content width (138 on a 320 px phone).
Widget _app(
  List<StarMedia> media,
  double width, {
  ValueChanged<List<StarMedia>>? onChanged,
}) => StringsScope(
  strings: const StringsIt(),
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: StarMediaEditor(
            media: media,
            onChanged: onChanged ?? (_) {},
            sideColumn: true,
            gridHeight: kFieldNameRowHeight + kFieldLabelGap + width * 16 / 9,
          ),
        ),
      ),
    ),
  ),
);

StarMedia _link(StarLinkKind? kind, String label) => StarMedia(
  id: label,
  kind: StarMediaKind.link,
  url: 'https://example.com',
  label: label,
  linkKind: kind,
  createdAt: DateTime(2026),
);

StarMedia _voice() => StarMedia(
  id: 'voice',
  kind: StarMediaKind.voice,
  path: 'x.m4a',
  durationMs: 12000,
  createdAt: DateTime(2026),
);

void main() {
  testWidgets('empty: two name rows with reset, the limit, one icon per link', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const [], 138));
    expect(find.text('Nota Vocale'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Limite · 1:00'), findsOneWidget);
    // One reset icon per name row, both off while nothing is there.
    expect(find.byType(FieldResetButton), findsNWidgets(2));
    expect(
      tester
          .widgetList<FieldResetButton>(find.byType(FieldResetButton))
          .every((b) => !b.canReset),
      isTrue,
    );
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    // The old kind words are gone from the placeholders.
    expect(find.text('Canzone'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [138.0, 154.0, 170.0]) {
    testWidgets('no overflow at $width px, empty and full', (tester) async {
      await tester.pumpWidget(_app(const [], width));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app([
          _voice(),
          _link(StarLinkKind.song, 'Una canzone con un titolo molto lungo'),
          _link(StarLinkKind.place, 'Un posto'),
          // A link saved before kinds existed counts as a site.
          _link(null, 'Il mio sito'),
        ], width),
      );
      expect(find.text('Una canzone con un titolo molto lungo'), findsOne);
      expect(find.text('Un posto'), findsOneWidget);
      expect(find.text('Il mio sito'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the voice reset removes the note, the link reset all links', (
    tester,
  ) async {
    List<StarMedia>? result;
    final media = [
      _voice(),
      _link(StarLinkKind.song, 'Canzone'),
      _link(StarLinkKind.place, 'Posto'),
    ];
    await tester.pumpWidget(_app(media, 154, onChanged: (m) => result = m));
    final resets = find.byType(FieldResetButton);

    await tester.tap(
      find.descendant(of: resets.at(0), matching: find.byType(IconButton)),
    );
    expect(result!.map((m) => m.kind), [
      StarMediaKind.link,
      StarMediaKind.link,
    ]);

    await tester.tap(
      find.descendant(of: resets.at(1), matching: find.byType(IconButton)),
    );
    expect(result!.map((m) => m.kind), [StarMediaKind.voice]);
  });

  testWidgets('a name row fits inside the height the form reserves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const [], 138));
    for (final label in tester.widgetList(find.byType(AppFieldLabel))) {
      final size = tester.getSize(find.byWidget(label));
      expect(size.height, lessThanOrEqualTo(kFieldNameRowHeight));
    }
  });

  test('a link kind survives the JSON round trip', () {
    final link = _link(StarLinkKind.place, 'Posto');
    expect(StarMedia.tryFromJson(link.toJson()), link);
    final legacy = link.toJson()..remove('linkKind');
    expect(StarMedia.tryFromJson(legacy)?.linkKind, isNull);
    expect(kMaxStarMediaPerKind[StarMediaKind.voice], 1);
  });
}
