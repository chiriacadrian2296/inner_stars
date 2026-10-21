import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'media_remote.dart';

/// The account's media files in Firebase Storage, under
/// `users/{uid}/media/<folder>/<file>`. The rules in `storage.rules` let only
/// that account read and write there, with a size and type limit.
class FirebaseMediaRemote implements MediaRemote {
  FirebaseMediaRemote(this.uid, {FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final String uid;
  final FirebaseStorage _storage;

  String get _root => 'users/$uid/media';

  Reference _ref(String name) => _storage.ref('$_root/$name');

  static bool _isMissing(FirebaseException error) =>
      error.code == 'object-not-found';

  @override
  Future<void> upload(String name, Uint8List bytes, String contentType) async {
    await _ref(name).putData(bytes, SettableMetadata(contentType: contentType));
  }

  @override
  Future<Uint8List?> download(String name) async {
    try {
      return await _ref(name).getData(kMaxMediaBytes);
    } on FirebaseException catch (error) {
      if (_isMissing(error)) return null;
      rethrow;
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      await _ref(name).delete();
    } on FirebaseException catch (error) {
      if (!_isMissing(error)) rethrow;
    }
  }

  @override
  Future<List<String>> list() async {
    final names = <String>[];
    Future<void> walk(Reference folder) async {
      final result = await folder.listAll();
      for (final item in result.items) {
        names.add(item.fullPath.substring(_root.length + 1));
      }
      for (final prefix in result.prefixes) {
        await walk(prefix);
      }
    }

    await walk(_storage.ref(_root));
    return names;
  }
}
