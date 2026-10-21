import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inner_stars/sync/media/media_queue.dart';
import 'package:inner_stars/sync/media/media_remote.dart';
import 'package:inner_stars/sync/media/media_sync.dart';
import 'package:inner_stars/sync/media/photo_compression.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Local implements MediaLocal {
  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> read(MediaFolder folder, String id) async =>
      files[mediaName(folder, id)];

  @override
  Future<void> write(MediaFolder folder, String id, Uint8List bytes) async {
    files[mediaName(folder, id)] = bytes;
  }
}

Uint8List _bigPicture() {
  final image = img.Image(width: 3200, height: 1800);
  var seed = 7;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final noise = (seed >> 16) % 64;
      image.setPixelRgb(
        x,
        y,
        ((x ~/ 8) * 7 + noise) % 256,
        ((y ~/ 8) * 5 + noise) % 256,
        (x + y + noise) % 256,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 97));
}

void main() {
  late SharedPreferences prefs;
  late InMemoryMediaRemote remote;
  late _Local local;
  late MediaQueue queue;
  late MediaSync sync;
  MediaRemote? signedIn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = InMemoryMediaRemote();
    signedIn = remote;
    local = _Local();
    queue = MediaQueue(prefs);
    sync = MediaSync(queue: queue, local: local, remoteFor: () => signedIn);
  });

  group('compressPhoto', () {
    test('shrinks a large picture to the longest side and a smaller file', () {
      final original = _bigPicture();
      final result = compressPhoto(original);
      final decoded = img.decodeImage(result)!;
      expect(decoded.width, kUploadPhotoMaxSide);
      expect(decoded.height, lessThan(kUploadPhotoMaxSide));
      expect(result.length, lessThan(original.length));
    });

    test('keeps something that is not a picture, and never grows a file', () {
      final text = Uint8List.fromList([1, 2, 3, 4]);
      expect(compressPhoto(text), same(text));
      final small = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 8, height: 8), quality: 10),
      );
      expect(compressPhoto(small).length, lessThanOrEqualTo(small.length));
    });
  });

  group('MediaQueue', () {
    test(
      'keeps one job per file, the latest winning, across restarts',
      () async {
        await queue.enqueue(MediaFolder.photos, 'a.jpg', MediaOp.upload);
        await queue.enqueue(MediaFolder.photos, 'a.jpg', MediaOp.delete);
        await queue.enqueue(MediaFolder.voices, 'v.m4a', MediaOp.upload);

        final reopened = MediaQueue(prefs).jobs;
        expect(reopened.map((j) => '${j.name}:${j.op.name}'), [
          'photos/a.jpg:delete',
          'voices/v.m4a:upload',
        ]);
      },
    );

    test('names files by their last path part', () {
      expect(
        mediaName(MediaFolder.photos, r'C:\docs\win_photos\9.jpg'),
        'photos/9.jpg',
      );
      expect(mediaName(MediaFolder.photos, '/data/x/9.jpg'), 'photos/9.jpg');
    });

    test('ignores a damaged queue instead of crashing', () async {
      await prefs.setString(MediaQueue.storageKey, '{not json');
      expect(queue.jobs, isEmpty);
    });
  });

  group('MediaSync', () {
    test(
      'uploads a photo smaller than the original, a voice note as is',
      () async {
        final photo = _bigPicture();
        final voice = Uint8List.fromList(List.generate(500, (i) => i % 256));
        await local.write(MediaFolder.photos, 'p.jpg', photo);
        await local.write(MediaFolder.voices, 'v.m4a', voice);
        await sync.fileSaved(MediaFolder.photos, 'p.jpg');
        await sync.fileSaved(MediaFolder.voices, 'v.m4a');

        expect(await sync.process(), 2);

        expect(remote.files['photos/p.jpg']!.length, lessThan(photo.length));
        expect(remote.types['photos/p.jpg'], 'image/jpeg');
        expect(remote.files['voices/v.m4a'], voice);
        expect(queue.isEmpty, isTrue);
      },
    );

    test('a delete queued after an upload means nothing is sent', () async {
      await local.write(MediaFolder.photos, 'p.jpg', Uint8List.fromList([1]));
      await sync.fileSaved(MediaFolder.photos, 'p.jpg');
      await sync.fileDeleted(MediaFolder.photos, 'p.jpg');

      await sync.process();

      expect(remote.uploads, 0);
      expect(remote.files, isEmpty);
    });

    test('a deletion removes the cloud copy', () async {
      remote.files['photos/p.jpg'] = Uint8List.fromList([1]);
      await sync.fileDeleted(MediaFolder.photos, 'p.jpg');
      await sync.process();
      expect(remote.files, isEmpty);
    });

    test('offline keeps the queue and the next run finishes it', () async {
      await local.write(MediaFolder.voices, 'a.m4a', Uint8List.fromList([1]));
      await local.write(MediaFolder.voices, 'b.m4a', Uint8List.fromList([2]));
      await sync.fileSaved(MediaFolder.voices, 'a.m4a');
      await sync.fileSaved(MediaFolder.voices, 'b.m4a');
      remote.offline = true;

      expect(await sync.process(), 0);
      expect(queue.jobs, hasLength(2));
      expect(queue.jobs.first.attempts, 1);

      remote.offline = false;
      expect(await sync.process(), 2);
      expect(remote.files.keys, containsAll(['voices/a.m4a', 'voices/b.m4a']));
    });

    test('a job that keeps failing is given up on', () async {
      final stubborn = MediaSync(
        queue: queue,
        local: local,
        remoteFor: () => signedIn,
        maxAttempts: 2,
      );
      await local.write(MediaFolder.voices, 'a.m4a', Uint8List.fromList([1]));
      await stubborn.fileSaved(MediaFolder.voices, 'a.m4a');
      remote.offline = true;

      await stubborn.process();
      expect(queue.jobs, hasLength(1));
      await stubborn.process();
      expect(queue.isEmpty, isTrue);
    });

    test('nothing is sent while signed out, and nothing is lost', () async {
      await local.write(MediaFolder.voices, 'a.m4a', Uint8List.fromList([1]));
      await sync.fileSaved(MediaFolder.voices, 'a.m4a');
      signedIn = null;

      expect(await sync.process(), 0);
      expect(queue.jobs, hasLength(1));
      expect(queue.jobs.first.attempts, 0);
    });

    test('a file that disappeared before its turn is simply dropped', () async {
      await sync.fileSaved(MediaFolder.photos, 'ghost.jpg');
      expect(await sync.process(), 1);
      expect(remote.uploads, 0);
      expect(queue.isEmpty, isTrue);
    });

    test('a file over the size limit is not sent', () async {
      final huge = Uint8List(kMaxMediaBytes + 1);
      await local.write(MediaFolder.voices, 'big.m4a', huge);
      await sync.fileSaved(MediaFolder.voices, 'big.m4a');
      await sync.process();
      expect(remote.uploads, 0);
      expect(queue.isEmpty, isTrue);
    });

    test(
      'ensureLocal downloads once for several askers, then uses the copy',
      () async {
        remote.files['photos/x.jpg'] = Uint8List.fromList([9, 9]);

        final results = await Future.wait([
          sync.ensureLocal(MediaFolder.photos, 'x.jpg'),
          sync.ensureLocal(MediaFolder.photos, 'x.jpg'),
        ]);
        expect(results, [true, true]);
        expect(remote.downloads, 1);
        expect(await local.read(MediaFolder.photos, 'x.jpg'), [9, 9]);

        expect(await sync.ensureLocal(MediaFolder.photos, 'x.jpg'), isTrue);
        expect(remote.downloads, 1);
      },
    );

    test(
      'ensureLocal says no when the cloud lacks it, is offline or signed out',
      () async {
        expect(await sync.ensureLocal(MediaFolder.photos, 'nope.jpg'), isFalse);
        remote.offline = true;
        expect(await sync.ensureLocal(MediaFolder.photos, 'nope.jpg'), isFalse);
        signedIn = null;
        expect(await sync.ensureLocal(MediaFolder.photos, 'nope.jpg'), isFalse);
      },
    );

    test('deleteAllRemote empties the account area', () async {
      remote.files['photos/a.jpg'] = Uint8List.fromList([1]);
      remote.files['voices/b.m4a'] = Uint8List.fromList([2]);
      await sync.fileSaved(MediaFolder.voices, 'c.m4a');

      expect(await sync.deleteAllRemote(), 2);
      expect(remote.files, isEmpty);
      expect(queue.isEmpty, isTrue);
    });

    test(
      'removeOrphans keeps what a record refers to or is still queued',
      () async {
        remote.files['photos/used.jpg'] = Uint8List.fromList([1]);
        remote.files['photos/old.jpg'] = Uint8List.fromList([2]);
        remote.files['voices/queued.m4a'] = Uint8List.fromList([3]);
        await sync.fileSaved(MediaFolder.voices, 'queued.m4a');

        final removed = await sync.removeOrphans({'photos/used.jpg'});

        expect(removed, 1);
        expect(
          remote.files.keys,
          unorderedEquals(['photos/used.jpg', 'voices/queued.m4a']),
        );
      },
    );
  });
}
