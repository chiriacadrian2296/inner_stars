import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repository_write.dart';
import 'media_remote.dart';

enum MediaOp { upload, delete }

/// One pending change to the cloud copy of a media file.
class MediaJob {
  const MediaJob({
    required this.folder,
    required this.id,
    required this.op,
    this.attempts = 0,
  });

  final MediaFolder folder;
  final String id;
  final MediaOp op;
  final int attempts;

  String get name => mediaName(folder, id);

  MediaJob failed() =>
      MediaJob(folder: folder, id: id, op: op, attempts: attempts + 1);

  Map<String, dynamic> toJson() => {
    'folder': folder.name,
    'id': id,
    'op': op.name,
    'attempts': attempts,
  };

  static MediaJob? fromJson(Object? json) {
    if (json is! Map) return null;
    final folder = MediaFolder.values.where((f) => f.name == json['folder']);
    final op = MediaOp.values.where((o) => o.name == json['op']);
    final id = json['id'];
    if (folder.isEmpty || op.isEmpty || id is! String) return null;
    return MediaJob(
      folder: folder.first,
      id: id,
      op: op.first,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The media changes that still have to reach the cloud, kept on the device
/// so they survive a restart. One job per file: a later change replaces an
/// earlier one, and an upload cancelled by a delete never leaves the device.
class MediaQueue {
  MediaQueue(this._prefs);

  static const storageKey = 'sync.media-queue-v1';
  final SharedPreferences _prefs;

  List<MediaJob> get jobs {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const [];
    try {
      return [
        for (final entry in jsonDecode(raw) as List) ?MediaJob.fromJson(entry),
      ];
    } catch (_) {
      return const [];
    }
  }

  bool get isEmpty => jobs.isEmpty;

  Future<void> _write(List<MediaJob> jobs) => writeRepositoryValue(
    _prefs,
    storageKey,
    jobs.isEmpty ? null : jsonEncode([for (final j in jobs) j.toJson()]),
  );

  /// Queues [op] for [id], replacing any job already waiting for that file.
  Future<void> enqueue(MediaFolder folder, String id, MediaOp op) async {
    final name = mediaName(folder, id);
    final rest = [
      for (final job in jobs)
        if (job.name != name) job,
    ];
    await _write([...rest, MediaJob(folder: folder, id: id, op: op)]);
  }

  Future<void> complete(MediaJob job) async {
    await _write([
      for (final other in jobs)
        if (other.name != job.name || other.op != job.op) other,
    ]);
  }

  /// Records a failed try, so a file that keeps failing can be given up on.
  Future<void> fail(MediaJob job) async {
    await _write([
      for (final other in jobs)
        if (other.name == job.name && other.op == job.op)
          other.failed()
        else
          other,
    ]);
  }

  Future<void> clear() => _write(const []);
}
