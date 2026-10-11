import 'dart:math' as math;

import 'celebration_stats.dart';

int chartDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
DateTime chartDate(int day) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

/// Human-readable integer ticks in the 1, 2, 5 sequence.
int accumulationTickStep(int total) {
  final target = math.max(1, total / 4);
  final magnitude = math.pow(10, (math.log(target) / math.ln10).floor());
  for (final factor in [1, 2, 5, 10]) {
    final step = (factor * magnitude).round();
    if (step >= target) return math.max(1, step);
  }
  return 1;
}

/// Actual recorded total on a day, including gaps with no new actions.
CelebrationPoint accumulationAtDay(List<CelebrationPoint> points, int day) {
  final selectedDay = day.clamp(
    chartDay(points.first.date),
    chartDay(points.last.date),
  );
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (chartDay(points[mid].date) <= selectedDay) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return CelebrationPoint(
    chartDate(selectedDay),
    points[math.max(0, low - 1)].total,
  );
}

/// Original cumulative observations for a smooth monotone overview.
List<CelebrationPoint> accumulationCurvePoints(List<CelebrationPoint> points) {
  return points;
}

/// Shared tangents avoid a stop/start bend at every observation. Limiting
/// slopes preserves monotonicity, including transitions into flat segments.
List<double> accumulationTangents(List<CelebrationPoint> points) {
  if (points.length < 2) return List.filled(points.length, 0);
  final slopes = <double>[];
  for (var i = 1; i < points.length; i++) {
    final days = chartDay(points[i].date) - chartDay(points[i - 1].date);
    slopes.add(days == 0 ? 0 : (points[i].total - points[i - 1].total) / days);
  }
  final tangents = <double>[slopes.first];
  for (var i = 1; i < points.length - 1; i++) {
    final before = slopes[i - 1];
    final after = slopes[i];
    tangents.add(
      before <= 0 || after <= 0 ? 0 : 2 * before * after / (before + after),
    );
  }
  tangents.add(slopes.last);
  for (var i = 0; i < slopes.length; i++) {
    if (slopes[i] == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    final a = tangents[i] / slopes[i];
    final b = tangents[i + 1] / slopes[i];
    final length = math.sqrt(a * a + b * b);
    if (length > 3) {
      tangents[i] *= 3 / length;
      tangents[i + 1] *= 3 / length;
    }
  }
  return tangents;
}

double accumulationCurveValue(
  List<CelebrationPoint> points,
  List<double> tangents,
  int day,
) {
  for (var i = 1; i < points.length; i++) {
    if (day > chartDay(points[i].date)) continue;
    final start = points[i - 1];
    final end = points[i];
    final width = chartDay(end.date) - chartDay(start.date);
    if (width == 0) return end.total.toDouble();
    final t = ((day - chartDay(start.date)) / width).clamp(0.0, 1.0);
    final t2 = t * t;
    final t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * start.total +
        (t3 - 2 * t2 + t) * width * tangents[i - 1] +
        (-2 * t3 + 3 * t2) * end.total +
        (t3 - t2) * width * tangents[i];
  }
  return points.last.total.toDouble();
}

/// Calendar-aligned day, Monday-week, month-start and year-start ticks.
List<DateTime> accumulationDateTicks(
  DateTime start,
  DateTime end,
  int maxTicks,
) {
  final first = chartDay(start);
  final last = chartDay(end);
  final target = math.max(1, (last - first) / math.max(1, maxTicks - 1));
  final ticks = <DateTime>[];
  if (last - first <= 7) {
    // The first point is the zero baseline immediately before the 7 days.
    for (var day = first + 1; day <= last; day++) {
      ticks.add(chartDate(day));
    }
  } else if (target <= 14 || last - first <= 31) {
    final step = last - first <= 31
        ? 5
        : [1, 2, 5, 7, 14].firstWhere((value) => value >= target);
    final origin = step >= 7 ? 4 : 0;
    for (
      var day = ((first - origin) / step).ceil() * step + origin;
      day <= last;
      day += step
    ) {
      ticks.add(chartDate(day));
    }
  } else if (target <= 180) {
    final months = [
      1,
      2,
      3,
      6,
    ].firstWhere((value) => value * 30 >= target, orElse: () => 6);
    var index = ((start.year * 12 + start.month - 1) / months).ceil() * months;
    if (chartDay(DateTime(index ~/ 12, index % 12 + 1)) < first) {
      index += months;
    }
    for (; ; index += months) {
      final date = DateTime(index ~/ 12, index % 12 + 1);
      if (chartDay(date) > last) break;
      ticks.add(date);
    }
  } else {
    final years = [1, 2, 5, 10, 20, 50, 100].firstWhere(
      (value) => value * 365 >= target,
      orElse: () => (target / 365).ceil(),
    );
    var year = (start.year / years).ceil() * years;
    if (chartDay(DateTime(year)) < first) year += years;
    for (; chartDay(DateTime(year)) <= last; year += years) {
      ticks.add(DateTime(year));
    }
  }
  return ticks.length < 2 ? [start, end] : ticks;
}
