import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/star_media_editor.dart';

Widget _app(List<StarMedia> media, double width) => StringsScope(
  strings: const StringsIt(),
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: StarMediaEditor(
            media: media,
            onChanged: (_) {},
            sideColumn: true,
            // What the form gives a 320 px wide phone: half of the content
            // width, at the photo's 9:16 shape.
            gridHeight: width * 16 / 9,
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

void main() {
  testWidgets('side column fits a narrow phone, empty and with links', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const [], 138));
    expect(find.text('Canzone'), findsOneWidget);
    expect(find.text('Posizione'), findsOneWidget);
    expect(find.text('Sito'), findsOneWidget);
    expect(find.text('Nota vocale · 1:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app([
        _link(StarLinkKind.song, 'Una canzone con un titolo molto lungo'),
        _link(StarLinkKind.place, 'Un posto'),
        // A link saved before kinds existed counts as a site.
        _link(null, 'Il mio sito'),
      ], 138),
    );
    expect(find.text('Una canzone con un titolo molto lungo'), findsOneWidget);
    expect(find.text('Un posto'), findsOneWidget);
    expect(find.text('Il mio sito'), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a link kind survives the JSON round trip', () {
    final link = _link(StarLinkKind.place, 'Posto');
    expect(StarMedia.tryFromJson(link.toJson()), link);
    final legacy = link.toJson()..remove('linkKind');
    expect(StarMedia.tryFromJson(legacy)?.linkKind, isNull);
    expect(kMaxStarMediaPerKind[StarMediaKind.voice], 1);
  });
}
