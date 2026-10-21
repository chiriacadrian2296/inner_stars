import 'dart:async';

import 'media_remote.dart';
import 'media_sync.dart';

/// How the file storages tell the cloud sync that something changed, without
/// depending on it: they call these, and nothing happens until the app has
/// set [instance] (signed in, sync available). Remote placeholders used by
/// sample data (http addresses) are never sent anywhere.
class MediaHooks {
  static MediaSync? instance;

  static bool _syncable(String id) => !id.startsWith('http');

  /// A file was written on this device.
  static void saved(MediaFolder folder, String id) {
    final sync = instance;
    if (sync == null || !_syncable(id)) return;
    unawaited(sync.fileSaved(folder, id).then((_) => sync.kick()));
  }

  /// A file was removed from this device.
  static void deleted(MediaFolder folder, String id) {
    final sync = instance;
    if (sync == null || !_syncable(id)) return;
    unawaited(sync.fileDeleted(folder, id).then((_) => sync.kick()));
  }

  /// A file a record points to is missing here: try to get it from the cloud.
  static Future<bool> fetch(MediaFolder folder, String id) async {
    final sync = instance;
    if (sync == null || !_syncable(id)) return false;
    return sync.ensureLocal(folder, id);
  }
}
