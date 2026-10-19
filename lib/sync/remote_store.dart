import 'merge.dart';

/// The remote copy of the data. Firestore implements this later; tests use
/// [InMemoryRemoteStore].
abstract class RemoteStore {
  /// Records of [collection] changed after [since] (all of them when null),
  /// tombstones included.
  Future<List<SyncRecord>> fetchChangesSince(
    String collection,
    DateTime? since,
  );

  /// Stores [records], replacing any remote record with the same id.
  Future<void> push(String collection, List<SyncRecord> records);
}

class InMemoryRemoteStore implements RemoteStore {
  final Map<String, Map<String, SyncRecord>> data = {};

  /// When set, the next call throws it, to simulate being offline.
  Object? failNext;

  void _check() {
    final error = failNext;
    if (error == null) return;
    failNext = null;
    throw error;
  }

  @override
  Future<List<SyncRecord>> fetchChangesSince(
    String collection,
    DateTime? since,
  ) async {
    _check();
    return [
      for (final record in (data[collection] ?? const {}).values)
        if (since == null ||
            DateTime.parse(record['updatedAt'] as String).isAfter(since))
          Map<String, dynamic>.from(record),
    ];
  }

  @override
  Future<void> push(String collection, List<SyncRecord> records) async {
    _check();
    final bucket = data.putIfAbsent(collection, () => {});
    for (final record in records) {
      bucket[record['id'] as String] = Map<String, dynamic>.from(record);
    }
  }
}
