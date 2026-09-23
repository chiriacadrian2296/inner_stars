import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:inner_stars/utils/responsive.dart';
// M3Carousel does not expose infinite; its underlying wrapper does.
// Keep m3_carousel pinned until this adapter is verified against an upgrade.
// ignore: implementation_imports
import 'package:m3_carousel/src/carousel_wrapper.dart';
// ignore: implementation_imports
import 'package:m3_carousel/src/carousel_view.dart' as m3;

/// The package's centered Hero layout, with snapping and circular navigation.
class LoopingHeroCarousel extends StatefulWidget {
  const LoopingHeroCarousel({
    super.key,
    required this.children,
    required this.onTap,
    this.freeScroll = false,
  }) : assert(children.length >= 3);

  final List<Widget> children;
  final ValueChanged<int> onTap;
  final bool freeScroll;

  @override
  State<LoopingHeroCarousel> createState() => _LoopingHeroCarouselState();
}

class _LoopingHeroCarouselState extends State<LoopingHeroCarousel> {
  final _controller = m3.CarouselController();
  double _dragDistance = 0;
  bool _animating = false;

  @override
  void didUpdateWidget(covariant LoopingHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.freeScroll != widget.freeScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final extent = _controller.position.viewportDimension * 0.2;
        if (extent > 0) {
          _controller.jumpTo((_controller.offset / extent).round() * extent);
        }
      });
    }
  }

  Future<void> _step(DragEndDetails details, double width) async {
    if (_animating || !_controller.hasClients) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDistance.abs() < 12 && velocity.abs() < 150) return;
    final direction = (_dragDistance.abs() >= 12 ? _dragDistance : velocity) < 0
        ? 1
        : -1;
    await _move(direction, width);
  }

  Future<void> _move(int direction, double width) async {
    if (_animating || !_controller.hasClients) return;
    // In the [2, 6, 2] layout one item advances by the leading 20% slot.
    // Disable ballistic scrolling: even a long, fast swipe advances once.
    final extent = width * 0.2;
    final target = (_controller.offset / extent).round() + direction;
    await _animateTo(target * extent);
  }

  void _tapCard(int index, double width) {
    if (_animating || !_controller.hasClients) return;
    final extent = width * 0.2;
    final center = _controller.offset / extent + 1;
    final count = widget.children.length;
    final delta = (index - center + count / 2) % count - count / 2;
    if (delta.abs() < 0.25) {
      widget.onTap((index - 1) % count);
    } else {
      _animateTo(_controller.offset + delta * extent);
    }
  }

  Future<void> _animateTo(double offset) async {
    _animating = true;
    try {
      await _controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _animating = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The first slot is a preview; put the last area there so the first
    // area starts in the large center slot, with circular neighbors.
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onHorizontalDragStart: widget.freeScroll
                ? null
                : (_) => _dragDistance = 0,
            onHorizontalDragUpdate: widget.freeScroll
                ? null
                : (details) => _dragDistance += details.primaryDelta ?? 0,
            onHorizontalDragEnd: widget.freeScroll
                ? null
                : (details) => _step(details, constraints.maxWidth),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ...ScrollConfiguration.of(context).dragDevices,
                  PointerDeviceKind.mouse,
                },
              ),
              child: CarouselWrapper(
                controller: _controller,
                infinite: true,
                freeScroll: widget.freeScroll,
                itemSnapping: true,
                consumeMaxWeight: false,
                flexWeights: const [2, 6, 2],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                onTap: (index) => _tapCard(index, constraints.maxWidth),
                children: [
                  for (var index = 0; index < widget.children.length; index++)
                    AnimatedBuilder(
                      animation: _controller,
                      child:
                          widget.children[(index - 1) % widget.children.length],
                      builder: (context, child) {
                        final extent = constraints.maxWidth * 0.2;
                        final center = _controller.hasClients && extent > 0
                            ? _controller.offset / extent + 1
                            : 1.0;
                        final count = widget.children.length;
                        final distance =
                            ((index - center + count / 2) % count - count / 2)
                                .abs();
                        final side = distance.clamp(0.0, 1.0);
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 24 * side),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                HeroCarouselEmphasis(side: side, child: child!),
                                IgnorePointer(
                                  child: ColoredBox(
                                    color: Colors.black.withValues(
                                      alpha: 0.3 * side,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black,
                  ],
                  stops: [0, 0.08, 0.92, 1],
                ),
              ),
            ),
          ),
          if (!isTouchOnlyMobile)
            for (final direction in [-1, 1])
              Positioned(
                // Center the controls in the 20% side slots.
                left: direction < 0 ? constraints.maxWidth * 0.10 - 24 : null,
                right: direction > 0 ? constraints.maxWidth * 0.10 - 24 : null,
                top: constraints.maxHeight / 2 - 24,
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: direction < 0
                      ? MaterialLocalizations.of(context).previousPageTooltip
                      : MaterialLocalizations.of(context).nextPageTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D1220),
                    side: const BorderSide(
                      color: Color(0xFF0D1220),
                      width: 2.5,
                    ),
                    iconSize: 32,
                    padding: const EdgeInsets.all(4),
                  ),
                  onPressed: () => _move(direction, constraints.maxWidth),
                  icon: Icon(
                    direction < 0 ? Icons.chevron_left : Icons.chevron_right,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Continuous position: zero for the centered card, one for side previews.
class HeroCarouselEmphasis extends InheritedWidget {
  const HeroCarouselEmphasis({
    super.key,
    required this.side,
    required super.child,
  });

  final double side;

  static double sideOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HeroCarouselEmphasis>()
          ?.side ??
      1;

  @override
  bool updateShouldNotify(HeroCarouselEmphasis oldWidget) =>
      side != oldWidget.side;
}
