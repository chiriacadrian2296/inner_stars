import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/star_media.dart';
import 'star_media_web_stub.dart'
    if (dart.library.js_interop) 'star_media_web.dart'
    as web;

/// Files behind a victory's extras (voice notes, secondary photos, videos),
/// kept under `documents/star_media/` on native platforms and in IndexedDB
/// on the web. SharedPreferences only stores the small opaque id, never the
/// media bytes.
///
/// [StarMedia.path] holds just the file name, so a moved documents directory
/// (reinstall, restore) never breaks a saved reference.
class StarMediaStorage {
  static bool get isSupported => true;

  static bool isRemote(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static const _webPrefix = 'star-media:';

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/star_media').create(recursive: true);
  }

  static String _extensionOf(String name, String fallback) {
    if (!name.contains('.')) return fallback;
    final ext = name.split('.').last.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    return ext.isEmpty ? fallback : ext;
  }

  static String _newId(String extension) =>
      '${DateTime.now().microsecondsSinceEpoch}.$extension';

  /// Copies a picked photo or video into app storage; returns its file name.
  ///
  /// [name] overrides the file's own name when working out its extension —
  /// a document picked through the system chooser can arrive as a content
  /// address with no extension of its own.
  static Future<String> save(
    XFile file, {
    String fallbackExtension = 'bin',
    String? name,
  }) async {
    final id = _newId(_extensionOf(name ?? file.name, fallbackExtension));
    if (kIsWeb) {
      final key = '$_webPrefix$id';
      await web.writeMedia(key, await file.readAsBytes());
      return key;
    }
    final dir = await _dir();
    await file.saveTo('${dir.path}/$id');
    return id;
  }

  /// Moves a freshly recorded file (at [sourcePath]) into app storage;
  /// returns its file name.
  static Future<String> saveRecording(String sourcePath) async {
    final id = _newId(_extensionOf(sourcePath, 'm4a'));
    final dir = await _dir();
    final target = '${dir.path}/$id';
    final source = File(sourcePath);
    try {
      await source.rename(target);
    } on FileSystemException {
      // Cache and documents can sit on different volumes.
      await source.copy(target);
      await source.delete();
    }
    return id;
  }

  /// A path inside the recordings scratch area for the recorder to write to.
  static Future<String> newRecordingPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  /// The stored file for [path], or null if it is gone. Native only; web
  /// callers use [readBytes] instead.
  static Future<File?> file(String path) async {
    if (kIsWeb) return null;
    final dir = await _dir();
    final stored = File('${dir.path}/${path.split('/').last}');
    return await stored.exists() ? stored : null;
  }

  static Future<Uint8List?> readBytes(String path) async =>
      kIsWeb ? web.readMedia(path) : (await file(path))?.readAsBytes();

  static Future<VideoPlayerController?> video(String path) async {
    if (kIsWeb) {
      final extension = path.split('.').last.toLowerCase();
      final mime = extension == 'webm'
          ? 'video/webm'
          : extension == 'mov'
          ? 'video/quicktime'
          : 'video/mp4';
      return VideoPlayerController.networkUrl(
        Uri.dataFromBytes(await web.readMedia(path), mimeType: mime),
      );
    }
    final f = await file(path);
    return f == null ? null : VideoPlayerController.file(f);
  }

  /// A still from the start of the stored video [path], made once and kept
  /// next to it; null if one can't be made.
  static Future<File?> videoThumbnail(String path) async {
    try {
      final dir = await _dir();
      final name = path.split('/').last;
      final thumb = File('${dir.path}/$name.thumb.jpg');
      if (await thumb.exists()) return thumb;
      final video = await file(path);
      if (video == null) return null;
      final made = await FcNativeVideoThumbnail().saveThumbnailToFile(
        srcFile: video.path,
        destFile: thumb.path,
        width: 640,
        height: 640,
        format: 'jpeg',
        quality: 80,
      );
      return made ? thumb : null;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort delete of one stored file (and a video's thumbnail).
  static Future<void> delete(String path) async {
    if (isRemote(path)) return;
    try {
      if (kIsWeb) {
        await web.deleteMedia(path);
        return;
      }
      final f = await file(path);
      if (f != null) await f.delete();
      final dir = await _dir();
      final thumb = File('${dir.path}/${path.split('/').last}.thumb.jpg');
      if (await thumb.exists()) await thumb.delete();
    } catch (_) {}
  }

  /// Best-effort delete of the files behind every file-backed item in
  /// [media] (links have nothing on disk).
  static Future<void> deleteAll(Iterable<StarMedia> media) async {
    for (final item in media) {
      final path = item.path;
      if (item.isFile && path != null) await delete(path);
    }
  }

  /// Removes every stored extra — used by "reset all data".
  static Future<void> clear() async {
    if (kIsWeb) {
      await web.clearMedia();
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/star_media');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
