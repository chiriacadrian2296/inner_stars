import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Copies a win's photo into persistent storage and cleans it up again.
///
/// [ImagePicker] only hands back a path into the OS's own temp/cache area
/// (or a content URI on some Android versions) — not guaranteed to survive
/// past the current session, and never meant to be kept long-term. Every
/// photo a star points to (via [Star.photoPath]) is instead a permanent copy
/// made right when it's picked — under this app's own documents directory on
/// native (via `dart:io`, [_photosDir]), or as a base64-encoded
/// [SharedPreferences] entry on web, where there's no real filesystem to
/// write to and `dart:io`'s `File` is a non-functional stub. Either way,
/// [Star.photoPath] is really just an opaque id from here on — a real file
/// path on native, a storage key on web — nothing outside this class needs
/// to know which.
class PhotoStorage {
  static const _subdirName = 'win_photos';
  static const _webKeyPrefix = 'photo-bytes:';

  /// Bytes already read once this session, keyed by [Star.photoPath] — every
  /// display site goes through `PhotoImage`, which reads asynchronously;
  /// caching here avoids re-reading (and the brief loading flicker that
  /// comes with it) on every rebuild, mirroring the caching `Image.file`
  /// used to get for free from Flutter's own image cache before every photo
  /// display switched to this class to support web too.
  static final Map<String, Uint8List> _cache = {};

  /// The synchronous fast path for a photo already read this session — see
  /// [_cache]. Null just means "not cached yet", not "doesn't exist".
  static Uint8List? cachedBytes(String id) => _cache[id];

  static Future<Directory> _photosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_subdirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The file [id] points to. [saveBytes] hands back just a file name, and
  /// older photos were saved as a full path that may no longer be valid (the
  /// app's documents directory can move) — so anything that isn't an existing
  /// absolute path is looked up by its file name in [_photosDir]. Reading a
  /// bare name as a path relative to the working directory is what made
  /// photos vanish after a restart, once the in-memory [_cache] was gone.
  static Future<File> _resolve(String id) async {
    final direct = File(id);
    if (direct.isAbsolute && await direct.exists()) return direct;
    final name = id.split('/').last;
    return File('${(await _photosDir()).path}/$name');
  }

  /// Copies [picked] into storage and returns its new, permanent id.
  static Future<String> save(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final dotIndex = picked.name.lastIndexOf('.');
    final extension = dotIndex == -1
        ? '.jpg'
        : picked.name.substring(dotIndex);
    return saveBytes(bytes, extension: extension);
  }

  /// Same as [save], but for a photo that's already been through the 9:16
  /// crop step (see `PhotoCropScreen`) and only exists as encoded bytes —
  /// there's no picker [XFile] backing it to copy from.
  static Future<String> saveBytes(
    Uint8List bytes, {
    String extension = '.jpg',
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}$extension';
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webKeyPrefix$id', base64Encode(bytes));
    } else {
      final dir = await _photosDir();
      await File('${dir.path}/$id').writeAsBytes(bytes);
    }
    _cache[id] = bytes;
    return id;
  }

  /// Reads back the bytes [id] (a file path on native, a storage key on web)
  /// points to — null if missing.
  static Future<Uint8List?> readBytes(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    final Uint8List? bytes;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('$_webKeyPrefix$id');
      bytes = encoded == null ? null : base64Decode(encoded);
    } else {
      final file = await _resolve(id);
      bytes = await file.exists() ? await file.readAsBytes() : null;
    }
    if (bytes != null) _cache[id] = bytes;
    return bytes;
  }

  /// Deletes the photo at [id], if it still exists. Failures are swallowed
  /// — a leftover file/key here is a wasted few KB, not worth surfacing an
  /// error for on what's already a best-effort cleanup step.
  static Future<void> delete(String id) async {
    _cache.remove(id);
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_webKeyPrefix$id');
      } else {
        final file = await _resolve(id);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup — see doc comment above.
    }
  }
}
