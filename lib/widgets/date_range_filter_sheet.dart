import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/date_format.dart';
import '../utils/responsive.dart';
import 'responsive_content.dart';

/// Opens the date-range filter sheet for Sky's Stars view — narrows the flat
/// list to whatever was logged within a window, either a common preset
/// (last week/month/year) or a custom range picked from Flutter's own
/// [showDateRangePicker], which already renders gold/night themed (see
/// `datePickerTheme` in `app_theme.dart`) without anything extra needed here.
///
/// Returns `(range: ..., preset: ...)`, or null if dismissed without tapping
/// Apply (caller should keep its previous filter in that case) — same
/// apply-or-keep contract as [showAreaFilterSheet]. `range` itself is null
/// when the user applied with no period selected ("All time"/cleared), which
/// is why the whole thing is wrapped in a record rather than just returning
/// a bare nullable [DateTimeRange]: that would make "cleared" and
/// "dismissed" indistinguishable. `preset` is returned alongside `range`
/// purely so the caller can hand it back in as [initialPreset] the next time
/// this reopens, so the right chip is still highlighted — see
/// [DateRangePreset]'s own doc for why the filter button itself doesn't use
/// it.
Future<({DateTimeRange? range, DateRangePreset preset})?>
showDateRangeFilterSheet(
  BuildContext context, {
  required DateTimeRange? initialRange,
  required DateRangePreset initialPreset,
}) {
  return showModalBottomSheet<({DateTimeRange? range, DateRangePreset preset})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DateRangeFilterSheet(
      initialRange: initialRange,
      initialPreset: initialPreset,
    ),
  );
}

/// Which of the sheet's quick chips (if any) produced the current range —
/// [custom] covers both a hand-picked range and, mid-edit, the moment before
/// any preset has been tapped. Public so [SkyExplorerView] can hold onto it
/// between opens and hand it back in as this sheet's own [initialPreset], so
/// the right chip is still highlighted on reopen, without recomputing which
/// preset a stored range happens to match — a comparison that would drift
/// the moment "today" moves on to the next calendar day. Deliberately *not*
/// used to label the filter button itself, which always shows the actual
/// span instead (e.g. "15/06 - 03/07") — seeing "Last week" there would
/// still mean opening the sheet just to find out which days that means.
enum DateRangePreset { allTime, week, month, year, custom }

class _DateRangeFilterSheet extends StatefulWidget {
  const _DateRangeFilterSheet({
    required this.initialRange,
    required this.initialPreset,
  });

  final DateTimeRange? initialRange;
  final DateRangePreset initialPreset;

  @override
  State<_DateRangeFilterSheet> createState() => _DateRangeFilterSheetState();
}

class _DateRangeFilterSheetState extends State<_DateRangeFilterSheet> {
  late DateTimeRange? _range = widget.initialRange;
  late DateRangePreset _preset = widget.initialPreset;

  /// How many whole units of [_preset] (week/month/year) the current
  /// [_range] sits behind "now" — 0 is the most recent period (ending
  /// today), 1 the one before that, and so on. Only meaningful while
  /// [_preset] is week/month/year; ignored (and not shown) otherwise. Purely
  /// local navigation state for this one sheet session — reopening always
  /// starts back at 0, since "today" may have moved on since [_range] was
  /// last set, which would make a stored offset ambiguous anyway.
  int _periodOffset = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// [_today] shifted back by [units] whole [unit]s — the one piece of math
  /// both [_rangeForOffset] and the step arrows are built from.
  DateTime _shiftedToday(DateRangePreset unit, int units) {
    final today = _today;
    return switch (unit) {
      DateRangePreset.week => today.subtract(Duration(days: 7 * units)),
      DateRangePreset.month => DateTime(
        today.year,
        today.month - units,
        today.day,
      ),
      DateRangePreset.year => DateTime(
        today.year - units,
        today.month,
        today.day,
      ),
      DateRangePreset.allTime || DateRangePreset.custom => today,
    };
  }

  /// The [unit]-long window ending [offset] units before today — offset 0
  /// is "the last week/month/year", offset 1 the one before that, tiled
  /// back to back with no gaps (this window's [DateTimeRange.end] is
  /// exactly the previous window's [DateTimeRange.start]) so stepping
  /// through them with the arrows never skips or overlaps a day.
  DateTimeRange _rangeForOffset(DateRangePreset unit, int offset) {
    return DateTimeRange(
      start: _shiftedToday(unit, offset + 1),
      end: _shiftedToday(unit, offset),
    );
  }

  /// Picks (or re-picks) a duration unit — always jumps back to its most
  /// recent period, same as tapping used to apply a fixed "last week"
  /// range; the arrows are what let you move on from there.
  void _selectUnit(DateRangePreset unit) {
    setState(() {
      _preset = unit;
      _periodOffset = 0;
      _range = _rangeForOffset(unit, 0);
    });
  }

  void _clear() {
    setState(() {
      _preset = DateRangePreset.allTime;
      _periodOffset = 0;
      _range = null;
    });
  }

  bool get _hasUnit =>
      _preset == DateRangePreset.week ||
      _preset == DateRangePreset.month ||
      _preset == DateRangePreset.year;

  /// The backward arrow has nothing stopping it (aside from the calendar's
  /// own firstDate, which nobody navigates back to one step at a time in
  /// practice) — only forward is bounded, since going past offset 0 would
  /// mean a window ending in the future.
  bool get _canStepForward => _hasUnit && _periodOffset > 0;

  void _stepBackward() {
    if (!_hasUnit) return;
    setState(() {
      _periodOffset++;
      _range = _rangeForOffset(_preset, _periodOffset);
    });
  }

  void _stepForward() {
    if (!_canStepForward) return;
    setState(() {
      _periodOffset--;
      _range = _rangeForOffset(_preset, _periodOffset);
    });
  }

  Future<void> _pickCustom() async {
    final today = _today;
    final range = _range;
    final initial =
        range != null &&
            !range.start.isAfter(today) &&
            !range.end.isAfter(today)
        ? range
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: initial,
      // The calendar dialog sizes itself off `MediaQuery.sizeOf` directly
      // rather than the constraints handed down through the tree (its
      // `insetPadding` is hardcoded to zero — there's no public knob for
      // this), so capping its width the way [ResponsiveContent] caps
      // everything else means overriding the MediaQuery it reads instead.
      // A no-op below [kWideLayoutBreakpoint], same as ResponsiveContent.
      builder: (context, child) {
        if (child == null || !isWideLayout(context)) {
          return child ?? const SizedBox.shrink();
        }
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            size: Size(
              kResponsiveContentMaxWidth,
              math.min(media.size.height, 720),
            ),
          ),
          child: child,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _preset = DateRangePreset.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return SafeArea(
      // Not [ResponsiveContent]: its `Center` shrink-wraps vertically only
      // when the incoming height is unbounded, but a modal bottom sheet
      // hands its content a *bounded* max height (the screen's own), so
      // `Center` would expand to fill all of it and then center this
      // sheet's genuinely short content inside that — which is exactly
      // the "too tall" sheet this replaced. `heightFactor: 1` forces the
      // shrink-wrap unconditionally; the width cap itself still only ever
      // bites on wide layouts, same as everywhere else, since
      // [kResponsiveContentMaxWidth] is already wider than any phone
      // screen.
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kResponsiveContentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.dateRangeFilterSectionTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    if (_range != null)
                      TextButton(
                        onPressed: _clear,
                        child: Text(strings.clearFilterAction),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // The duration on one side (which chip is lit is also what
                // the arrows step by), a pair of step buttons on the
                // other — greyed out until a duration is actually picked,
                // since there's nothing for them to step by before that.
                Row(
                  children: [
                    Expanded(
                      child: _PresetChip(
                        label: strings.dateRangeUnitWeek,
                        selected: _preset == DateRangePreset.week,
                        onTap: () => _selectUnit(DateRangePreset.week),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PresetChip(
                        label: strings.dateRangeUnitMonth,
                        selected: _preset == DateRangePreset.month,
                        onTap: () => _selectUnit(DateRangePreset.month),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PresetChip(
                        label: strings.dateRangeUnitYear,
                        selected: _preset == DateRangePreset.year,
                        onTap: () => _selectUnit(DateRangePreset.year),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StepButton(
                      icon: Icons.chevron_left,
                      enabled: _hasUnit,
                      tooltip: strings.dateRangeStepBackAction,
                      onTap: _stepBackward,
                    ),
                    const SizedBox(width: 6),
                    _StepButton(
                      icon: Icons.chevron_right,
                      enabled: _canStepForward,
                      tooltip: strings.dateRangeStepForwardAction,
                      onTap: _stepForward,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // The "flight ticket" pair the user pictured — two dates with a
                // line joining them, tap either side to open the full range
                // picker and set both at once.
                _DateRangeTicket(
                  from: _range?.start,
                  to: _range?.end,
                  onTap: _pickCustom,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop((range: _range, preset: _preset)),
                    child: Text(strings.applyFilterAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single-line duration chip ("Week"/"Month"/"Year") — same
/// selected/unselected treatment as `_FilterChip` in
/// `area_filter_sheet.dart`, just without its leading icon and trailing
/// check, since three short labels in a row already read as a set of
/// mutually exclusive choices on their own.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: selectableDecoration(colors, selected: selected),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.text : colors.muted,
          ),
        ),
      ),
    );
  }
}

/// One of the two arrows beside the duration chips — steps [_range] back or
/// forward by a whole [DateRangePreset] unit (see [_DateRangeFilterSheetState
/// ._stepBackward]/`._stepForward`). Dimmed and inert rather than hidden
/// when [enabled] is false, so the row's width never jumps around as a
/// duration is picked or the forward edge is reached.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            width: 40,
            height: 46,
            alignment: Alignment.center,
            decoration: panelDecoration(colors, radius: kRadiusField),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? colors.text
                  : colors.muted.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Da"/"A" boxes plus the dot-line-dot that joins them — a booking-app
/// date span at a glance rather than two unrelated fields. Both boxes open
/// the same picker, since the range is always set as one pair.
class _DateRangeTicket extends StatelessWidget {
  const _DateRangeTicket({
    required this.from,
    required this.to,
    required this.onTap,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final active = from != null && to != null;
    return Row(
      children: [
        Expanded(
          child: _TicketBox(
            label: strings.dateRangeFromLabel,
            date: from,
            onTap: onTap,
          ),
        ),
        _TicketConnector(active: active),
        Expanded(
          child: _TicketBox(
            label: strings.dateRangeToLabel,
            date: to,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _TicketBox extends StatelessWidget {
  const _TicketBox({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final filled = date != null;
    final state = fieldStateOf(hasValue: filled, focused: false);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: fieldDecoration(colors, state),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filled ? formatDisplayDate(date!, strings) : '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
                color: filled ? colors.text : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dot-line-dot between the two ticket boxes — full gold once a range is
/// set, a lighter tint of the same gold while empty. Always gold rather than
/// switching to [AppColors.nightBorder]'s navy when inactive: this is the
/// one place in the sheet that's decorative rather than a real field, so it
/// reads as "the thread joining the two dates" even before either is set.
class _TicketConnector extends StatelessWidget {
  const _TicketConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = colors.gold.withValues(alpha: active ? 1 : 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Container(width: 10, height: 1.5, color: color),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
