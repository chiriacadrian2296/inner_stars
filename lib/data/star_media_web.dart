import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

final Future<Database> _database = idbFactoryNative.open(
  'inner-stars-star-media',
  version: 1,
  onUpgradeNeeded: (event) => event.database.createObjectStore('media'),
);

Future<void> writeMedia(String id, Uint8List bytes) async {
  final transaction = (await _database).transaction('media', idbModeReadWrite);
  await transaction.objectStore('media').put(bytes, id);
  await transaction.completed;
}

Future<Uint8List> readMedia(String id) async {
  final transaction = (await _database).transaction('media', idbModeReadOnly);
  final value = await transaction.objectStore('media').getObject(id);
  await transaction.completed;
  if (value == null) throw StateError('Missing star media');
  return value is Uint8List
      ? value
      : Uint8List.fromList((value as List).cast<int>());
}

Future<void> deleteMedia(String id) async {
  final transaction = (await _database).transaction('media', idbModeReadWrite);
  await transaction.objectStore('media').delete(id);
  await transaction.completed;
}

Future<void> clearMedia() async {
  final transaction = (await _database).transaction('media', idbModeReadWrite);
  await transaction.objectStore('media').clear();
  await transaction.completed;
}
