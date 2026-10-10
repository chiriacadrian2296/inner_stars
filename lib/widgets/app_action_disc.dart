import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// PARKED (2026-09-11): every call site now uses `SaveActionButton`/
/// `PillActionButton` (pill_action_button.dart) instead — the round
/// FAB-style disc didn't read as clearly against its background as the
/// pill shape does. Kept here rather than deleted in case the round shape
/// comes back; nothing in the app references this file right now.
///
/// The round primary action at the bottom of every form — save a star,
/// create a constellation — and its destructive sibling.
///
/// A form's disc is the clearest place in the app where the whole grammar
/// shows up at once: it's dark and flat while the form is incomplete, and
/// the moment everything required is there it fills gold and starts
/// glowing. You light it the same way you light a star — the same
/// lit/glow mechanic `SaveActionButton` now carries forward.
///
/// Was copy-pasted at three call sites with slightly different shadows.
/// [lit] now decides fill, glow and foreground together, so there's no way
/// to end up with a gold disc that doesn't work or a dead-looking one that
/// does — and an unlit disc keeps its [onPressed] so it can explain *why*
/// it isn't lit rather than sitting there inert.
class AppActionDisc extends StatelessWidget {
  const AppActionDisc({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.heroTag,
    this.lit = true,
    this.tooltip,
    this.boldPlus = false,
  }) : _danger = false;

  /// The destructive variant: danger-colored, and never glowing — a delete
  /// button that lit up would be saying the wrong thing entirely.
  const AppActionDisc.danger({
    super.key,
    required this.onPressed,
    required this.heroTag,
    this.tooltip,
  }) : icon = Icons.delete_outline,
       lit = false,
       boldPlus = false,
       _danger = true;

  final IconData icon;
  final VoidCallback? onPressed;
  final Object heroTag;

  /// Whether the action is actually available.
  final bool lit;

  final String? tooltip;

  /// Draws a thick, rounded "+" in place of [icon] — Material's own `add`
  /// glyph only comes in one thin weight.
  final bool boldPlus;

  final bool _danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Navy like the page, with the icon and a rim in gold (muted while it is
    // not available); the danger variant keeps its solid red.
    final accent = lit ? colors.gold : colors.muted;
    final background = _danger ? colors.danger : colors.night;
    final foreground = _danger ? colors.night : accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: lit ? goldGlow(colors, strength: 1.1, size: 56) : null,
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: background,
        shape: _danger
            ? const CircleBorder()
            : CircleBorder(side: BorderSide(color: accent, width: 2)),
        tooltip: tooltip,
        child: boldPlus
            ? _BoldPlus(color: foreground)
            : Icon(icon, color: foreground),
      ),
    );
  }
}

class _BoldPlus extends StatelessWidget {
  const _BoldPlus({required this.color});

  final Color color;

  static const _length = 20.0;
  static const _thickness = 4.0;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_thickness / 2),
      ),
    );
    return SizedBox.square(
      dimension: _length,
      child: Stack(
        alignment: Alignment.center,
        children: [bar(_length, _thickness), bar(_thickness, _length)],
      ),
    );
  }
}
