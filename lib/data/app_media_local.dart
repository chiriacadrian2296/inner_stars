import 'dart:typed_data';

import '../sync/media/media_remote.dart';
import '../sync/media/media_sync.dart';
import 'moodboard_storage.dart';
import 'photo_storage.dart';
import 'star_media_storage.dart';

/// The device's own copy of the media files, for [MediaSync]: it reads and
/// writes through the existing photo, voice-note and moodboard storages, using
/// the methods that never ask the cloud and never queue an upload.
class AppMediaLocal implements MediaLocal {
  @override
  Future<Uint8List?> read(MediaFolder folder, String id) {
    switch (folder) {
      case MediaFolder.photos:
        return PhotoStorage.readLocalBytes(id);
      case MediaFolder.voices:
        return StarMediaStorage.readLocal(id);
      case MediaFolder.moodboard:
        return MoodboardStorage.readLocal(id);
    }
  }

  @override
  Future<void> write(MediaFolder folder, String id, Uint8List bytes) {
    switch (folder) {
      case MediaFolder.photos:
        return PhotoStorage.writeAs(id, bytes);
      case MediaFolder.voices:
        return StarMediaStorage.writeAs(id, bytes);
      case MediaFolder.moodboard:
        return MoodboardStorage.writeAs(id, bytes);
    }
  }
}
