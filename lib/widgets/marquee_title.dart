import 'package:flutter/material.dart';

/// A looping, news-ticker title. It remains still when it fits; otherwise it
/// starts left-aligned, pauses briefly, then slides until its duplicate has
/// taken exactly the same place before pausing and repeating.
class MarqueeTitle extends StatefulWidget {
  const MarqueeTitle({
    super.key,
    required this.title,
    required this.style,
    this.pause = const Duration(milliseconds: 500),
    this.scrollDuration = const Duration(seconds: 6),
  });

  final String title;
  final TextStyle style;
  final Duration pause;
  final Duration scrollDuration;

  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(MarqueeTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pause != widget.pause ||
        oldWidget.scrollDuration != widget.scrollDuration) {
      _controller.dispose();
      _configureController();
    }
  }

  void _configureController() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.scrollDuration + widget.pause * 2,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.title, style: widget.style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width <= constraints.maxWidth) {
        return Center(
          child: Text(widget.title, maxLines: 1, style: widget.style),
        );
      }
      const gap = 48.0;
      final travel = painter.width + gap;
      final total = widget.scrollDuration + widget.pause * 2;
      final pauseFraction = widget.pause.inMicroseconds / total.inMicroseconds;
      final progress = CurvedAnimation(
        parent: _controller,
        curve: Interval(pauseFraction, 1 - pauseFraction),
      );
      return Semantics(
        label: widget.title,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) => Stack(
              children: [
                Positioned(
                  left: -travel * progress.value,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title, maxLines: 1, style: widget.style),
                      const SizedBox(width: gap),
                      Text(widget.title, maxLines: 1, style: widget.style),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
