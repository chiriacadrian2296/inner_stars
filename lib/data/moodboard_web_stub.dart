import 'dart:typed_data';

Future<void> writeMedia(String id, Uint8List bytes) =>
    throw UnsupportedError('Web only');
Future<Uint8List> readMedia(String id) => throw UnsupportedError('Web only');
Future<void> deleteMedia(String id) => throw UnsupportedError('Web only');
