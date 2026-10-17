import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_style.dart';
import '../../theme/app_typography.dart';
import '../../utils/celebration_stats.dart';
import '../../utils/accumulation_chart_data.dart';

const double _axisLabelGap = 10;
const double _valueBadgeHorizontalPadding = 8;
const double _valueBadgeVerticalPadding = 4;

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
            Semantics(
              liveRegion: true,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  key: const ValueKey('accumulation-chart-selection-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _valueBadgeHorizontalPadding,
                    vertical: _valueBadgeVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: colors.night,
                    border: Border.all(color: colors.nightBorder),
                    borderRadius: BorderRadius.circular(kSpaceXs),
                  ),
                  child: Row(
                    key: const ValueKey('accumulation-chart-selection'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: colors.gold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          selected == null
                              ? '${widget.dateLabel(widget.points.first.date)} – ${widget.dateLabel(widget.points.last.date)}'
                              : widget.dateLabel(selected.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.body.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected != null) ...[
                        const SizedBox(width: kSpaceSm),
                        Icon(Icons.bolt_rounded, size: 17, color: colors.gold),
                        const SizedBox(width: 3),
                        Text(
                          '${selected.total}',
                          key: const ValueKey(
                            'accumulation-chart-selection-total',
                          ),
                          style: context.typography.body.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
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
  TextPainter label(
    String value, {
    bool highlight = false,
    bool badge = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: style.copyWith(
        color: badge
            ? colors.text
            : highlight
            ? colors.gold
            : colors.muted,
      ),
    ),
    textDirection: direction,
    textScaler: scaler,
  )..layout();
  Rect plotRect(Size size) {
    final text = label('$maximum');
    return Rect.fromLTRB(
      text.width + 24,
      text.height / 2 + 8,
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
    final generatedTicks = accumulationDateTicks(
      points.first.date,
      points.last.date,
      maxTicks,
    );
    final ticks = <DateTime>[
      points.first.date,
      for (final date in generatedTicks)
        if (chartDay(date) != first) date,
    ];
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
        Offset(
          plot.left - text.width - _axisLabelGap,
          y(value) - text.height / 2,
        ),
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
      text.paint(canvas, Offset(left, plot.bottom + _axisLabelGap));
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
    if (selected == null) {
      final text = label('${points.last.total}', highlight: true);
      text.paint(canvas, Offset(end.dx - text.width, end.dy - text.height - 8));
    } else {
      final point = Offset(
        x(selected!.date),
        y(accumulationCurveValue(curve, tangents, chartDay(selected!.date))),
      );
      _paintSelectedPoint(canvas, point);
      // Exact values occupy the regular axis lanes. Their opaque badges
      // cover a nearby tick instead of creating a second row or column.
      final exactTotal = label('${selected!.total}', badge: true);
      final totalOffset = Offset(
        plot.left - exactTotal.width - _axisLabelGap,
        y(selected!.total) - exactTotal.height / 2,
      );
      _paintLabelBadge(canvas, exactTotal, totalOffset);
      exactTotal.paint(canvas, totalOffset);
      final exactDate = label(dateLabel(selected!.date), badge: true);
      final dateLeft = (point.dx - exactDate.width / 2)
          .clamp(0.0, math.max(0.0, size.width - exactDate.width))
          .toDouble();
      final dateOffset = Offset(dateLeft, plot.bottom + _axisLabelGap);
      _paintLabelBadge(canvas, exactDate, dateOffset);
      exactDate.paint(canvas, dateOffset);
    }
  }

  void _paintSelectedPoint(Canvas canvas, Offset point) {
    const haloRadius = 24.0;
    canvas.drawCircle(
      point,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.gold.withValues(alpha: .72),
            colors.gold.withValues(alpha: .28),
            colors.gold.withValues(alpha: 0),
          ],
          stops: const [0, .35, 1],
        ).createShader(Rect.fromCircle(center: point, radius: haloRadius)),
    );
    canvas.drawCircle(point, 6, Paint()..color = colors.gold);
  }

  void _paintLabelBadge(Canvas canvas, TextPainter text, Offset offset) {
    final rect = Rect.fromLTRB(
      offset.dx - _valueBadgeHorizontalPadding,
      offset.dy - _valueBadgeVerticalPadding,
      offset.dx + text.width + _valueBadgeHorizontalPadding,
      offset.dy + text.height + _valueBadgeVerticalPadding,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(kSpaceXs)),
      Paint()..color = colors.night,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(kSpaceXs)),
      Paint()
        ..color = colors.nightBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_AccumulationPainter oldDelegate) => true;
}
