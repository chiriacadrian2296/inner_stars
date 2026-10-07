import 'package:flutter/material.dart';

/// The one size a play mark is drawn at — on video thumbnails and voice notes
/// alike.
const double kPlayBadgeSize = 40;

/// A white play (or pause) button: a white ring and glyph. The one "this plays"
/// mark for videos and voice notes alike. Videos put a navy veil under it, so
/// it needs no outline of its own to read on a picture.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, required this.size, this.playing = false});

  final double size;

  /// Shows a pause glyph instead of the play triangle.
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
