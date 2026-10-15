import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_style.dart';
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          kSpaceMd,
          kSpaceMd,
          kSpaceMd,
          kSpaceSm,
        ),
        decoration: panelDecoration(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.axisLabel, style: context.typography.supporting),
            const SizedBox(height: kSpaceXs),
            Semantics(
              liveRegion: true,
              child: Text(
                selected == null
                    ? '${widget.dateLabel(widget.points.first.date)} – ${widget.dateLabel(widget.points.last.date)}'
                    : '${widget.dateLabel(selected.date)} · ${selected.total}',
                key: const ValueKey('accumulation-chart-selection'),
                textAlign: TextAlign.center,
                style: context.typography.body.copyWith(
                  color: selected == null ? colors.muted : colors.gold,
                  fontWeight: selected == null
                      ? FontWeight.w400
                      : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: kSpaceXs),
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
                  final fraction = ((position.dx - plot.left) / plot.width)
                      .clamp(0.0, 1.0);
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
          ],
        ),
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
      text.width + 24,
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
    final plotShape = RRect.fromRectAndRadius(
      plot,
      const Radius.circular(kRadiusField),
    );
    canvas.drawRRect(plotShape, Paint()..color = colors.night);
    canvas.save();
    canvas.clipRRect(plotShape);
    for (var value = 0; value <= maximum; value += step) {
      final vertical = y(value);
      canvas.drawLine(
        Offset(plot.left, vertical),
        Offset(plot.right, vertical),
        grid,
      );
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
    for (final date in ticks) {
      final horizontal = x(date);
      canvas.drawLine(
        Offset(horizontal, plot.top),
        Offset(horizontal, plot.bottom),
        grid,
      );
    }
    canvas.restore();
    for (var value = 0; value <= maximum; value += step) {
      final text = label('$value');
      text.paint(
        canvas,
        Offset(plot.left - text.width - 8, y(value) - text.height / 2),
      );
    }
    var previousLabelEnd = double.negativeInfinity;
    for (final date in ticks) {
      final horizontal = x(date);
      final text = label(tickLabel(date));
      final left = (horizontal - text.width / 2)
          .clamp(0.0, math.max(0.0, size.width - text.width))
          .toDouble();
      if (left < previousLabelEnd + 8) continue;
      previousLabelEnd = left + text.width;
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
            colors.gold.withValues(alpha: .34),
            colors.gold.withValues(alpha: .09),
            colors.gold.withValues(alpha: .018),
          ],
          stops: const [0, .58, 1],
        ).createShader(plot),
    );
    canvas.save();
    canvas.clipRRect(plotShape);
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.gold.withValues(alpha: .28)
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.gold.withValues(alpha: .48)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.gold
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawRRect(
      plotShape,
      Paint()
        ..color = colors.nightBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _paintPoint(canvas, end);
    if (selected == null) {
      final text = label('${points.last.total}', highlight: true);
      text.paint(canvas, Offset(end.dx - text.width, end.dy - text.height - 8));
    } else {
      final point = Offset(
        x(selected!.date),
        y(accumulationCurveValue(curve, tangents, chartDay(selected!.date))),
      );
      _paintPoint(canvas, point, selected: true);
      // Exact values occupy the regular axis lanes. Their opaque badges
      // cover a nearby tick instead of creating a second row or column.
      final exactTotal = label('${selected!.total}', highlight: true);
      final totalOffset = Offset(
        plot.left - exactTotal.width - 8,
        y(selected!.total) - exactTotal.height / 2,
      );
      _paintLabelBadge(canvas, exactTotal, totalOffset);
      exactTotal.paint(canvas, totalOffset);
      final exactDate = label(dateLabel(selected!.date), highlight: true);
      final dateLeft = (point.dx - exactDate.width / 2)
          .clamp(0.0, math.max(0.0, size.width - exactDate.width))
          .toDouble();
      final dateOffset = Offset(dateLeft, plot.bottom + 10);
      _paintLabelBadge(canvas, exactDate, dateOffset);
      exactDate.paint(canvas, dateOffset);
    }
  }

  void _paintPoint(Canvas canvas, Offset point, {bool selected = false}) {
    final haloRadius = selected ? 16.0 : 13.0;
    canvas.drawCircle(
      point,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.gold.withValues(alpha: .58),
            colors.gold.withValues(alpha: .2),
            colors.gold.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: point, radius: haloRadius)),
    );
    canvas.drawCircle(point, selected ? 6 : 5, Paint()..color = colors.night);
    canvas.drawCircle(
      point,
      selected ? 5 : 4,
      Paint()
        ..color = colors.text
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(point, selected ? 2.5 : 2, Paint()..color = colors.gold);
  }

  void _paintLabelBadge(Canvas canvas, TextPainter text, Offset offset) {
    final rect = (offset & text.size).inflate(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(kSpaceXs)),
      Paint()..color = colors.night,
    );
  }

  @override
  bool shouldRepaint(_AccumulationPainter oldDelegate) => true;
}
