import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repository_write.dart';
import 'media_remote.dart';

enum MediaOp { upload, delete }

/// How long a job waits after its [attempts]-th failure: 2 minutes, then 4, 8
/// and so on, never more than 6 hours.
Duration mediaRetryDelay(int attempts) =>
    Duration(minutes: (1 << attempts.clamp(1, 9)).clamp(2, 360));

/// One pending change to the cloud copy of a media file.
class MediaJob {
  const MediaJob({
    required this.folder,
    required this.id,
    required this.op,
    this.attempts = 0,
    this.retryAt,
  });

  final MediaFolder folder;
  final String id;
  final MediaOp op;

  /// How many times this job has failed.
  final int attempts;

  /// Not before this time, after a failure. Null for a job never tried or
  /// ready to go.
  final DateTime? retryAt;

  String get name => mediaName(folder, id);

  bool isDue(DateTime now) => retryAt == null || !retryAt!.isAfter(now);

  MediaJob failed(DateTime now) => MediaJob(
    folder: folder,
    id: id,
    op: op,
    attempts: attempts + 1,
    retryAt: now.add(mediaRetryDelay(attempts + 1)),
  );

  Map<String, dynamic> toJson() => {
    'folder': folder.name,
    'id': id,
    'op': op.name,
    'attempts': attempts,
    if (retryAt != null) 'retryAt': retryAt!.toUtc().toIso8601String(),
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
      retryAt: DateTime.tryParse('${json['retryAt'] ?? ''}'),
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

  /// Records a failed try and holds the job back for a while (see
  /// [mediaRetryDelay]). A job is never dropped for failing: the cause may be
  /// temporary (offline, a service not yet switched on).
  Future<void> fail(MediaJob job, DateTime now) async {
    await _write([
      for (final other in jobs)
        if (other.name == job.name && other.op == job.op)
          other.failed(now)
        else
          other,
    ]);
  }

  Future<void> clear() => _write(const []);
}
