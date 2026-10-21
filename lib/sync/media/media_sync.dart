import 'dart:async';
import 'dart:typed_data';

import 'media_queue.dart';
import 'media_remote.dart';
import 'photo_compression.dart';

/// Where this device keeps its copy of the media files. The photo, voice and
/// moodboard storages implement it.
abstract interface class MediaLocal {
  /// The bytes for [id], or null when this device does not have the file.
  Future<Uint8List?> read(MediaFolder folder, String id);

  /// Keeps [bytes] on the device under [id].
  Future<void> write(MediaFolder folder, String id, Uint8List bytes);
}

/// Sends media to the cloud and brings it back when another device made it.
///
/// Records sync through Firestore and carry only the file's id; this keeps the
/// files themselves. A change is queued on the device (so it survives a
/// restart and being offline) and [process] sends the queue. A file another
/// device made is not downloaded ahead of time: [ensureLocal] fetches it the
/// first time something asks for it.
class MediaSync {
  MediaSync({
    required this.queue,
    required this.local,
    required this.remoteFor,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MediaQueue queue;
  final MediaLocal local;
  final DateTime Function() _now;

  /// The cloud for the signed-in account, or null when there is none (signed
  /// out, or working offline in a development build).
  final MediaRemote? Function() remoteFor;

  bool _processing = false;
  Timer? _timer;
  final Map<String, Future<bool>> _downloads = {};

  /// Runs [process] soon; several calls inside [after] become one run.
  void kick([Duration after = const Duration(seconds: 2)]) {
    _timer?.cancel();
    _timer = Timer(after, () => unawaited(process()));
  }

  void dispose() => _timer?.cancel();

  /// A file was added or replaced locally: queue its upload.
  Future<void> fileSaved(MediaFolder folder, String id) =>
      queue.enqueue(folder, id, MediaOp.upload);

  /// A file was removed locally: queue the removal of its cloud copy.
  Future<void> fileDeleted(MediaFolder folder, String id) =>
      queue.enqueue(folder, id, MediaOp.delete);

  /// Sends the queued changes that are due, oldest first. Stops at the first
  /// failure (most likely offline): that job waits longer each time it fails
  /// (see [mediaRetryDelay]) but is never dropped, so a cause that is only
  /// temporary, such as a service not yet switched on, loses nothing. Returns
  /// how many jobs finished.
  Future<int> process() async {
    final remote = remoteFor();
    if (remote == null || _processing) return 0;
    _processing = true;
    var done = 0;
    try {
      for (final job in queue.jobs) {
        if (!job.isDue(_now())) continue;
        try {
          await _run(remote, job);
          await queue.complete(job);
          done++;
        } catch (_) {
          await queue.fail(job, _now());
          break;
        }
      }
    } finally {
      _processing = false;
    }
    _scheduleNextRetry();
    return done;
  }

  /// Wakes [process] up again when the earliest held-back job is due.
  void _scheduleNextRetry() {
    final waiting = [
      for (final job in queue.jobs)
        if (job.retryAt != null) job.retryAt!,
    ]..sort();
    if (waiting.isEmpty) return;
    final wait = waiting.first.difference(_now());
    kick(
      wait < const Duration(seconds: 30) ? const Duration(seconds: 30) : wait,
    );
  }

  Future<void> _run(MediaRemote remote, MediaJob job) async {
    if (job.op == MediaOp.delete) {
      await remote.delete(job.name);
      return;
    }
    final bytes = await local.read(job.folder, job.id);
    // Gone from this device since it was queued: nothing left to send.
    if (bytes == null) return;
    final ready = job.folder == MediaFolder.voices
        ? bytes
        : compressPhoto(bytes);
    if (ready.length > kMaxMediaBytes) return;
    await remote.upload(job.name, ready, mediaContentType(job.folder, job.id));
  }

  /// Makes sure this device has [id], downloading it when it does not.
  /// Returns whether the file is available afterwards. Several callers asking
  /// for the same file share one download.
  Future<bool> ensureLocal(MediaFolder folder, String id) {
    final name = mediaName(folder, id);
    return _downloads[name] ??= _fetch(folder, id).whenComplete(() {
      _downloads.remove(name);
    });
  }

  Future<bool> _fetch(MediaFolder folder, String id) async {
    if (await local.read(folder, id) != null) return true;
    final remote = remoteFor();
    if (remote == null) return false;
    try {
      final bytes = await remote.download(mediaName(folder, id));
      if (bytes == null) return false;
      await local.write(folder, id, bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes every media file of the account from the cloud (account
  /// deletion). Returns how many it removed.
  Future<int> deleteAllRemote() async {
    final remote = remoteFor();
    if (remote == null) return 0;
    final names = await remote.list();
    for (final name in names) {
      await remote.delete(name);
    }
    await queue.clear();
    return names.length;
  }

  /// Removes cloud files no record refers to any more. [referenced] is every
  /// name (see [mediaName]) that some live record points to; call it only
  /// after a complete sync, or a file another device just referenced could be
  /// taken for an orphan. Files still waiting in the queue are kept.
  Future<int> removeOrphans(Set<String> referenced) async {
    final remote = remoteFor();
    if (remote == null) return 0;
    final waiting = {for (final job in queue.jobs) job.name};
    var removed = 0;
    for (final name in await remote.list()) {
      if (referenced.contains(name) || waiting.contains(name)) continue;
      await remote.delete(name);
      removed++;
    }
    return removed;
  }
}
