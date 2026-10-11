import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/celebration_stats.dart';
import '../../utils/accumulation_chart_data.dart';

/// Monotone cumulative curve with precise day-based inspection.
class AccumulationChart extends StatefulWidget {
  const AccumulationChart({
    super.key,
    required this.points,
    required this.dateLabel,
    required this.axisLabel,
  });
  final List<CelebrationPoint> points;
  final String Function(DateTime) dateLabel;
  final String axisLabel;
  @override
  State<AccumulationChart> createState() => _AccumulationChartState();
}

class _AccumulationChartState extends State<AccumulationChart> {
  int? _selectedDay;
  @override
  void didUpdateWidget(AccumulationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (chartDay(oldWidget.points.first.date) !=
            chartDay(widget.points.first.date) ||
        chartDay(oldWidget.points.last.date) !=
            chartDay(widget.points.last.date)) {
      _selectedDay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay == null
        ? null
        : accumulationAtDay(widget.points, _selectedDay!);
    final colors = context.colors;
    return Semantics(
      label:
          '${widget.axisLabel}: ${widget.points.first.total} – ${widget.points.last.total}. ${widget.dateLabel(widget.points.first.date)} – ${widget.dateLabel(widget.points.last.date)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.axisLabel, style: context.typography.supporting),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = _AccumulationPainter(
                widget.points,
                colors,
                context.typography.supporting,
                Directionality.of(context),
                MediaQuery.textScalerOf(context),
                widget.dateLabel,
                selected,
              );
              final height =
                  280.0 +
                  30 *
                      (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                        0,
                        3,
                      );
              void select(Offset position) {
                final plot = painter.plotRect(
                  Size(constraints.maxWidth, height),
                );
                if (plot.width <= 0) return;
                final fraction = ((position.dx - plot.left) / plot.width).clamp(
                  0.0,
                  1.0,
                );
                final first = chartDay(widget.points.first.date);
                final last = chartDay(widget.points.last.date);
                setState(
                  () => _selectedDay =
                      first + (fraction * (last - first)).round(),
                );
              }

              return GestureDetector(
                key: const ValueKey('accumulation-chart-touch'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => select(details.localPosition),
                onHorizontalDragStart: (details) =>
                    select(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    select(details.localPosition),
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: height,
                    width: double.infinity,
                    child: CustomPaint(painter: painter),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              selected == null
                  ? '${widget.dateLabel(widget.points.first.date)} – ${widget.dateLabel(widget.points.last.date)}'
                  : '${widget.dateLabel(selected.date)} · ${selected.total}',
              key: const ValueKey('accumulation-chart-selection'),
              style: context.typography.body.copyWith(
                color: selected == null ? colors.muted : colors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccumulationPainter extends CustomPainter {
  const _AccumulationPainter(
    this.points,
    this.colors,
    this.style,
    this.direction,
    this.scaler,
    this.dateLabel,
    this.selected,
  );
  final List<CelebrationPoint> points;
  final AppColors colors;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler scaler;
  final String Function(DateTime) dateLabel;
  final CelebrationPoint? selected;
  int get step => accumulationTickStep(points.last.total);
  int get maximum => math.max(step, (points.last.total / step).ceil() * step);
  TextPainter label(String value, {bool highlight = false}) => TextPainter(
    text: TextSpan(
      text: value,
      style: style.copyWith(color: highlight ? colors.gold : colors.muted),
    ),
    textDirection: direction,
    textScaler: scaler,
  )..layout();
  Rect plotRect(Size size) {
    final text = label('$maximum');
    return Rect.fromLTRB(
      text.width * 2 + 24,
      text.height + 12,
      size.width - 16,
      size.height - text.height * 2 - 34,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;
    final first = chartDay(points.first.date);
    final span = math.max(1, chartDay(points.last.date) - first);
    double x(DateTime date) =>
        plot.left + (chartDay(date) - first) / span * plot.width;
    double y(num total) => plot.bottom - total / maximum * plot.height;
    final grid = Paint()
      ..color = colors.nightBorder
      ..strokeWidth = 1;
    for (var value = 0; value <= maximum; value += step) {
      final vertical = y(value);
      canvas.drawLine(
        Offset(plot.left, vertical),
        Offset(plot.right, vertical),
        grid,
      );
      final text = label('$value');
      text.paint(canvas, Offset(0, vertical - text.height / 2));
    }
    final shortRange = span <= 31;
    String tickLabel(DateTime date) =>
        shortRange ? '${date.day}' : dateLabel(date);
    final longestDate = math.max(
      label(tickLabel(points.first.date)).width,
      label(tickLabel(points.last.date)).width,
    );
    final maxTicks = (plot.width / (longestDate + 10)).floor().clamp(2, 8);
    final ticks = accumulationDateTicks(
      points.first.date,
      points.last.date,
      maxTicks,
    );
    var previousLabelEnd = double.negativeInfinity;
    for (final date in ticks) {
      final horizontal = x(date);
      final text = label(tickLabel(date));
      final left = (horizontal - text.width / 2)
          .clamp(0.0, math.max(0.0, size.width - text.width))
          .toDouble();
      if (left < previousLabelEnd + 8) continue;
      previousLabelEnd = left + text.width;
      canvas.drawLine(
        Offset(horizontal, plot.top),
        Offset(horizontal, plot.bottom + 5),
        grid,
      );
      text.paint(canvas, Offset(left, plot.bottom + 10));
    }
    final curve = accumulationCurvePoints(points);
    final tangents = accumulationTangents(curve);
    final line = Path()..moveTo(x(curve.first.date), y(curve.first.total));
    for (var i = 1; i < curve.length; i++) {
      final previous = curve[i - 1];
      final next = curve[i];
      final startX = x(previous.date);
      final endX = x(next.date);
      final days = chartDay(next.date) - chartDay(previous.date);
      // Shared, limited tangents produce fluid bends without decreases.
      line.cubicTo(
        startX + (endX - startX) / 3,
        y(previous.total + tangents[i - 1] * days / 3),
        startX + (endX - startX) * 2 / 3,
        y(next.total - tangents[i] * days / 3),
        endX,
        y(next.total),
      );
    }
    final end = Offset(x(points.last.date), y(points.last.total));
    final area = Path.from(line)
      ..lineTo(end.dx, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.gold.withValues(alpha: .2),
            colors.gold.withValues(alpha: .015),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.gold
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(end, 4, Paint()..color = colors.gold);
    if (selected == null) {
      final text = label('${points.last.total}', highlight: true);
      text.paint(canvas, Offset(end.dx - text.width, end.dy - text.height - 8));
    } else {
      final point = Offset(
        x(selected!.date),
        y(accumulationCurveValue(curve, tangents, chartDay(selected!.date))),
      );
      canvas.drawCircle(point, 6, Paint()..color = colors.night);
      canvas.drawCircle(point, 4, Paint()..color = colors.gold);
      // A separate lane on each axis keeps the exact values distinct from
      // regular ticks without adding crosshair lines over the chart.
      final exactTotal = label('${selected!.total}', highlight: true);
      exactTotal.paint(
        canvas,
        Offset(
          plot.left - exactTotal.width - 8,
          y(selected!.total) - exactTotal.height / 2,
        ),
      );
      final exactDate = label(dateLabel(selected!.date), highlight: true);
      final dateLeft = (point.dx - exactDate.width / 2)
          .clamp(0.0, math.max(0.0, size.width - exactDate.width))
          .toDouble();
      exactDate.paint(
        canvas,
        Offset(dateLeft, plot.bottom + exactDate.height + 18),
      );
    }
  }

  @override
  bool shouldRepaint(_AccumulationPainter oldDelegate) => true;
}
