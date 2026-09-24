import 'dart:async';
import 'dart:math' show pi, sin;

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
import '../utils/app_modals.dart';
import '../utils/date_format.dart';
import '../utils/star_stats.dart';
import '../widgets/app_field.dart';
import '../widgets/lit_star_card.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/star_heatmap.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';
import 'stat_detail_screen.dart';

/// Today's star, the activity calendar, total stars, and the current/
/// longest streak — everything the old separate Home dashboard and
/// Statistics tab each showed, now one page reached straight from the
/// menu. They used to be two screens (Home ending with the calendar,
/// Statistics starting with the cumulative numbers) linked by a "your
/// dashboard" button; once the Sky became the app's only real screen,
/// that extra tap in between stopped earning its keep, so this page just
/// shows all of it, top (today) to bottom (all-time).
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// The month the activity calendar is currently showing — always the 1st,
  /// so it can be compared/offset by month without caring what day it was
  /// created on. Defaults to the current month; [_changeDisplayedMonth]
  /// moves it, capped so the user can never page past the present month.
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool get _isCurrentMonthDisplayed {
    final now = DateTime.now();
    return _displayedMonth.year == now.year &&
        _displayedMonth.month == now.month;
  }

  void _changeDisplayedMonth(int delta) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    setState(() {
      _displayedMonth = next.isAfter(currentMonth) ? currentMonth : next;
    });
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
    return widget.starRepository.getAll().where((s) {
      if (!s.isLit) return false;
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
        ),
      ),
    );
  }

  void _openCurrentStreakDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CurrentStreakDetailScreen(starRepository: widget.starRepository),
      ),
    );
  }

  void _openLongestStreakDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LongestStreakDetailScreen(starRepository: widget.starRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final achievedStars = widget.starRepository
        .getAll()
        .where((s) => s.isLit)
        .toList();
    final dayCounts = starCountsByDay(achievedStars);
    final dayIntensities = starIntensityByDay(achievedStars);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final litToday = (dayCounts[today] ?? 0) > 0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
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
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.arrow_back, color: colors.muted),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.statsEyebrow,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                            color: colors.accentDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      strings.statsTitle,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 1,
                    child: Text(
                      strings.todayStarSectionLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
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
                    child: Text(
                      strings.activityLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 2,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      clipBehavior: Clip.antiAlias,
                      decoration: panelDecoration(colors),
                      child: StarHeatmap(
                        month: _displayedMonth,
                        countsByDay: dayCounts,
                        intensityByDay: dayIntensities,
                        onDayTap: _openDayDetail,
                        onPreviousMonth: () => _changeDisplayedMonth(-1),
                        onNextMonth: _isCurrentMonthDisplayed
                            ? null
                            : () => _changeDisplayedMonth(1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 3,
                    child: Text(
                      strings.totalStarsLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 3,
                    child: _TotalStarsBanner(
                      value: achievedStars.length,
                      onTap: _openTotalStarsDetail,
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    index: 4,
                    child: Text(
                      strings.streaksSectionLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StaggeredEntrance(
                          index: 4,
                          axis: Axis.horizontal,
                          child: _StatCard(
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
                          child: _StatCard(
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
  )..repeat(reverse: true);
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
  void initState() {
    super.initState();
    if (widget.litToday) {
      _spinController.repeat();
    } else {
      _startShakeTimer();
    }
  }

  @override
  void didUpdateWidget(_TodayStarHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.litToday == oldWidget.litToday) return;
    if (widget.litToday) {
      _spinController.repeat();
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

    return Material(
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
            builder: (context, child) {
              final t = _shakeController.value;
              final dx = sin(t * pi * 6) * (1 - t) * 8;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Icon(Icons.star, size: starSize, color: colors.muted),
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
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.gold,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  boxShadow: [
                    ...goldGlow(colors, strength: 1.1, size: 56),
                    ..._glow(colors.gold, 44),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: child,
              );
            },
            child: Text(
              strings.lightStarCta,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.night,
              ),
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            const SizedBox(height: 14),
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
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onAddForDay,
                  icon: const Icon(Icons.add),
                  label: Text(strings.addStarForDayLabel),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              hasStarsForDay
                  ? Expanded(
                      child: StaggeredEntrance(
                        index: 3,
                        child: Center(
                          child: _emptyStateText(strings, colors),
                        ),
                      ),
                    )
                  : StaggeredEntrance(
                      index: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: _emptyStateText(strings, colors),
                        ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(kRadiusCard);
    return Material(
      color: colors.nightPanel,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: colors.nightBorder),
            borderRadius: borderRadius,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontFamily: kFontMono,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  StaggeredEntrance(
                    index: 1,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -2,
                right: -2,
                child: StaggeredEntrance(
                  index: 1,
                  child: Icon(Icons.info_outline, size: 14, color: colors.gold),
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.gold.withValues(alpha: 0.22),
                colors.gold.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: colors.gold.withValues(alpha: 0.45)),
            borderRadius: borderRadius,
          ),
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
                        style: TextStyle(
                          fontFamily: kFontMono,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                          height: 1,
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
                  child: Icon(Icons.info_outline, size: 16, color: colors.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
