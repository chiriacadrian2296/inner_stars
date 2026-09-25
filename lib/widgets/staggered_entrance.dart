import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Fades [child] in with a short drift, delayed by [index] so a group of
/// them arrives one after another instead of all at once.
///
/// [axis] follows the layout the items sit in, so the motion reads as the
/// content settling into place rather than decoration: things stacked in a
/// column rise from below ([Axis.vertical]); things laid out side by side
/// (tiles, chips, a row of stats) slide in from the reading-direction end
/// ([Axis.horizontal], mirrored for right-to-left).
///
/// It only animates what the person can actually see. Once laid out, an
/// item that sits outside the screen (below the fold of a scroll view, or
/// built early by a lazy list) just appears, at no cost — so each screen
/// animates exactly as many items as it shows, on any device size, without
/// a hand-tuned limit.
///
/// Plays when first mounted, and again whenever [replayKey] changes — for
/// content that swaps in place (the star form's kind, the search's mode)
/// rather than being rebuilt from scratch, which would otherwise keep the
/// already-played state and pop in silently.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.axis = Axis.vertical,
    this.replayKey,
    this.enabled = true,
    this.reverse = false,
    this.drift = 0.06,
  });

  final int index;
  final Widget child;
  final Axis axis;

  /// Restarts the entrance when it changes between builds.
  final Object? replayKey;

  /// False shows [child] as-is, for the life of this widget's state — for
  /// a swap that already has an animation of its own.
  final bool enabled;

  /// Flips the horizontal direction, so it enters from the start edge
  /// instead of the end — for content that arrives from the side the person
  /// just navigated toward, like the previous star in a swipe.
  final bool reverse;

  /// How far a vertical entrance rises from, as a fraction of the child's own
  /// height. Small text blocks need a larger value than cards to read at all.
  final double drift;

  /// Delay between consecutive items.
  static const step = Duration(milliseconds: 40);

  /// A ceiling on the delay, in steps, so a screen with many items on view
  /// never makes the last ones wait for long.
  static const maxDelaySteps = 12;

  /// Wraps each of [children] in a [StaggeredEntrance], numbered from
  /// [start], for a literal `children:` list. Pass only the content blocks,
  /// not spacers, or the gaps eat indices and stretch the cascade.
  static List<Widget> all(
    List<Widget> children, {
    int start = 0,
    Axis axis = Axis.vertical,
    Object? replayKey,
  }) {
    return [
      for (var i = 0; i < children.length; i++)
        StaggeredEntrance(
          index: start + i,
          axis: axis,
          replayKey: replayKey,
          child: children[i],
        ),
    ];
  }

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  // Created only for items that turn out to be on screen.
  AnimationController? _controller;
  CurvedAnimation? _curved;
  Timer? _delay;

  // Hidden until the first layout says whether this item is visible.
  Animation<double> _progress = kAlwaysDismissedAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _progress = kAlwaysDismissedAnimation;
      _scheduleDecision();
    } else {
      _progress = kAlwaysCompleteAnimation;
    }
  }

  @override
  void didUpdateWidget(StaggeredEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && widget.replayKey != oldWidget.replayKey) {
      _delay?.cancel();
      _controller?.value = 0;
      _progress = _controller == null ? kAlwaysDismissedAnimation : _curved!;
      _scheduleDecision();
    }
  }

  /// After layout, plays the entrance if the item is on screen and shows it
  /// straight away if not.
  void _scheduleDecision() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context) || !_isOnScreen()) {
        setState(() => _progress = kAlwaysCompleteAnimation);
        return;
      }
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: kMotionSlow,
      );
      final curved = _curved ??= CurvedAnimation(
        parent: controller,
        curve: kMotionEnter,
      );
      setState(() => _progress = curved);
      final steps = widget.index.clamp(0, StaggeredEntrance.maxDelaySteps);
      final delay = StaggeredEntrance.step * steps;
      if (delay == Duration.zero) {
        controller.forward(from: 0);
      } else {
        _delay = Timer(delay, () {
          if (mounted) controller.forward(from: 0);
        });
      }
    });
  }

  bool _isOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    return (box.localToGlobal(Offset.zero) & box.size).overlaps(screen);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fractions of the child's own size: a tall block drifts further than a
    // small chip, which keeps the motion proportionate to what moves.
    final fromEnd =
        (Directionality.of(context) == TextDirection.rtl) == widget.reverse;
    final begin = widget.axis == Axis.vertical
        ? Offset(0, widget.drift)
        : Offset(fromEnd ? 0.12 : -0.12, 0);
    return FadeTransition(
      opacity: _progress,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(_progress),
        child: widget.child,
      ),
    );
  }
}
