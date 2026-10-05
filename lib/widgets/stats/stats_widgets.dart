import 'package:flutter/material.dart';

import '../../l10n/strings_scope.dart';
import '../../models/life_area.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_style.dart';
import '../../theme/app_typography.dart';
import '../../utils/habit_stats.dart';

import '../area_tag.dart';
import '../app_choice_chip.dart';
import '../star_heatmap.dart';

/// Small muted heading above a block of statistics — the app's compact
/// section label role.
class StatsSectionLabel extends StatelessWidget {
  const StatsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.typography.compactSectionLabel);
  }
}

/// One figure with its caption — the single "value over label" tile used by
/// the Statistics page, the pulsar dashboard and the detail screens.
///
/// A flat night panel; the figure is plain text, and only turns gold when
/// it is the one that deserves to burn ([highlight]) — gold means lit, so it
/// can't be the default for every number. [compact] is the denser
/// three-across variant; [mono] switches the figure to the mono face; a
/// non-null [onTap] makes the tile tappable and adds a quiet chevron.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.compact = false,
    this.mono = false,
    this.highlight = false,
    this.onTap,
  });

  final String value;
  final String label;
  final bool compact;
  final bool mono;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(kRadiusCard);
    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: kSpaceMd - 2,
        horizontal: compact ? kSpaceXs : kSpaceMd - 4,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                textAlign: TextAlign.center,
                style: typography.sectionHeading.copyWith(
                  fontFamily: mono ? kFontMono : null,
                  fontSize: mono ? 24 : 20,
                  color: highlight ? colors.gold : colors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typography.microLabel,
              ),
            ],
          ),
          if (onTap != null)
            Positioned(
              top: -4,
              right: -4,
              child: Icon(Icons.chevron_right, size: 18, color: colors.muted),
            ),
        ],
      ),
    );
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              child: InkWell(onTap: onTap, borderRadius: radius, child: content),
            ),
    );
  }
}

/// The 7 / 30 / 90 day selector, labelled with its unit ("30 days"). Built
/// from the app's canonical [AppChoiceChip]: flat, gold ring when chosen.
class RangeChips extends StatelessWidget {
  const RangeChips({
    super.key,
    required this.range,
    required this.onChanged,
    this.alignment = WrapAlignment.start,
  });

  final HabitStatsRange range;
  final ValueChanged<HabitStatsRange> onChanged;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Wrap(
      alignment: alignment,
      spacing: kSpaceSm,
      runSpacing: kSpaceSm,
      children: [
        for (final value in HabitStatsRange.values)
          AppChoiceChip(
            label: strings.habitStatsDays(value.days),
            selected: value == range,
            onPressed: () => onChanged(value),
          ),
      ],
    );
  }
}

/// Panel around a [StarHeatmap] that owns the month paging, so changing
/// month rebuilds only the calendar and never the rest of the page. Paging
/// forward stops at the present month.
class HeatmapPanel extends StatefulWidget {
  const HeatmapPanel({
    super.key,
    required this.countsByDay,
    this.intensityByDay,
    this.progressByDay,
    this.onDayTap,
    this.availableFrom,
    this.availableThrough,
    this.initialMonth,
    this.onMonthChanged,
  });

  /// Month to open on (its day is ignored); defaults to the current one.
  final DateTime? initialMonth;
  final ValueChanged<DateTime>? onMonthChanged;
  final Map<DateTime, int> countsByDay;
  final Map<DateTime, int>? intensityByDay;
  final Map<DateTime, double>? progressByDay;
  final ValueChanged<DateTime>? onDayTap;
  final DateTime? availableFrom;
  final DateTime? availableThrough;

  @override
  State<HeatmapPanel> createState() => _HeatmapPanelState();
}

class _HeatmapPanelState extends State<HeatmapPanel> {
  late DateTime _month = _initial();

  DateTime _initial() {
    final month = widget.initialMonth;
    if (month == null) return _currentMonth();
    final first = DateTime(month.year, month.month);
    final current = _currentMonth();
    return first.isAfter(current) ? current : first;
  }

  static DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void _change(int delta) {
    final current = _currentMonth();
    final next = DateTime(_month.year, _month.month + delta);
    setState(() => _month = next.isAfter(current) ? current : next);
    widget.onMonthChanged?.call(_month);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = !_month.isBefore(_currentMonth());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: panelDecoration(context.colors),
      child: StarHeatmap(
        month: _month,
        countsByDay: widget.countsByDay,
        intensityByDay: widget.intensityByDay ?? const {},
        progressByDay: widget.progressByDay,
        availableFrom: widget.availableFrom,
        availableThrough: widget.availableThrough,
        onDayTap: widget.onDayTap,
        onPreviousMonth: () => _change(-1),
        onNextMonth: isCurrent ? null : () => _change(1),
      ),
    );
  }
}

/// Centered muted message for a stats block with nothing to show yet.
class StatsEmptyState extends StatelessWidget {
  const StatsEmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.typography.supporting,
    );
  }
}

/// Bar chart of per-day habit progress. Beyond [maxBars] days (the 90-day
/// range) consecutive days are averaged into one bar, so every bar stays
/// wide enough to read; the first and last dates are labelled underneath
/// and tapping a bar shows its value.
class TrendBars extends StatefulWidget {
  const TrendBars({super.key, required this.points, this.maxBars = 30});

  final List<HabitTrendPoint> points;
  final int maxBars;

  @override
  State<TrendBars> createState() => _TrendBarsState();
}

class _TrendBarsState extends State<TrendBars> {
  int? _selected;

  List<_Bucket> _buckets() {
    final points = widget.points;
    if (points.isEmpty) return const [];
    final size = (points.length / widget.maxBars).ceil().clamp(1, 1000);
    final buckets = <_Bucket>[];
    for (var i = 0; i < points.length; i += size) {
      final slice = points.sublist(i, (i + size).clamp(0, points.length));
      final avg =
          slice.fold<double>(0, (sum, p) => sum + p.progress) / slice.length;
      buckets.add(_Bucket(slice.first.date, slice.last.date, avg));
    }
    return buckets;
  }

  String _day(BuildContext context, DateTime d) {
    final month = context.strings.monthAbbreviations[d.month - 1];
    return '${d.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final buckets = _buckets();
    if (buckets.isEmpty) return const SizedBox.shrink();
    final selected = _selected != null && _selected! < buckets.length
        ? buckets[_selected!]
        : null;
    final first = buckets.first.start;
    final last = buckets.last.end;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = _selected == i ? null : i),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 6 + 52 * buckets[i].progress,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              colors.muted.withValues(alpha: 0.12),
                              colors.gold,
                              buckets[i].progress,
                            ),
                            border: _selected == i
                                ? Border.all(color: colors.text, width: 1)
                                : null,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selected == null
                  ? _day(context, first)
                  : '${_day(context, selected.start)}'
                        '${selected.start == selected.end ? '' : ' – ${_day(context, selected.end)}'}'
                        ' · ${(selected.progress * 100).round()}%',
              style: context.typography.microLabel.copyWith(
                color: selected == null ? colors.muted : colors.gold,
              ),
            ),
            if (selected == null)
              Text(
                _day(context, last),
                style: context.typography.microLabel,
              ),
          ],
        ),
      ],
    );
  }
}

class _Bucket {
  const _Bucket(this.start, this.end, this.progress);
  final DateTime start;
  final DateTime end;
  final double progress;
}

/// Horizontal bars of how many stars each life area holds, largest first,
/// scaled against the biggest area.
class AreaDistribution extends StatelessWidget {
  const AreaDistribution({super.key, required this.counts});

  final List<MapEntry<LifeArea, int>> counts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    if (counts.isEmpty) return const SizedBox.shrink();
    final maxCount = counts.first.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceXs),
      decoration: panelDecoration(colors),
      child: Column(
        children: [
          for (final entry in counts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AreaTag(
                          area: entry.key,
                          iconSize: 16,
                          fontSize: 14,
                          textColor: colors.text,
                        ),
                      ),
                      Text(
                        strings.starsCount(entry.value),
                        style: context.typography.supporting,
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpaceXs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: maxCount == 0 ? 0 : entry.value / maxCount,
                      minHeight: 6,
                      color: colors.gold,
                      backgroundColor: colors.muted.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
