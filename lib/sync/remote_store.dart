import 'merge.dart';

/// What a pull returned: the records, and the server-side position to resume
/// from next time. The cursor comes from the server's own clock, never from
/// the records' `updatedAt`, so a device whose clock runs behind cannot push
/// changes that every other device then skips.
class RemoteChanges {
  const RemoteChanges(this.records, this.cursor);
  final List<SyncRecord> records;

  /// The newest server time seen, or the cursor that was asked for when
  /// nothing came back.
  final DateTime? cursor;
}

/// The remote copy of the data. Firestore implements this; tests use
/// [InMemoryRemoteStore].
abstract class RemoteStore {
  /// Records of [collection] written at or after [cursor] (all of them when
  /// null), tombstones included. "At or after" means the boundary records come
  /// back again, which is harmless because merging is idempotent.
  Future<RemoteChanges> fetchChangesSince(String collection, DateTime? cursor);

  /// Stores [records], replacing any remote record with the same id, and
  /// stamps them with the server's time.
  Future<void> push(String collection, List<SyncRecord> records);
}

class InMemoryRemoteStore implements RemoteStore {
  final Map<String, Map<String, ({SyncRecord record, DateTime at})>> data = {};

  /// The server clock: moves forward by a second on every push.
  DateTime serverTime = DateTime.utc(2026, 1, 1);

  /// When set, the next call throws it, to simulate being offline.
  Object? failNext;

  /// The records of [collection], without their server times.
  Map<String, SyncRecord> records(String collection) => {
    for (final e in (data[collection] ?? const {}).entries)
      e.key: e.value.record,
  };

  void _check() {
    final error = failNext;
    if (error == null) return;
    failNext = null;
    throw error;
  }

  @override
  Future<RemoteChanges> fetchChangesSince(
    String collection,
    DateTime? cursor,
  ) async {
    _check();
    final out = <SyncRecord>[];
    var newest = cursor;
    for (final entry in (data[collection] ?? const {}).values) {
      if (cursor != null && entry.at.isBefore(cursor)) continue;
      out.add(Map<String, dynamic>.from(entry.record));
      if (newest == null || entry.at.isAfter(newest)) newest = entry.at;
    }
    return RemoteChanges(out, newest);
  }

  @override
  Future<void> push(String collection, List<SyncRecord> records) async {
    _check();
    serverTime = serverTime.add(const Duration(seconds: 1));
    final bucket = data.putIfAbsent(collection, () => {});
    for (final record in records) {
      bucket[record['id'] as String] = (
        record: Map<String, dynamic>.from(record),
        at: serverTime,
      );
    }
  }
}
