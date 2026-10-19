import 'package:flutter/foundation.dart';

import 'local_collection.dart';
import 'merge.dart';

/// A repository backed by a list collection that can be synced. It reads
/// SharedPreferences on every access, so applying remote records only needs
/// to notify listeners afterwards.
mixin SyncableRepository on ChangeNotifier {
  /// Remote collection name.
  String get syncName;

  /// The persisted collection behind this repository.
  SyncCollection get syncCollection;

  /// Writes the remote records that win the merge and notifies listeners.
  /// Returns how many local records changed.
  Future<int> applyRemote(List<SyncRecord> records) async {
    final changed = await syncCollection.applyRemote(records);
    if (changed > 0) notifyListeners();
    return changed;
  }
}
