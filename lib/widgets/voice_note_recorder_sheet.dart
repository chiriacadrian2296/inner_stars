import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';

/// What a finished recording hands back: the stored file name and length.
typedef VoiceNoteRecording = ({String path, int durationMs});

/// Longest a single voice note can run before it stops by itself.
const Duration kMaxVoiceNote = Duration(minutes: 2);

String formatVoiceDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Records a voice note from the microphone and returns it once the user
/// keeps it, or null if they cancel. The finished file is already moved into
/// [StarMediaStorage].
Future<VoiceNoteRecording?> showVoiceNoteRecorder(BuildContext context) {
  return showAppSheet<VoiceNoteRecording>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _VoiceNoteRecorderSheet(),
  );
}

enum _Phase { idle, recording, recorded }

class _VoiceNoteRecorderSheet extends StatefulWidget {
  const _VoiceNoteRecorderSheet();

  @override
  State<_VoiceNoteRecorderSheet> createState() =>
      _VoiceNoteRecorderSheetState();
}

class _VoiceNoteRecorderSheetState extends State<_VoiceNoteRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  _Phase _phase = _Phase.idle;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _tempPath;
  bool _denied = false;
  bool _failed = false;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_recorder.dispose());
    _discardTemp();
    super.dispose();
  }

  void _discardTemp() {
    final path = _tempPath;
    _tempPath = null;
    if (path == null) return;
    if (kIsWeb) return;
    unawaited(File(path).delete().then((_) {}, onError: (_) {}));
  }

  Future<void> _start() async {
    setState(() {
      _denied = false;
      _failed = false;
    });
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      _discardTemp();
      final path = kIsWeb ? '' : await StarMediaStorage.newRecordingPath();
      await _recorder.start(const RecordConfig(), path: path);
      if (!kIsWeb) _tempPath = path;
      if (!mounted) return;
      setState(() {
        _phase = _Phase.recording;
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        final next = _elapsed + const Duration(milliseconds: 250);
        if (next >= kMaxVoiceNote) {
          unawaited(_stop());
        } else {
          setState(() => _elapsed = next);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    try {
      final result = await _recorder.stop();
      if (result != null) _tempPath = result;
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.recorded);
  }

  Future<void> _keep() async {
    final temp = _tempPath;
    if (temp == null) return;
    try {
      final stored = kIsWeb
          ? await StarMediaStorage.save(XFile(temp), fallbackExtension: 'webm')
          : await StarMediaStorage.saveRecording(temp);
      _tempPath = null;
      if (!mounted) return;
      Navigator.of(context)
          .pop((path: stored, durationMs: _elapsed.inMilliseconds));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final recording = _phase == _Phase.recording;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSheetTitle(strings.recordVoiceTitle),
            const SizedBox(height: 24),
            Center(
              child: Text(
                formatVoiceDuration(_elapsed),
                style: TextStyle(
                  color: recording ? colors.gold : colors.muted,
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: IconButton.outlined(
                iconSize: 32,
                padding: const EdgeInsets.all(18),
                tooltip: recording ? strings.recordStop : strings.recordStart,
                onPressed: recording ? _stop : _start,
                icon: Icon(
                  recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: colors.gold,
                ),
              ),
            ),
            if (_denied || _failed) ...[
              const SizedBox(height: 16),
              Text(
                _denied ? strings.micPermissionDenied : strings.mediaError,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: AppButtonLabel(strings.cancel),
                ),
                if (_phase == _Phase.recorded && !_failed) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _keep,
                    child: AppButtonLabel(strings.recordKeep),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
