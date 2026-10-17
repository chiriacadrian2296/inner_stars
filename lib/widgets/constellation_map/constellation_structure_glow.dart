import 'package:flutter/material.dart';

final _erase = Paint()..blendMode = BlendMode.clear;

/// Paints [body] and then erases the complete discs, so translucent nodes
/// never reveal graph lines. The discs are cleared in a layer rather than
/// clipped out with `Path.combine`, whose difference is unreliable on web.
void paintOutsideDiscs(
  Canvas canvas,
  Rect bounds,
  List<(Offset, double)> discs,
  VoidCallback body,
) {
  canvas.saveLayer(bounds, Paint());
  body();
  for (final (center, radius) in discs) {
    canvas.drawCircle(center, radius, _erase);
  }
  canvas.restore();
}

/// The same two light layers as the graph, outside a tooltip's frame only.
class ConstellationTooltipGlowPainter extends CustomPainter {
  const ConstellationTooltipGlowPainter({
    required this.frameWidth,
    required this.radius,
  });
  final double frameWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.saveLayer(rect.inflate(frameWidth * 8), Paint());
    for (final (alpha, blur) in const [(0.45, 1.6), (0.65, 0.65)]) {
      canvas.drawRRect(
        outer.deflate(frameWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = frameWidth
          ..color = Colors.white.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, frameWidth * blur),
      );
    }
    canvas.drawRRect(outer, _erase);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConstellationTooltipGlowPainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth || oldDelegate.radius != radius;
}

/// Blurred light outside the graph's solid strokes and circular discs.
/// Erasing whole discs also prevents nearby edges from lighting their
/// interiors, including discs with semi-transparent photos.
class ConstellationStructureGlowPainter extends CustomPainter {
  const ConstellationStructureGlowPainter({
    required this.segments,
    required this.discs,
    required this.strokeWidth,
    required this.color,
    this.focusedDiscIndex,
    this.inactiveOpacity = 1,
  });

  final List<(Offset, Offset)> segments;
  final List<(Offset, double)> discs;
  final double strokeWidth;
  final Color color;
  final int? focusedDiscIndex;
  final double inactiveOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;
    final half = strokeWidth / 2;
    final graph = Path();
    final selectedGraph = Path();
    final strokes = Path();
    for (var i = 0; i < discs.length; i++) {
      final (center, radius) = discs[i];
      if (radius > half) {
        (i == focusedDiscIndex ? selectedGraph : graph).addOval(
          Rect.fromCircle(center: center, radius: radius - half),
        );
      }
    }
    for (final (a, b) in segments) {
      final delta = b - a;
      if (delta.distance < 0.001) continue;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance * half;
      strokes.addPolygon([
        a + normal,
        b + normal,
        b - normal,
        a - normal,
      ], true);
      graph.moveTo(a.dx, a.dy);
      graph.lineTo(b.dx, b.dy);
    }
    paintOutsideDiscs(canvas, Offset.zero & size, discs, () {
      for (final (alpha, blur) in const [(0.45, 1.6), (0.65, 0.65)]) {
        for (final (path, opacity) in [
          (graph, focusedDiscIndex == null ? 1.0 : inactiveOpacity),
          (selectedGraph, 1.0),
        ]) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = color.withValues(alpha: alpha * opacity)
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                strokeWidth * blur,
              ),
          );
        }
      }
      // The sharp strokes are painted separately; keep their own area dark.
      canvas.drawPath(strokes, _erase);
    });
  }

  @override
  bool shouldRepaint(ConstellationStructureGlowPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.discs != discs ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.focusedDiscIndex != focusedDiscIndex ||
      oldDelegate.inactiveOpacity != inactiveOpacity ||
      oldDelegate.color != color;
}
