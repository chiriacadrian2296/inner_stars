import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// TEMPORARY measuring aid (2026-10-15, Galaxy optimization pass): every 5
/// seconds logs how many frames were drawn and their average / 90th
/// percentile build (UI thread) and raster (GPU thread) times. Remove once
/// the measurements are done.
void startFrameTimingProbe() {
  final builds = <double>[];
  final rasters = <double>[];
  var windowStart = DateTime.now();
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      builds.add(timing.buildDuration.inMicroseconds / 1000);
      rasters.add(timing.rasterDuration.inMicroseconds / 1000);
    }
    final now = DateTime.now();
    if (now.difference(windowStart).inSeconds < 5 || rasters.isEmpty) return;
    double average(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;
    double p90(List<double> values) {
      final sorted = [...values]..sort();
      return sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    }

    debugPrint(
      'FRAME_PROBE frames=${rasters.length} '
      'build_avg=${average(builds).toStringAsFixed(2)} '
      'build_p90=${p90(builds).toStringAsFixed(2)} '
      'raster_avg=${average(rasters).toStringAsFixed(2)} '
      'raster_p90=${p90(rasters).toStringAsFixed(2)}',
    );
    builds.clear();
    rasters.clear();
    windowStart = now;
  });
}
