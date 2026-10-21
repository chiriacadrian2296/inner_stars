import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../sync/media/media_hooks.dart';
import '../sync/media/media_remote.dart';
import 'moodboard_web_stub.dart'
    if (dart.library.js_interop) 'moodboard_web.dart'
    as web;

import 'package:video_player/video_player.dart';

class MoodboardStorage {
  static const _prefix = 'moodboard-media:';

  /// Only pictures go to the cloud; videos stay on the device.
  static bool _isPicture(String path) => const {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  }.contains(path.split('.').last.toLowerCase());

  static Future<String> save(XFile file) async {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        : 'bin';
    final id = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    if (kIsWeb) {
      final key = '$_prefix$id';
      await web.writeMedia(key, await file.readAsBytes());
      if (_isPicture(id)) MediaHooks.saved(MediaFolder.moodboard, key);
      return key;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = await Directory('${docs.path}/moodboard')
        .create(recursive: true);
    final path = '${dir.path}/$id';
    await file.saveTo(path);
    if (_isPicture(id)) MediaHooks.saved(MediaFolder.moodboard, path);
    return path;
  }

  /// Stores [bytes] under a path that already exists, as when the picture
  /// comes from another device. Does not queue an upload.
  static Future<void> writeAs(String path, Uint8List bytes) async {
    if (kIsWeb) {
      await web.writeMedia(path, bytes);
      return;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = await Directory('${docs.path}/moodboard')
        .create(recursive: true);
    await File('${dir.path}/${path.split('/').last}').writeAsBytes(bytes);
  }

  /// The stored bytes for [path], or null if this device does not have them.
  /// Never asks the cloud.
  static Future<Uint8List?> readLocal(String path) async {
    try {
      if (kIsWeb) return await web.readMedia(path);
      final file = await _resolve(path);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// The file [path] points to, falling back to the same file name inside
  /// the current moodboard directory when the saved absolute path no longer
  /// exists (the app's documents directory can move, e.g. after a reinstall
  /// or restore).
  static Future<File> _resolve(String path) async {
    final direct = File(path);
    if (await direct.exists()) return direct;
    final name = path.split('/').last;
    final docs = await getApplicationDocumentsDirectory();
    final moved = File('${docs.path}/moodboard/$name');
    return await moved.exists() ? moved : direct;
  }

  static Future<Uint8List> read(String path) async {
    if (_isPicture(path)) {
      final local = await readLocal(path);
      if (local != null) return local;
      if (await MediaHooks.fetch(MediaFolder.moodboard, path)) {
        final fetched = await readLocal(path);
        if (fetched != null) return fetched;
      }
    }
    if (!kIsWeb) return (await _resolve(path)).readAsBytes();
    return web.readMedia(path);
  }

  static Future<VideoPlayerController> video(String path) async {
    if (!kIsWeb) return VideoPlayerController.file(await _resolve(path));
    final extension = path.split('.').last.toLowerCase();
    final mime = extension == 'webm'
        ? 'video/webm'
        : extension == 'mov'
        ? 'video/quicktime'
        : 'video/mp4';
    return VideoPlayerController.networkUrl(
      Uri.dataFromBytes(await read(path), mimeType: mime),
    );
  }

  /// [syncDeletion] is false when the file is only being cleared from this
  /// device (wiping local data), which must leave the cloud copy alone.
  static Future<void> delete(String path, {bool syncDeletion = true}) async {
    if (syncDeletion && _isPicture(path)) {
      MediaHooks.deleted(MediaFolder.moodboard, path);
    }
    if (kIsWeb) {
      await web.deleteMedia(path);
    } else {
      final file = await _resolve(path);
      if (await file.exists()) await file.delete();
    }
  }
}
