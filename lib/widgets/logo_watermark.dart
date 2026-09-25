import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/star_kind.dart';
import '../theme/app_colors.dart';

/// The reader pages' backdrop: the app logo (`Logo.svg`, no background) as a
/// big watermark in [color] (alpha included, see [logoWatermarkColor]),
/// filling most of the page at [scale] of its full size. A new [color] or
/// [scale] eases from the previous one in place, and a change of [pulse]
/// plays a short glide toward [pulseDirection] and back — for a move that
/// changes neither, so the logo still answers it.
class LogoWatermark extends StatefulWidget {
  const LogoWatermark({
    super.key,
    required this.color,
    this.scale = 1,
    this.pulse = 0,
    this.pulseDirection = -1,
    this.duration = const Duration(milliseconds: 300),
  });

  final Color color;

  /// 1 fills the page; less shrinks the logo around its center (see
  /// [logoWatermarkScale]).
  final double scale;

  /// Bump this to play the glide.
  final int pulse;

  /// Which way the glide goes: -1 toward the left edge, 1 toward the right.
  final double pulseDirection;

  /// How long a change of [color] or [scale] takes.
  final Duration duration;

  /// Logo.svg's shapes only span ~45% x 64% of its own box (the rest is
  /// margin), so the box is sized off those to make the *shapes* cover this
  /// fraction of the page's width/height, whichever is tighter.
  static const _shapeWidthFraction = 0.45;
  static const _shapeHeightFraction = 0.64;
  static const _pageCoverage = 0.85;

  @override
  State<LogoWatermark> createState() => _LogoWatermarkState();
}

class _LogoWatermarkState extends State<LogoWatermark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  /// How far the logo drifts at the peak of the glide, as a fraction of its
  /// own size.
  static const _glideDistance = 0.012;

  @override
  void didUpdateWidget(LogoWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) _glide.forward(from: 0);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final scale = widget.scale;
    final duration = widget.duration;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side =
              math.min(
                constraints.maxWidth / LogoWatermark._shapeWidthFraction,
                constraints.maxHeight / LogoWatermark._shapeHeightFraction,
              ) *
              LogoWatermark._pageCoverage;
          // Min 0 too: the page's own tight constraints would otherwise be
          // inherited as the minimum, which is bigger than [side] on the
          // tight axis and makes the constraints invalid.
          return OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: side,
            maxHeight: side,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              curve: Curves.easeInOut,
              builder: (context, tint, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: scale),
                duration: duration,
                curve: Curves.easeInOut,
                builder: (context, factor, child) => AnimatedBuilder(
                  animation: _glide,
                  child: child,
                  builder: (context, child) {
                    // Out toward [pulseDirection] and back home, eased both
                    // ways.
                    final drift = math.sin(
                      Curves.easeInOut.transform(_glide.value) * math.pi,
                    );
                    return Transform.translate(
                      offset: Offset(
                        widget.pulseDirection *
                            side *
                            _glideDistance *
                            drift,
                        0,
                      ),
                      child: Transform.scale(scale: factor, child: child),
                    );
                  },
                ),
                child: SvgPicture.asset(
                  'assets/icon/Logo.svg',
                  width: side,
                  height: side,
                  colorFilter: ColorFilter.mode(
                    tint ?? color,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The watermark color for a page about a [kind] of star, alpha included —
/// built from the theme's own colors: gold eased toward white for anything
/// burning (a lit star, a pulsar that kept its rhythm), so it reads cream
/// rather than brown at this transparency; the night gradient's blues,
/// brightened toward the unlit-star and dead-star blues, for anything dark
/// (dead one step darker than unlit); and white for a slot still empty.
Color logoWatermarkColor(
  AppColors colors,
  StarKind kind, {
  bool lit = true,
}) {
  final burning = Color.lerp(colors.gold, Colors.white, 0.55)!;
  final dark = Color.lerp(
    colors.nightlightGradientCenter,
    colors.starUnlit,
    0.8,
  )!;
  final dead = Color.lerp(
    colors.nightlightGradientOuter,
    colors.starDead,
    0.7,
  )!;
  final color = switch (kind) {
    StarKind.lit => burning,
    StarKind.pulsar => lit ? burning : dark,
    StarKind.unlit => dark,
    StarKind.nascent => Colors.white,
    StarKind.dead => dead,
  };
  return color.withValues(alpha: _opacity);
}

const _opacity = 0.25;

/// How big the watermark is, by state: full size for anything burning, a bit
/// smaller for anything dark, smallest for a slot still empty or a dead star.
double logoWatermarkScale(StarKind kind, {bool lit = true}) =>
    switch (kind) {
      StarKind.lit => 1,
      StarKind.pulsar => lit ? 1 : 0.85,
      StarKind.unlit => 0.85,
      StarKind.nascent || StarKind.dead => 0.75,
    };
