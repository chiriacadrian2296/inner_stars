import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'voice_note_recorder_sheet.dart' show formatVoiceDuration;

/// Compact play/pause row for one voice note. Owns its own [AudioPlayer],
/// set to mix with other audio so it never interrupts (or gets interrupted
/// by) the Cosmo's background loop — see `AudioService`.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.media, this.framed = true});

  final StarMedia media;

  /// Whether it draws its own outline — off when it sits inside a field
  /// that already has one.
  final bool framed;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _player;
  StreamSubscription<void>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  bool _playing = false;
  Duration _position = Duration.zero;
  bool _failed = false;
  String? _filePath;

  /// Set once playback ran to the end: a finished player can't be resumed,
  /// the source has to be played again from the start.
  bool _finished = false;

  Duration get _total => Duration(milliseconds: widget.media.durationMs ?? 0);

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      var player = _player;
      if (player == null) {
        final file = await StarMediaStorage.file(widget.media.path!);
        if (file == null) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        player = AudioPlayer();
        await player.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
        _player = player;
        _filePath = file.path;
        _stateSub = player.onPlayerStateChanged.listen((state) {
          if (!mounted) return;
          setState(() {
            _playing = state == PlayerState.playing;
            if (state == PlayerState.completed) {
              _position = Duration.zero;
              _finished = true;
            }
          });
        });
        _posSub = player.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        });
        await player.play(DeviceFileSource(file.path));
        return;
      }
      if (_playing) {
        await player.pause();
      } else if (_finished) {
        _finished = false;
        await player.play(DeviceFileSource(_filePath!));
      } else {
        await player.resume();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final total = _total;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _failed ? null : _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: widget.framed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusField),
                border: Border.all(color: colors.muted.withValues(alpha: 0.35)),
              )
            : null,
        child: Row(
          children: [
            IconButton(
              onPressed: _failed ? null : _toggle,
              icon: Icon(
                _failed
                    ? Icons.error_outline
                    : _playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: colors.gold,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _failed
                        ? strings.mediaError
                        : strings.voiceNoteLabel(
                            formatVoiceDuration(_playing ? _position : total),
                          ),
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    color: colors.gold,
                    backgroundColor: colors.muted.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
