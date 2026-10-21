import 'dart:typed_data';

/// The folders media lives in, in the cloud and in the queue. A file is named
/// `<folder>/<id>`, where the id is the opaque name the app already keeps in
/// the record (a star's `photoPath`, a voice note's `path`, a moodboard
/// item's `content`).
enum MediaFolder {
  photos('photos', 'image/jpeg'),
  voices('voices', 'audio/mp4'),
  moodboard('moodboard', 'image/jpeg');

  const MediaFolder(this.path, this.contentType);
  final String path;
  final String contentType;
}

/// The cloud file name for [id] in [folder]. A record may hold a full device
/// path (older photos, moodboard files on a phone) or a web storage key such
/// as `moodboard-media:123.jpg`, so only the part after the last `/`, `\` or
/// `:` counts: every device then names the same file the same way.
String mediaName(MediaFolder folder, String id) =>
    '${folder.path}/${id.split(RegExp(r'[\\/:]')).last}';

/// Largest file the cloud accepts, kept equal to `storage.rules`.
const int kMaxMediaBytes = 5 * 1024 * 1024;

/// The remote copy of the media files, one per signed-in account. Firebase
/// Storage implements this; tests use [InMemoryMediaRemote].
abstract class MediaRemote {
  Future<void> upload(String name, Uint8List bytes, String contentType);

  /// The bytes of [name], or null when the cloud has no such file.
  Future<Uint8List?> download(String name);

  /// Removes [name]; a file that is not there is not an error.
  Future<void> delete(String name);

  /// Every file name in the account's media area.
  Future<List<String>> list();
}

/// A fake cloud for tests, with a switch to simulate being offline.
class InMemoryMediaRemote implements MediaRemote {
  final Map<String, Uint8List> files = {};
  final Map<String, String> types = {};
  bool offline = false;
  int uploads = 0;
  int downloads = 0;

  void _check() {
    if (offline) throw StateError('offline');
  }

  @override
  Future<void> upload(String name, Uint8List bytes, String contentType) async {
    _check();
    files[name] = bytes;
    types[name] = contentType;
    uploads++;
  }

  @override
  Future<Uint8List?> download(String name) async {
    _check();
    downloads++;
    return files[name];
  }

  @override
  Future<void> delete(String name) async {
    _check();
    files.remove(name);
    types.remove(name);
  }

  @override
  Future<List<String>> list() async {
    _check();
    return files.keys.toList();
  }
}
