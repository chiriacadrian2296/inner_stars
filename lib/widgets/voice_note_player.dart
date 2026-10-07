import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import 'play_badge.dart';
import 'voice_note_recorder_sheet.dart' show formatVoiceDuration;

/// One voice note as a card: a play badge, a waveform that fills as it
/// plays (tap it to jump) and the length. Owns its own [AudioPlayer],
/// set to mix with other audio so it never interrupts (or gets interrupted
/// by) the Cosmo's background loop — see `AudioService`.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.media, this.framed = true});

  final StarMedia media;

  /// Whether it draws its own card — off when it sits inside a field
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
  Source? _source;

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
        final Source? source;
        if (kIsWeb) {
          final bytes = await StarMediaStorage.readBytes(widget.media.path!);
          source = bytes == null ? null : BytesSource(bytes);
        } else {
          final file = await StarMediaStorage.file(widget.media.path!);
          _filePath = file?.path;
          source = file == null ? null : DeviceFileSource(file.path);
        }
        if (source == null) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        player = AudioPlayer();
        await player.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
        _player = player;
        _source = source;
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
        await player.play(source);
        return;
      }
      if (_playing) {
        await player.pause();
      } else if (_finished) {
        _finished = false;
        await player.play(_source ?? DeviceFileSource(_filePath!));
      } else {
        await player.resume();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Jumps playback to [fraction] of the note — only once it has started;
  /// before that a tap on the bars simply starts it.
  Future<void> _seekTo(double fraction) async {
    final player = _player;
    if (player == null || _total == Duration.zero) {
      await _toggle();
      return;
    }
    try {
      final target = _total * fraction.clamp(0.0, 1.0);
      await player.seek(target);
      if (mounted) setState(() => _position = target);
    } catch (_) {}
  }

  /// The voice note's play badge — a good deal smaller than the one on a
  /// video, since this is a compact row.
  static const _badgeSize = 26.0;

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        // Framed, it's a transparent pill with a thin white outline, like a
        // link — not a solid card.
        decoration: widget.framed
            ? ShapeDecoration(
                color: colors.night.withValues(alpha: 0.4),
                shape: StadiumBorder(
                  side: const BorderSide(color: Colors.white, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            _failed
                ? Icon(Icons.error_outline, color: colors.muted, size: 26)
                : PlayBadge(size: _badgeSize, playing: _playing),
            const SizedBox(width: 8),
            Expanded(
              child: _failed
                  ? Text(
                      strings.mediaError,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _seekTo(
                          details.localPosition.dx / constraints.maxWidth,
                        ),
                        child: SizedBox(
                          height: 18,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _WaveformPainter(
                              seed: widget.media.id.hashCode,
                              progress: progress,
                              played: Colors.white,
                              rest: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if (!_failed) ...[
              const SizedBox(width: 8),
              Text(
                formatVoiceDuration(_playing ? _position : total),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A voice note's bars: a fixed, per-note shape (seeded by its id, so each
/// note keeps its own) that fills white as playback advances.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.played,
    required this.rest,
  });

  final int seed;
  final double progress;
  final Color played;
  final Color rest;

  static const _barWidth = 3.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_barWidth + _gap)).floor();
    if (count <= 0) return;
    final random = math.Random(seed);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;
    // Neighbouring bars drift rather than jump, so it reads as speech.
    var level = 0.5;
    for (var i = 0; i < count; i++) {
      level = (level + (random.nextDouble() - 0.5) * 0.7).clamp(0.2, 1.0);
      final x = i * (_barWidth + _gap) + _barWidth / 2;
      final half = size.height * level / 2;
      paint.color = (i + 0.5) / count <= progress ? played : rest;
      canvas.drawLine(
        Offset(x, size.height / 2 - half),
        Offset(x, size.height / 2 + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.played != played ||
      old.rest != rest;
}
