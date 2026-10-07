import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/widgets/star_media_views.dart';

Star _star({List<StarMedia> media = const []}) => Star(
  id: 1,
  projectId: 1,
  slotSequence: 1,
  title: 'Run',
  createdAt: DateTime(2024, 1, 1),
  achievedDate: DateTime(2024, 1, 2),
  intensity: 3,
  media: media,
);

void main() {
  final voice = StarMedia(
    id: 'a',
    kind: StarMediaKind.voice,
    path: '1.m4a',
    durationMs: 4200,
    createdAt: DateTime(2024, 1, 2),
  );
  final link = StarMedia(
    id: 'b',
    kind: StarMediaKind.link,
    url: 'https://example.com',
    label: 'Race results',
    createdAt: DateTime(2024, 1, 2),
  );

  test('star media survives a JSON round trip', () {
    final star = _star(media: [voice, link]);
    final back = Star.fromJson(star.toJson());

    expect(back.media, [voice, link]);
    expect(back, star);
  });

  test('JSON saved before extras existed loads with no media', () {
    final json = _star().toJson()..remove('media');

    expect(Star.fromJson(json).media, isEmpty);
  });

  test(
    'an extra of an unknown kind is dropped instead of failing the load',
    () {
      final json = _star(media: [voice]).toJson();
      (json['media'] as List).add({
        'id': 'x',
        'kind': 'hologram',
        'createdAt': DateTime(2024).toIso8601String(),
      });

      expect(Star.fromJson(json).media, [voice]);
    },
  );

  test('copyWith can replace and clear media', () {
    final star = _star(media: [voice]);

    expect(star.copyWith(media: [voice, link]).media, hasLength(2));
    expect(star.copyWith(media: const []).media, isEmpty);
    expect(star.copyWith(title: 'x').media, [voice]);
  });

  test('parseExtraLink accepts web addresses and rejects junk', () {
    expect(parseExtraLink('example.com')?.toString(), 'https://example.com');
    expect(parseExtraLink(' http://a.io/x ')?.scheme, 'http');
    expect(parseExtraLink('not a link'), isNull);
    expect(parseExtraLink('ftp://example.com'), isNull);
    expect(parseExtraLink('localhost'), isNull);
    expect(parseExtraLink(''), isNull);
  });
}
