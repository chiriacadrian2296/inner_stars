import 'dart:async';
import 'dart:math' show pi, sin;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/app_modals.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import '../utils/habit_stats.dart';
import '../utils/habit_stats_snapshot.dart';
import '../utils/star_stats.dart';
import '../widgets/app_field.dart';
import '../widgets/area_filter_sheet.dart';
import '../widgets/date_range_filter_sheet.dart';
import '../widgets/filter_button.dart';
import '../widgets/lit_star_card.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/stats/stats_widgets.dart';
import 'pulsar_reader_screen.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';
import 'stat_detail_screen.dart';

/// In-memory working context of the Statistics page. Owned by Cosmo (like
/// [SkyExplorerSession] for the Sky) so leaving the page and coming back
/// restores the range, filters, calendar month and scroll position instead
/// of starting over.
class StatsSession {
  HabitStatsRange habitRange = HabitStatsRange.days30;
  StarFilter filter = StarFilter.all();
  DateRangePreset datePreset = DateRangePreset.allTime;
  DateTime? displayedMonth;
  double scrollOffset = 0;
}

/// The Statistics page: pulsar overview (with the 7/30/90 range), today's
/// star, the activity calendar, total stars and the current/longest streak,
/// top (habits, today) to bottom (all-time).
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    this.session,
  });

  /// Pass the same session across visits to remember where the user was.
  final StatsSession? session;
  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsSession _session = widget.session ?? StatsSession();
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: _session.scrollOffset,
  )..addListener(_rememberScroll);

  void _rememberScroll() {
    if (_scrollController.hasClients) {
      _session.scrollOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_rememberScroll)
      ..dispose();
    super.dispose();
  }

  HabitStatsRange get _habitRange => _session.habitRange;
  set _habitRange(HabitStatsRange value) => _session.habitRange = value;

  /// Narrows the Stars section (calendar, total, area split, streaks) to
  /// some areas and/or a period. Today's star and the pulsars above are
  /// never filtered: they describe right now, not a slice of history.
  StarFilter get _filter => _session.filter;
  set _filter(StarFilter value) => _session.filter = value;

  DateRangePreset get _datePreset => _session.datePreset;
  set _datePreset(DateRangePreset value) => _session.datePreset = value;

  Future<void> _openAreaFilter() async {
    final result = await showAreaFilterSheet(
      context,
      selectedAreas: _filter.areas,
    );
    if (result == null) return;
    setState(() => _filter = _filter.copyWith(areas: result));
  }

  Future<void> _openDateRangeFilter() async {
    final result = await showDateRangeFilterSheet(
      context,
      initialRange: _filter.hasDateRange
          ? DateTimeRange(start: _filter.from!, end: _filter.to!)
          : null,
      initialPreset: _datePreset,
    );
    if (result == null) return;
    setState(() {
      _datePreset = result.preset;
      _filter = result.range == null
          ? _filter.copyWith(clearDates: true)
          : _filter.copyWith(from: result.range!.start, to: result.range!.end);
    });
  }

  String _dateRangeButtonLabel(AppStrings strings) {
    if (!_filter.hasDateRange) return strings.dateRangeFilterSectionTitle;
    final year = DateTime.now().year;
    final needsYear = _filter.from!.year != year || _filter.to!.year != year;
    final format = needsYear ? formatShortDateWithYear : formatShortDate;
    return '${format(_filter.from!)} - ${format(_filter.to!)}';
  }

  /// A pulsar's own dashboard — its streak, the history calendar and the
  /// "mark today" action — the page a pulsar card used to open before
  /// pulsars got a page in the star reader.
  Future<void> _openPulsarDashboard(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PulsarReaderScreen(
          habit: habit,
          project: _projectsById()[habit.projectId],
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Checks (or unchecks) today for a pulsar straight from the list. A daily
  /// pulsar with a target above 1 can't be a yes/no: there a tap logs one
  /// more instance, and the pulsar's own page does the undoing.
  Future<void> _toggleHabitToday(HabitStatsEntry entry) async {
    final habit = entry.habit;
    final completions = widget.habitCompletionRepository;
    final today = dateOnly(DateTime.now());
    if (_isStepper(habit)) {
      await completions.logInstance(habit.id);
    } else if (_isDoneToday(entry, today)) {
      await completions.unmarkDone(habit.id, today);
    } else {
      await completions.markDone(habit.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openPulsarArchive() async {
    final dead = widget.habitRepository
        .getAll()
        .where((habit) => habit.dead)
        .toList();
    final deadSnapshot = HabitStatsSnapshot.build(
      habits: dead,
      allCompletions: widget.habitCompletionRepository.getAll(),
      range: _habitRange,
    );
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.strings.habitStatsArchiveTitle,
                style: context.typography.sectionHeading,
              ),
              const SizedBox(height: 20),
              if (dead.isEmpty)
                StatsEmptyState(context.strings.habitStatsArchiveEmpty)
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: deadSnapshot.entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final entry = deadSnapshot.entries[index];
                      return _PulsarTile(
                        entry: entry,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openPulsarDashboard(entry.habit);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Map<int, Project> _projectsById() {
    return {
      for (final project in widget.projectRepository.getAll())
        project.id: project,
    };
  }

  /// One form for every kind of star; which repository the result belongs
  /// to is decided by [StarFormResult.kind], not by which entry point was
  /// used to open it.
  Future<void> _openStarForm({
    DateTime? initialDate,
    StarKind initialKind = StarKind.lit,
  }) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          initialDate: initialDate,
          initialKind: initialKind,
        ),
      ),
    );
    if (result is! StarFormResult) return;

    if (result.kind == StarKind.pulsar) {
      await widget.habitRepository.add(
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? 3,
        frequency: result.habitFrequency ?? HabitFrequency.daily,
        targetPerPeriod: result.habitTargetPerPeriod ?? 1,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
      );
    } else {
      await widget.starRepository.add(
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
      );
    }
    setState(() {});
  }

  List<Star> _achievedStarsOnDay(DateTime day) {
    final projects = _projectsById();
    return widget.starRepository.getAll().where((s) {
      if (!s.isLit || !_filter.matches(s, projects)) return false;
      final date = s.achievedDate!;
      return date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList();
  }

  Future<void> _openStarReader(
    List<Star> stars,
    int index,
    DateTime day,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialStars: stars,
          startIndex: index,
          allowEdit: true,
          projectsById: _projectsById(),
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshStars: () => _achievedStarsOnDay(day),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openDayDetail(DateTime day) async {
    final projectsById = _projectsById();
    final dayStars = _achievedStarsOnDay(day);
    final sheetMaxHeight = MediaQuery.sizeOf(context).height * 0.85;

    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: dayStars.isEmpty
          ? BoxConstraints(maxHeight: sheetMaxHeight)
          : BoxConstraints.tightFor(height: sheetMaxHeight),
      builder: (sheetContext) {
        return _DayDetailSheet(
          day: day,
          stars: dayStars,
          projectsById: projectsById,
          onStarTap: (stars, index) {
            Navigator.of(sheetContext).pop();
            _openStarReader(stars, index, day);
          },
          onAddForDay: () {
            Navigator.of(sheetContext).pop();
            _openStarForm(initialDate: day);
          },
        );
      },
    );
  }

  void _openTotalStarsDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TotalStarsDetailScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          filter: _filter,
        ),
      ),
    );
  }

  void _openCurrentStreakDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CurrentStreakDetailScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          filter: _filter,
        ),
      ),
    );
  }

  void _openLongestStreakDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LongestStreakDetailScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          filter: _filter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final projects = _projectsById();
    final litStars = widget.starRepository
        .getAll()
        .where((s) => s.isLit)
        .toList();
    final achievedStars = litStars
        .where((s) => _filter.matches(s, projects))
        .toList();
    final dayCounts = starCountsByDay(achievedStars);
    final dayIntensities = starIntensityByDay(achievedStars);
    final today = dateOnly(DateTime.now());
    final litToday = (starCountsByDay(litStars)[today] ?? 0) > 0;
    final areaCounts = starCountsByArea(achievedStars, projects);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            kPageInsetCompact,
            kSpaceMd,
            kPageInsetCompact,
            kSpaceXxl,
          ),
          // The scrollable itself spans the full window width (so its
          // auto-attached Scrollbar sits at the true page edge on wide
          // viewports); only its content is capped/centered.
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      strings.statsTitle,
                      style: context.typography.utilityPageTitle,
                    ),
                  ),
                  ..._pulsarSection(context),
                  const SizedBox(height: kSpaceXl),
                  StaggeredEntrance(
                    index: 1,
                    child: Text(
                      strings.starsStatsSectionTitle,
                      style: context.typography.sectionHeading,
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 1,
                    child: StatsSectionLabel(strings.todayStarSectionLabel),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 1,
                    child: _TodayStarHero(
                      litToday: litToday,
                      onTap: litToday
                          ? () => _openDayDetail(today)
                          : () => _openStarForm(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: FilterButton(
                            icon: Icons.tune,
                            active: _filter.isAreaNarrowed,
                            horizontal: true,
                            label: _filter.isAreaNarrowed
                                ? strings.activeAreasCount(_filter.areas.length)
                                : strings.areaFilterDefaultLabel,
                            tooltip: strings.filterAreasAction,
                            onTap: _openAreaFilter,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilterButton(
                            icon: Icons.calendar_month,
                            active: _filter.hasDateRange,
                            horizontal: true,
                            label: _dateRangeButtonLabel(strings),
                            tooltip: strings.filterDateRangeAction,
                            onTap: _openDateRangeFilter,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 2,
                    child: StatsSectionLabel(strings.activityLabel),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 2,
                    child: HeatmapPanel(
                      countsByDay: dayCounts,
                      intensityByDay: dayIntensities,
                      onDayTap: _openDayDetail,
                      initialMonth: _session.displayedMonth,
                      onMonthChanged: (month) =>
                          _session.displayedMonth = month,
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 3,
                    child: StatsSectionLabel(strings.totalStarsLabel),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 3,
                    child: _TotalStarsBanner(
                      value: achievedStars.length,
                      onTap: _openTotalStarsDetail,
                    ),
                  ),
                  if (areaCounts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 3,
                      child: StatsSectionLabel(strings.starsByAreaLabel),
                    ),
                    const SizedBox(height: 10),
                    StaggeredEntrance(
                      index: 3,
                      child: AreaDistribution(counts: areaCounts),
                    ),
                  ],
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 4,
                    child: StatsSectionLabel(strings.streaksSectionLabel),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StaggeredEntrance(
                          index: 4,
                          axis: Axis.horizontal,
                          child: MetricTile(
                            mono: true,
                            highlight: true,
                            label: strings.currentStreakLabel,
                            value: '${currentStreak(dayCounts)}',
                            onTap: _openCurrentStreakDetail,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StaggeredEntrance(
                          index: 5,
                          axis: Axis.horizontal,
                          child: MetricTile(
                            mono: true,
                            label: strings.longestStreakLabel,
                            value: '${longestStreak(dayCounts)}',
                            onTap: _openLongestStreakDetail,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Motivational overview of every living pulsar.
  List<Widget> _pulsarSection(BuildContext context) {
    final strings = context.strings;
    final snapshot = HabitStatsSnapshot.build(
      habits: widget.habitRepository.getAll().where((h) => h.isActive).toList(),
      allCompletions: widget.habitCompletionRepository.getAll(),
      range: _habitRange,
    );
    final consistency = (snapshot.overallRate * 100).round();
    return [
      const SizedBox(height: 24),
      StaggeredEntrance(
        index: 1,
        child: Row(
          children: [
            Expanded(
              child: Text(
                strings.habitStatsSectionTitle,
                style: context.typography.sectionHeading,
              ),
            ),
            TextButton(
              onPressed: _openPulsarArchive,
              child: AppButtonLabel(strings.habitStatsArchiveAction),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              compact: true,
              value: '${snapshot.entries.length}',
              label: strings.habitStatsActiveLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              compact: true,
              value: '${snapshot.onTrackCount}',
              label: strings.habitStatsOnTrackLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              compact: true,
              highlight: true,
              value: '$consistency%',
              label: strings.habitStatsConsistencyLabel,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      RangeChips(
        range: _habitRange,
        onChanged: (range) => setState(() => _habitRange = range),
      ),
      if (snapshot.entries.isEmpty) ...[
        const SizedBox(height: 14),
        StatsEmptyState(strings.habitStatsNotEnoughData),
      ] else
        const SizedBox(height: 10),
      for (final entry in snapshot.entries) ...[
        StaggeredEntrance(
          index: 2,
          child: _PulsarTile(
            entry: entry,
            onTap: () => _openPulsarDashboard(entry.habit),
            onToggleToday: () => _toggleHabitToday(entry),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// A daily pulsar that wants several instances a day ("3 times a day").
bool _isStepper(Habit habit) =>
    habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1;

/// Whether today is already checked: its target reached for a stepper,
/// otherwise simply any completion today.
bool _isDoneToday(HabitStatsEntry entry, DateTime today) {
  final count = entry.countsByDay[today] ?? 0;
  return _isStepper(entry.habit)
      ? count >= entry.habit.targetPerPeriod
      : count > 0;
}

/// One pulsar in the stats list: its icon, title and key figures.
class _PulsarTile extends StatelessWidget {
  const _PulsarTile({
    required this.entry,
    required this.onTap,
    this.onToggleToday,
  });

  final HabitStatsEntry entry;
  final VoidCallback onTap;

  /// Checks or unchecks today without opening the pulsar. Null for pulsars
  /// that can no longer be checked (the archive's dead ones).
  final VoidCallback? onToggleToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final habit = entry.habit;
    final summary = entry.summary;
    final weekly = habit.frequency == HabitFrequency.weekly;
    final doneToday = _isDoneToday(entry, dateOnly(DateTime.now()));
    final best = weekly
        ? strings.habitStatsWeeks(summary.longestStreak)
        : strings.habitStatsDays(summary.longestStreak);
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceMd,
              vertical: kSpaceMd - 2,
            ),
            child: Row(
              children: [
                // Lit (on track) pulsars burn gold; one that needs attention
                // stays dark and muted — the same lit/dark reading the Sky uses.
                Icon(
                  StarKind.pulsar.icon,
                  color: entry.isLit ? colors.gold : colors.muted,
                  size: 22,
                ),
                const SizedBox(width: kSpaceSm + 2),
                Expanded(
                  child: Text(
                    habit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: entry.isLit ? colors.text : colors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: kSpaceSm + 2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(summary.completionRate * 100).round()}%',
                      style: context.typography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: entry.isLit ? colors.gold : colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.currentStreak} / $best',
                      style: context.typography.supporting.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (onToggleToday != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: doneToday
                        ? strings.habitUncheckAction
                        : strings.habitCheckAction,
                    child: IconButton(
                      onPressed: onToggleToday,
                      icon: Icon(
                        _isStepper(habit)
                            ? Icons.add_circle_outline
                            : (doneToday
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked),
                        color: doneToday ? colors.gold : colors.muted,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: colors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// This page's headline element: whether today's star is lit.
///
/// Lit: a big gold star that spins slowly and forever, with a glow that
/// breathes in and out, next to a two-line congratulatory message.
///
/// Unlit: the same star, cold and static, with a status caption below it,
/// and below that a normal pill-shaped gold button. Tapping anywhere opens
/// today's stars if there are any, or the add-star flow if not.
class _TodayStarHero extends StatefulWidget {
  const _TodayStarHero({required this.litToday, required this.onTap});

  final bool litToday;
  final VoidCallback onTap;

  @override
  State<_TodayStarHero> createState() => _TodayStarHeroState();
}

class _TodayStarHeroState extends State<_TodayStarHero>
    with TickerProviderStateMixin {
  late final _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final _spinController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  late final _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Timer? _shakeTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotion();
  }

  @override
  void didUpdateWidget(_TodayStarHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.litToday != oldWidget.litToday) _applyMotion();
  }

  /// Starts or stops the ambient animations for the current state. With the
  /// system's reduce-motion setting on, the star stays still at a mid glow.
  void _applyMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _glowController
        ..stop()
        ..value = 0.5;
      _spinController.stop();
      _shakeTimer?.cancel();
      _shakeTimer = null;
      return;
    }
    if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    if (widget.litToday) {
      if (!_spinController.isAnimating) _spinController.repeat();
      _shakeTimer?.cancel();
      _shakeTimer = null;
    } else {
      _spinController.stop();
      _startShakeTimer();
    }
  }

  void _startShakeTimer() {
    _shakeTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _shakeController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _spinController.dispose();
    _shakeController.dispose();
    _shakeTimer?.cancel();
    super.dispose();
  }

  List<BoxShadow> _glow(Color color, double size) {
    final glowT = _glowController.value;
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.25 + 0.3 * glowT),
        blurRadius: size * 0.19 + size * 0.16 * glowT,
        spreadRadius: size * 0.015 + size * 0.05 * glowT,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final width = MediaQuery.sizeOf(context).width;

    return Semantics(
      button: true,
      label: widget.litToday ? strings.litTodayTitle : strings.notLitTodayLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: widget.litToday
                ? _buildLit(colors, strings, width)
                : _buildUnlit(colors, strings, width),
          ),
        ),
      ),
    );
  }

  Widget _buildLit(AppColors colors, AppStrings strings, double width) {
    final starSize = (width / 3).clamp(90.0, 160.0);

    return Column(
      children: [
        StaggeredEntrance(
          index: 0,
          child: AnimatedBuilder(
            animation: Listenable.merge([_glowController, _spinController]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _glow(colors.gold, starSize),
                ),
                child: Transform.rotate(
                  angle: _spinController.value * 2 * pi,
                  child: child,
                ),
              );
            },
            child: Icon(Icons.star, size: starSize, color: colors.gold),
          ),
        ),
        const SizedBox(height: 22),
        StaggeredEntrance(
          index: 1,
          child: _highlightedText(
            text: strings.litTodayTitle,
            highlight: strings.litTodayTitleHighlight,
            highlightColor: colors.gold,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 6),
        StaggeredEntrance(
          index: 2,
          child: _highlightedText(
            text: strings.litTodaySubtitle,
            highlight: strings.litTodaySubtitleHighlight,
            highlightColor: colors.gold,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlit(AppColors colors, AppStrings strings, double width) {
    final starSize = (width / 3).clamp(90.0, 160.0);

    return Column(
      children: [
        StaggeredEntrance(
          index: 0,
          child: AnimatedBuilder(
            animation: _shakeController,
            builder: (context, _) {
              final t = _shakeController.value;
              final dx = sin(t * pi * 6) * (1 - t) * 8;
              // Lights up gold and glows for as long as the shake lasts —
              // the same beat as the "light" buttons in the star reader.
              final glow = sin(t * pi);
              final star = Icon(
                Icons.star,
                size: starSize,
                color: Color.lerp(colors.muted, colors.gold, glow),
              );
              return Transform.translate(
                offset: Offset(dx, 0),
                child: glow < 0.02
                    ? star
                    : Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: starSize * 0.12,
                              sigmaY: starSize * 0.12,
                            ),
                            child: Icon(
                              Icons.star,
                              size: starSize,
                              color: colors.gold.withValues(alpha: 0.75 * glow),
                            ),
                          ),
                          star,
                        ],
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        StaggeredEntrance(
          index: 1,
          child: _highlightedText(
            text: strings.notLitTodayLabel,
            highlight: strings.notLitTodayHighlight,
            highlightColor: colors.muted,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 18),
        StaggeredEntrance(
          index: 2,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusPill),
                boxShadow: [
                  ...goldGlow(colors, strength: 1.1, size: 56),
                  ..._glow(colors.gold, 44),
                ],
              ),
              child: child,
            ),
            child: PillActionButton(
              icon: Icons.star,
              label: strings.lightStarCta,
              onTap: widget.onTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders [text] centered with [highlight] (its first occurrence) recolored
/// to [highlightColor] — used to pick out one word within an otherwise
/// single-colored sentence, per language.
Widget _highlightedText({
  required String text,
  required String highlight,
  required Color highlightColor,
  required TextStyle style,
}) {
  final index = text.indexOf(highlight);
  if (index == -1) {
    return Text(text, textAlign: TextAlign.center, style: style);
  }
  return RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style: style.copyWith(color: highlightColor),
        ),
        TextSpan(text: text.substring(index + highlight.length)),
      ],
    ),
  );
}

/// The day-detail bottom sheet's content — a date heading, a search field, a
/// button to log a new victory already dated to [day], and either the
/// matching achieved stars or an empty-state message.
class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({
    required this.day,
    required this.stars,
    required this.projectsById,
    required this.onStarTap,
    required this.onAddForDay,
  });

  final DateTime day;
  final List<Star> stars;
  final Map<int, Project> projectsById;
  final void Function(List<Star> stars, int index) onStarTap;
  final VoidCallback onAddForDay;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Text _emptyStateText(AppStrings strings, AppColors colors) {
    return Text(
      widget.stars.isEmpty ? strings.dayDetailEmpty : strings.noSearchResults,
      textAlign: TextAlign.center,
      style: TextStyle(color: colors.muted, fontSize: 14),
    );
  }

  List<Star> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.stars;
    return widget.stars.where((s) {
      return s.title.toLowerCase().contains(query) ||
          (s.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final filtered = _filtered;
    final hasStarsForDay = widget.stars.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: hasStarsForDay ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Text(
                formatDisplayDate(widget.day, strings),
                style: TextStyle(
                  fontFamily: kFontMono,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StaggeredEntrance(
              index: 1,
              child: AppTextField(
                controller: _queryController,
                hintText: strings.searchHint,
                onChanged: (value) => setState(() => _query = value),
                prefixIcon: Icon(Icons.search, color: colors.muted, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            StaggeredEntrance(
              index: 2,
              child: Align(
                child: OutlinedButton.icon(
                  onPressed: widget.onAddForDay,
                  icon: const Icon(Icons.add),
                  label: AppButtonLabel(strings.addStarForDayLabel),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              hasStarsForDay
                  ? Expanded(
                      child: StaggeredEntrance(
                        index: 3,
                        child: Center(child: _emptyStateText(strings, colors)),
                      ),
                    )
                  : StaggeredEntrance(
                      index: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: _emptyStateText(strings, colors)),
                      ),
                    )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final star = filtered[index];
                    // The header above takes indices 0-2; the list follows it.
                    return StaggeredEntrance(
                      index: index + 3,
                      child: LitStarCard(
                        star: star,
                        project: widget.projectsById[star.projectId],
                        onTap: () => widget.onStarTap(filtered, index),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A wider, more eye-catching presentation for the total-star count — its
/// own row above the streak cards, rather than squeezed into an equal-width
/// slot alongside them, since it's the headline number on this tab.
class _TotalStarsBanner extends StatelessWidget {
  const _TotalStarsBanner({required this.value, required this.onTap});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(kRadiusCard);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: kSpaceLg - 4,
            horizontal: kSpaceLg - 4,
          ),
          decoration: panelDecoration(colors),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StaggeredEntrance(
                      index: 0,
                      child: Icon(Icons.star, size: 24, color: colors.gold),
                    ),
                    const SizedBox(height: 6),
                    StaggeredEntrance(
                      index: 1,
                      child: Text(
                        '$value',
                        style: context.typography.immersivePageTitle.copyWith(
                          fontFamily: kFontMono,
                          fontSize: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: StaggeredEntrance(
                  index: 2,
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
