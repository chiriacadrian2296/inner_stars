import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Gives [child] a small "pressed in" response — a slight shrink and dim
/// while a finger is down on it.
///
/// It listens with a raw [Listener] rather than a `GestureDetector`, so it
/// never joins the gesture arena: the `InkWell`/`onTap` underneath (and any
/// long-press timing a parent does by hand) behaves exactly as before. Flat
/// on purpose — scale and opacity only, no glow.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
  });

  final Widget child;

  /// The size the child settles at while pressed.
  final double scale;

  /// When false the child is passed through untouched (a disabled button).
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final duration = motionDuration(context, kMotionFast);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: duration,
        curve: kMotionEnter,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: duration,
          curve: kMotionEnter,
          child: widget.child,
        ),
      ),
    );
  }
}
