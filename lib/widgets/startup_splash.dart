import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// One overlay for the lifetime of a cold launch, above the root navigator.
/// Its child remains mounted and paints Galaxy while resources are prepared.
/// Returning from the background never resets this state.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.ready,
    required this.child,
    required this.onDismissed,
    required this.loadingLabel,
    required this.tagline,
    this.failed = false,
  });

  final bool ready;
  final bool failed;
  final Widget child;
  final VoidCallback onDismissed;
  final String loadingLabel;
  final String tagline;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with TickerProviderStateMixin {
  late final _charge = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();
  late final _exit =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _dismissed = true);
          widget.onDismissed();
        }
      });
  bool _dismissed = false;
  bool _exiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeExit();
  }

  @override
  void didUpdateWidget(StartupSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeExit();
  }

  void _maybeExit() {
    if (widget.failed) {
      _charge.stop();
      _exit.stop();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _charge.stop();
    } else if (!widget.ready &&
        !_exiting &&
        _charge.value < 1 &&
        !_charge.isAnimating) {
      _charge.forward();
    }
    if (!widget.ready || _exiting || _dismissed) return;
    _exiting = true;
    _charge.stop();
    // No minimum splash duration: ready means the destination has painted.
    _exit.duration = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 450);
    _exit.forward();
  }

  @override
  void dispose() {
    _charge.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showing = !_dismissed && !widget.failed;
    final quiet = MediaQuery.disableAnimationsOf(context);
    final logo = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/icon/Logo.svg',
        width: 150,
        height: 150,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(AppColors.dark.gold, BlendMode.srcIn),
      ),
    );
    return PopScope(
      canPop: !showing,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: showing,
            child: IgnorePointer(ignoring: showing, child: widget.child),
          ),
          if (showing)
            AnimatedBuilder(
              animation: Listenable.merge([_charge, _exit]),
              builder: (context, _) {
                final light = quiet
                    ? .65
                    : Curves.easeOut.transform(_charge.value);
                return Opacity(
                  opacity: 1 - Curves.easeInOut.transform(_exit.value),
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Colors.transparent,
                    ),
                    child: Semantics(
                      label: widget.loadingLabel,
                      liveRegion: true,
                      child: ColoredBox(
                        key: const ValueKey('startup-splash'),
                        color: AppColors.dark.night,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const RepaintBoundary(
                              child: CustomPaint(painter: _SplashAtmosphere()),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 190,
                                      height: 150,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Fixed, small blur surfaces; only opacity
                                          // changes, never a fullscreen blur/shader.
                                          Opacity(
                                            opacity: .08 + .62 * light,
                                            child: ImageFiltered(
                                              imageFilter: ui.ImageFilter.blur(
                                                sigmaX: 14,
                                                sigmaY: 14,
                                              ),
                                              child: logo,
                                            ),
                                          ),
                                          Opacity(
                                            opacity: .2 + .65 * light,
                                            child: ImageFiltered(
                                              imageFilter: ui.ImageFilter.blur(
                                                sigmaX: 5,
                                                sigmaY: 5,
                                              ),
                                              child: logo,
                                            ),
                                          ),
                                          logo,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Inner Stars',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: kFontBranding,
                                        fontSize: 31,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                        color: AppColors.dark.text,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.tagline,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: kFontStarTitle,
                                        fontSize: 18,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                        color: Color(0xFFC3C4CE),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SplashAtmosphere extends CustomPainter {
  const _SplashAtmosphere();

  @override
  void paint(Canvas canvas, Size size) {
    final short = size.shortestSide;
    for (final (center, radius, color) in [
      (
        Offset(size.width * .28, size.height * .42),
        short * .8,
        const Color(0x9934538B),
      ),
      (
        Offset(size.width * .73, size.height * .55),
        short * .65,
        const Color(0x8072512E),
      ),
    ]) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_SplashAtmosphere oldDelegate) => false;
}
