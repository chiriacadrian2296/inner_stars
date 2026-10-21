import 'package:shared_preferences/shared_preferences.dart';

import '../../data/moodboard_repository.dart';
import '../../models/star.dart';
import '../../models/star_media.dart';
import 'media_remote.dart';
import 'media_sync.dart';

/// Queues the media this device already had before the cloud copy existed, so
/// an account's older photos, voice notes and moodboard pictures reach the
/// cloud too. Runs once per account on a device; later changes are queued by
/// the storages as they happen.
Future<void> backfillMedia({
  required SharedPreferences prefs,
  required String uid,
  required MediaSync sync,
  required Iterable<Star> stars,
  required Iterable<MoodboardItem> moodboard,
}) async {
  // v2: web recordings (WebM) were never queued before, so every device queues
  // its media once more.
  final key = 'sync.$uid.media-backfilled-v2';
  if (prefs.getBool(key) ?? false) return;
  for (final star in stars) {
    if (star.deleted) continue;
    final photo = star.photoPath;
    if (photo != null && !photo.startsWith('http')) {
      await sync.fileSaved(MediaFolder.photos, photo);
    }
    for (final item in star.media) {
      final path = item.path;
      if (item.kind == StarMediaKind.voice &&
          path != null &&
          !path.startsWith('http')) {
        await sync.fileSaved(MediaFolder.voices, path);
      }
    }
  }
  for (final item in moodboard) {
    if (item.deleted || item.kind != MoodboardKind.photo) continue;
    await sync.fileSaved(MediaFolder.moodboard, item.content);
  }
  await prefs.setBool(key, true);
}
