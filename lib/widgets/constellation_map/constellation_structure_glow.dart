import 'package:flutter/material.dart';

/// Blurred light outside the graph's solid strokes and circular discs.
/// Subtracting whole discs also prevents nearby edges from lighting their
/// interiors, including discs with semi-transparent photos.
class ConstellationStructureGlowPainter extends CustomPainter {
  const ConstellationStructureGlowPainter({
    required this.segments,
    required this.discs,
    required this.strokeWidth,
    required this.color,
  });

  final List<(Offset, Offset)> segments;
  final List<(Offset, double)> discs;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;
    final half = strokeWidth / 2;
    final graph = Path();
    var outside = Path()..addRect(Offset.zero & size);
    canvas.save();
    for (final (center, radius) in discs) {
      outside = Path.combine(
        PathOperation.difference,
        outside,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
      if (radius > half) {
        graph.addOval(Rect.fromCircle(center: center, radius: radius - half));
      }
    }
    for (final (a, b) in segments) {
      final delta = b - a;
      if (delta.distance < 0.001) continue;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance * half;
      outside = Path.combine(
        PathOperation.difference,
        outside,
        Path()
          ..addPolygon([a + normal, b + normal, b - normal, a - normal], true),
      );
      graph.moveTo(a.dx, a.dy);
      graph.lineTo(b.dx, b.dy);
    }
    canvas.clipPath(outside);
    for (final (alpha, blur) in const [(0.45, 1.6), (0.65, 0.65)]) {
      canvas.drawPath(
        graph,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * blur),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConstellationStructureGlowPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.discs != discs ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color;
}
