import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/sync/media/media_backfill.dart';
import 'package:inner_stars/sync/media/media_queue.dart';
import 'package:inner_stars/sync/media/media_remote.dart';
import 'package:inner_stars/sync/media/media_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoLocal implements MediaLocal {
  @override
  Future<Uint8List?> read(MediaFolder folder, String id) async => null;

  @override
  Future<void> write(MediaFolder folder, String id, Uint8List bytes) async {}
}

Star _star(
  String id, {
  String? photo,
  List<StarMedia> media = const [],
  bool deleted = false,
}) => Star(
  id: id,
  projectId: 'p',
  slotSequence: 0,
  title: id,
  createdAt: DateTime.utc(2026, 1, 1),
  photoPath: photo,
  media: media,
  deleted: deleted,
);

MoodboardItem _item(
  String id,
  MoodboardKind kind,
  String content, {
  bool deleted = false,
}) => MoodboardItem(id: id, kind: kind, content: content, deleted: deleted);

void main() {
  late SharedPreferences prefs;
  late MediaQueue queue;
  late MediaSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    queue = MediaQueue(prefs);
    sync = MediaSync(queue: queue, local: _NoLocal(), remoteFor: () => null);
  });

  test(
    'queues the existing photos, voice notes and moodboard pictures once',
    () async {
      final voice = StarMedia(
        id: 'm1',
        kind: StarMediaKind.voice,
        path: 'v.m4a',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final extraPhoto = StarMedia(
        id: 'm2',
        kind: StarMediaKind.photo,
        path: 'extra.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      Future<void> run() => backfillMedia(
        prefs: prefs,
        uid: 'u1',
        sync: sync,
        stars: [
          _star('a', photo: 'a.jpg', media: [voice, extraPhoto]),
          _star('b', photo: 'sample', deleted: true),
          _star('c', photo: 'https://example.com/x.jpg'),
        ],
        moodboard: [
          _item('1', MoodboardKind.photo, '/docs/moodboard/1.jpg'),
          _item('2', MoodboardKind.video, '/docs/moodboard/2.mp4'),
          _item('3', MoodboardKind.quote, 'A quote'),
          _item(
            '4',
            MoodboardKind.photo,
            '/docs/moodboard/4.jpg',
            deleted: true,
          ),
        ],
      );

      await run();

      expect(queue.jobs.map((j) => j.name).toSet(), {
        'photos/a.jpg',
        'voices/v.m4a',
        'moodboard/1.jpg',
      });

      await queue.clear();
      await run();
      expect(queue.isEmpty, isTrue);
    },
  );

  test('each account is backfilled on its own', () async {
    Future<void> run(String uid) => backfillMedia(
      prefs: prefs,
      uid: uid,
      sync: sync,
      stars: [_star('a', photo: 'a.jpg')],
      moodboard: const [],
    );

    await run('u1');
    await queue.clear();
    await run('u2');

    expect(queue.jobs, hasLength(1));
  });
}
