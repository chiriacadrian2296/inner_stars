import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'merge.dart';
import 'remote_store.dart';

/// One stored document: the record as JSON text plus the server time of the
/// write.
class RemoteDoc {
  const RemoteDoc({required this.id, required this.data, required this.at});
  final String id;
  final String data;
  final DateTime at;
}

/// The thin layer over Firestore, so the store's own logic can be tested
/// without the network.
abstract class FirestorePort {
  Future<List<RemoteDoc>> readSince(String collection, DateTime? cursor);
  Future<void> writeBatch(String collection, List<RemoteDocWrite> docs);

  /// Deletes up to [limit] documents of [collection]; returns how many it
  /// deleted (0 when the collection is empty).
  Future<int> deleteSome(String collection, int limit);
}

class RemoteDocWrite {
  const RemoteDocWrite({
    required this.id,
    required this.data,
    required this.updatedAt,
    required this.deleted,
  });
  final String id;
  final String data;
  final String updatedAt;
  final bool deleted;
}

/// Stores each record as a document `users/{uid}/{collection}/{id}` with the
/// whole record as JSON text in `data` (Firestore rejects nested lists, which
/// some records contain), next to `id`, `updatedAt` and `deleted` for
/// readability in the console, and a server-side `_syncedAt` that pulls order
/// by.
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._port);

  final FirestorePort _port;

  /// Firestore allows 500 writes per batch.
  static const batchSize = 400;

  static String documentId(String recordId) => Uri.encodeComponent(recordId);

  @override
  Future<RemoteChanges> fetchChangesSince(
    String collection,
    DateTime? cursor,
  ) async {
    final docs = await _port.readSince(collection, cursor);
    var newest = cursor;
    final records = <SyncRecord>[];
    for (final doc in docs) {
      records.add(Map<String, dynamic>.from(jsonDecode(doc.data) as Map));
      if (newest == null || doc.at.isAfter(newest)) newest = doc.at;
    }
    return RemoteChanges(records, newest);
  }

  @override
  Future<void> deleteCollection(String collection) async {
    while (await _port.deleteSome(collection, batchSize) > 0) {}
  }

  @override
  Future<void> push(String collection, List<SyncRecord> records) async {
    for (var i = 0; i < records.length; i += batchSize) {
      final chunk = records.skip(i).take(batchSize);
      await _port.writeBatch(collection, [
        for (final record in chunk)
          RemoteDocWrite(
            id: documentId(record['id'] as String),
            data: jsonEncode(record),
            updatedAt: record['updatedAt'] as String,
            deleted: record['deleted'] == true,
          ),
      ]);
    }
  }
}

/// The real Firestore behind [FirestorePort], scoped to one user.
class FirebaseFirestorePort implements FirestorePort {
  FirebaseFirestorePort(this.uid, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  /// A write that never completes (offline) must not hang the sync forever.
  static const timeout = Duration(seconds: 30);

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _db.collection('users').doc(uid).collection(name);

  @override
  Future<List<RemoteDoc>> readSince(String collection, DateTime? cursor) async {
    Query<Map<String, dynamic>> query = _collection(collection);
    if (cursor != null) {
      query = query.where(
        '_syncedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(cursor),
      );
    }
    // Straight from the server: a stale local cache must not pose as news.
    final snapshot = await query
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    return [
      for (final doc in snapshot.docs)
        RemoteDoc(
          id: doc.id,
          data: doc.data()['data'] as String,
          at: (doc.data()['_syncedAt'] as Timestamp).toDate(),
        ),
    ];
  }

  @override
  Future<int> deleteSome(String collection, int limit) async {
    final snapshot = await _collection(collection)
        .limit(limit)
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (snapshot.docs.isEmpty) return 0;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit().timeout(timeout);
    return snapshot.docs.length;
  }

  @override
  Future<void> writeBatch(String collection, List<RemoteDocWrite> docs) async {
    final batch = _db.batch();
    final ref = _collection(collection);
    for (final doc in docs) {
      batch.set(ref.doc(doc.id), {
        'id': doc.id,
        'updatedAt': doc.updatedAt,
        'deleted': doc.deleted,
        'data': doc.data,
        '_syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit().timeout(timeout);
  }
}
