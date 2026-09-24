import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import 'staggered_entrance.dart';

/// Shows [child] while [visible], and animates it both ways: on the way in
/// it fades, drifts and opens up its own space; on the way out the exact
/// reverse, and only then is it taken out of the tree. Whatever shares the
/// row with it grows or shrinks smoothly to match, instead of jumping.
///
/// For something that comes and goes with a mode (the search's filter
/// button, which only exists outside Supernovas). Mounting and unmounting
/// on its own gives an entrance at best and a pop on the way out.
///
/// The child keeps its full size at all times and is only revealed, anchored
/// to the end edge of its slot — so its position and size never change while
/// it animates, which keeps a guided tour's spotlight steady if it points at
/// something inside it.
class AnimatedPresence extends StatefulWidget {
  const AnimatedPresence({
    super.key,
    required this.visible,
    required this.child,
    this.axis = Axis.horizontal,
    this.entranceIndex = 0,
  });

  final bool visible;
  final Widget child;
  final Axis axis;

  /// When it is already visible on first build, its place in the page's
  /// entrance cascade (see [StaggeredEntrance]).
  final int entranceIndex;

  @override
  State<AnimatedPresence> createState() => _AnimatedPresenceState();
}

class _AnimatedPresenceState extends State<AnimatedPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  Timer? _delay;

  // The last child shown, kept so the exit still has something to draw once
  // the parent has stopped providing it.
  Widget? _lastChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kMotionBase);
    _curved = CurvedAnimation(
      parent: _controller,
      curve: kMotionEnter,
      reverseCurve: kMotionExit,
    );
    if (widget.visible) {
      _lastChild = widget.child;
      final delay =
          StaggeredEntrance.step *
          widget.entranceIndex.clamp(0, StaggeredEntrance.maxDelaySteps);
      if (delay == Duration.zero) {
        _controller.forward();
      } else {
        _delay = Timer(delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = motionDuration(context, kMotionBase);
  }

  @override
  void didUpdateWidget(AnimatedPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    _delay?.cancel();
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visible) _lastChild = widget.child;
    final child = _lastChild;
    if (child == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      // Fully gone: out of the tree, so it costs nothing and can't be hit.
      builder: (context, _) => !widget.visible && _controller.isDismissed
          ? const SizedBox.shrink()
          : _buildTransition(context, child),
    );
  }

  Widget _buildTransition(BuildContext context, Widget child) {
    final horizontal = widget.axis == Axis.horizontal;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final begin = horizontal
        ? Offset(rtl ? -0.15 : 0.15, 0)
        : const Offset(0, 0.15);
    return SizeTransition(
      axis: widget.axis,
      // Anchored to the end edge, so the child never moves relative to it
      // while its slot opens.
      alignment: horizontal
          ? AlignmentDirectional.centerEnd
          : Alignment.bottomCenter,
      sizeFactor: _curved,
      child: FadeTransition(
        opacity: _curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(_curved),
          child: child,
        ),
      ),
    );
  }
}
