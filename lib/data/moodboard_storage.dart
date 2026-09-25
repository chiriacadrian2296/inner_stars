import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'moodboard_web_stub.dart'
    if (dart.library.js_interop) 'moodboard_web.dart'
    as web;

import 'package:video_player/video_player.dart';

class MoodboardStorage {
  static const _prefix = 'moodboard-media:';
  static Future<String> save(XFile file) async {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        : 'bin';
    final id = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    if (kIsWeb) {
      final key = '$_prefix$id';
      await web.writeMedia(key, await file.readAsBytes());
      return key;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = await Directory('${docs.path}/moodboard')
        .create(recursive: true);
    final path = '${dir.path}/$id';
    await file.saveTo(path);
    return path;
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

  static Future<void> delete(String path) async {
    if (kIsWeb) {
      await web.deleteMedia(path);
    } else {
      final file = await _resolve(path);
      if (await file.exists()) await file.delete();
    }
  }
}
