import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'reader_entry_content.dart' show ReaderEntrance;

/// One button in the reader's bottom bar.
class ReaderAction {
  const ReaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.off = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  /// Drawn dark instead of gold: the star this belongs to is off, and this is
  /// what switches it on (or, on a burning pulsar, off). A dark button that
  /// can be pressed also beckons — its icon shakes and flashes gold every
  /// couple of seconds (see [ReaderActionButton]).
  final bool off;
}

/// The reader's bottom bar between the two arrows: every action available
/// for the page, kept icon-only so the content above remains the focus.
class ReaderActionBar extends StatelessWidget {
  const ReaderActionBar({
    super.key,
    required this.actions,
    required this.entrance,
    this.reverseOrder = false,
  });

  final List<ReaderAction> actions;

  /// Runs the cascade from the last button to the first.
  final bool reverseOrder;

  /// How each button arrives — see [ReaderEntrance].
  final ReaderEntrance entrance;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: _gap,
      runSpacing: _gap,
      children: [
        for (var i = 0; i < actions.length; i++)
          entrance(
            7 + (reverseOrder ? actions.length - 1 - i : i),
            ReaderActionButton(
              icon: actions[i].icon,
              label: actions[i].label,
              onTap: actions[i].onTap,
              loading: actions[i].loading,
              off: actions[i].off,
            ),
          ),
      ],
    );
  }
}

/// The gold pill every action shares — an icon and label together inside one
/// [StadiumBorder], or just the icon when [compact].
///
/// An [off] button that can be pressed beckons: every [_beckonPeriod] its
/// icon gives the same little shake as the big star above the calendar in
/// the stats (only more often), and lights up gold for as long as it lasts.
class ReaderActionButton extends StatefulWidget {
  const ReaderActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.off = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  /// Dark and muted instead of gold.
  final bool off;

  static const iconSize = 20.0;
  static const _verticalPadding = 14.0;

  // The stats' big star shakes every 5 seconds; this one is meant to be
  // noticed more, so it repeats about twice as often. The first shake comes
  // soon after the page settles rather than a whole period later.
  static const _beckonPeriod = Duration(milliseconds: 2500);
  static const _firstBeckonDelay = Duration(milliseconds: 900);
  static const _shakeDuration = Duration(milliseconds: 500);

  @override
  State<ReaderActionButton> createState() => _ReaderActionButtonState();
}

class _ReaderActionButtonState extends State<ReaderActionButton>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: ReaderActionButton._shakeDuration,
  );
  Timer? _timer;
  bool _reduceMotion = false;

  bool get _beckons =>
      widget.off && widget.onTap != null && !widget.loading && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTimer();
  }

  @override
  void didUpdateWidget(ReaderActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (_beckons) {
      _timer ??= Timer(ReaderActionButton._firstBeckonDelay, _beckon);
    } else {
      _timer?.cancel();
      _timer = null;
      _shake.value = 0;
    }
  }

  void _beckon() {
    if (!mounted) return;
    _shake.forward(from: 0);
    _timer = Timer(ReaderActionButton._beckonPeriod, _beckon);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final off = widget.off;
    final foreground = widget.onTap == null && !widget.loading
        ? colors.muted
        : colors.gold;
    final Widget leading;
    if (widget.loading) {
      leading = SizedBox(
        width: ReaderActionButton.iconSize,
        height: ReaderActionButton.iconSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    } else if (off) {
      leading = AnimatedBuilder(
        animation: _shake,
        builder: (context, _) {
          final t = _shake.value;
          // The big star's own shake (sideways, fading out over three
          // swings), scaled to an icon this small; the gold swells and
          // fades with the same beat.
          final dx = math.sin(t * math.pi * 6) * (1 - t) * 3;
          final glow = math.sin(t * math.pi);
          final icon = Icon(
            widget.icon,
            size: ReaderActionButton.iconSize,
            color: Color.lerp(colors.muted, colors.gold, glow),
          );
          return Transform.translate(
            offset: Offset(dx, 0),
            child: glow < 0.02
                ? icon
                // A blurred copy of the icon behind it, so the glow follows
                // the glyph's own outline (same trick as `IntensityBolts`),
                // fading in and out with the gold — same size as the icon,
                // so nothing grows.
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Icon(
                          widget.icon,
                          size: ReaderActionButton.iconSize,
                          color: colors.gold.withValues(alpha: 0.75 * glow),
                        ),
                      ),
                      icon,
                    ],
                  ),
          );
        },
      );
    } else {
      leading = Icon(
        widget.icon,
        color: foreground,
        size: ReaderActionButton.iconSize,
      );
    }
    final pill = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(ReaderActionButton._verticalPadding),
          child: leading,
        ),
      ),
    );
    return Tooltip(message: widget.label, child: pill);
  }
}
