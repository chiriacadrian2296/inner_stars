import 'package:shared_preferences/shared_preferences.dart';

import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';
import 'moodboard_repository.dart';
import 'moodboard_storage.dart';
import 'photo_storage.dart';
import 'repository_write.dart';
import 'shooting_star_wish_repository.dart';
import 'star_media_storage.dart';
import 'star_repository.dart';

/// Older storage keys that may still hold copies of data now kept elsewhere.
const _legacyKeys = ['reflection-answers-v1'];

/// Removes the user's content from this device, for real: the stored records
/// are deleted outright (no tombstones), together with the photos, recordings
/// and moodboard files. Settings, the app lock and the schema markers stay.
///
/// Tombstones are the difference from the repositories' `clear()`: those mean
/// "this was deleted" and a sync would carry that deletion to the cloud, while
/// this only empties the device, and a later sync brings the cloud copy back.
Future<void> wipeLocalData({
  required SharedPreferences prefs,
  required StarRepository stars,
  required MoodboardRepository moodboard,
  required List<SyncableRepository> repositories,
}) async {
  // Files first, while the records that name them can still be read.
  for (final star in stars.getAll(includeDeleted: true)) {
    final photo = star.photoPath;
    if (photo != null) await PhotoStorage.delete(photo);
  }
  await StarMediaStorage.clear();
  for (final item in moodboard.getAll(includeDeleted: true)) {
    if (item.kind != MoodboardKind.quote) {
      await MoodboardStorage.delete(item.content);
    }
  }

  for (final repository in repositories) {
    final collection = repository.syncCollection;
    if (collection is LocalCollection) {
      await writeRepositoryValue(prefs, collection.key, null);
    }
  }
  await writeRepositoryValue(
    prefs,
    ShootingStarWishRepository.legacyStorageKey,
    null,
  );
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith(legacyMoodboardPrefix) || _legacyKeys.contains(key)) {
      await writeRepositoryValue(prefs, key, null);
    }
  }

  for (final repository in repositories) {
    repository.refreshFromStorage();
  }
}
