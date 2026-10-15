import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/habit_cycle.dart';
import '../models/life_area.dart';
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
import '../utils/entity_insights.dart';
import '../utils/icon_for_slug.dart';
import '../utils/light_stats.dart';
import '../widgets/app_choice_chip.dart';
import '../widgets/area_tag.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/habit_cycle_detail_dialog.dart';
import '../widgets/habit_cycle_host.dart';
import '../widgets/habit_cycle_scope.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/lit_star_card.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/stats/accumulation_chart.dart';
import '../widgets/stats/stats_widgets.dart';
import 'star_reader_screen.dart';

/// Where "Your Light" was left when opened from the Galaxy menu, so coming
/// back restores the scope and period instead of starting over.
class LightSession {
  InsightEntity? scope;
  LightPeriod period = LightPeriod.allTime;
}

/// Opens "Your Light" on [scope] (everything when null).
Future<void> openLightPage(
  BuildContext context, {
  InsightEntity? scope,
  LightSession? session,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LightScreen(initialScope: scope, session: session),
    ),
  );
}

/// Every per-entity "Statistics" button (Sky cards, Galaxy tooltips, area
/// and constellation docks, the readers) lands here, on its own scope.
Future<void> openEntityStatistics(BuildContext context, InsightEntity entity) =>
    openLightPage(context, scope: entity);

/// The one statistics page: what has been lit, as one growing intensity
/// total, for everything or for one area, constellation or activity. Every
/// "Statistics" button opens it on its own scope; the trail at the top
/// moves back up, the "Where it shines" rows move down.
///
/// Only what was done is shown — no current streaks, no targets, no
/// missed days.
class LightScreen extends StatefulWidget {
  const LightScreen({super.key, this.initialScope, this.session});

  final InsightEntity? initialScope;
  final LightSession? session;

  @override
  State<LightScreen> createState() => _LightScreenState();
}

class _LightScreenState extends State<LightScreen> {
  late final LightSession _session =
      widget.session ?? (LightSession()..scope = widget.initialScope);

  void _setScope(InsightEntity? scope) =>
      setState(() => _session.scope = scope);

  void _setPeriod(LightPeriod period) =>
      setState(() => _session.period = period);

  Future<void> _pickPeriod() async {
    final period = await showAppSheet<LightPeriod>(
      context: context,
      builder: (sheetContext) => _PeriodSheet(selected: _session.period),
    );
    if (period != null && mounted) _setPeriod(period);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final controller = EntityInsightsScope.maybeOf(context);
    final cycles =
        HabitCycleScope.maybeOf(context)?.getAll() ?? const <HabitCycle>[];
    final allProjects = controller?.projects.getAll() ?? const <Project>[];
    final allStars = controller?.stars.getAll() ?? const <Star>[];
    final allHabits = controller?.habits.getAll() ?? const <Habit>[];
    final stats = LightStats.build(
      scope: _session.scope,
      period: _session.period,
      projects: allProjects,
      stars: allStars,
      habits: allHabits,
      completions: controller?.completions.getAll() ?? const [],
      cycles: cycles,
    );
    final names = _Names(
      strings: strings,
      projects: {for (final p in allProjects) p.id: p},
      stars: {for (final s in allStars) s.id: s},
      habits: {for (final h in allHabits) h.id: h},
    );

    final sections = <Widget>[];
    if (stats.isStarScope) {
      final star = stats.stars.firstOrNull;
      sections.addAll([
        StatsSectionLabel(strings.lightOverviewLabel),
        star == null
            ? StatsEmptyState(strings.insightUnavailable)
            : _StarFacts(star: star),
      ]);
    } else {
      sections.addAll([
        StatsSectionLabel(strings.lightOverviewLabel),
        _LightHero(stats: stats),
      ]);
      final habit = stats.isHabitScope ? stats.habits.firstOrNull : null;
      final habitCycles = habit == null
          ? const <HabitCycle>[]
          : [
              for (final cycle in cycles)
                if (cycle.habitId == habit.id) cycle,
            ];
      if (habit != null && habitCycles.isNotEmpty) {
        habitCycles.sort((a, b) => b.completedDate.compareTo(a.completedDate));
        sections.addAll([
          StatsSectionLabel(strings.cycleHistoryTitle),
          _CycleHistory(
            cycles: habitCycles,
            onReflect: (cycle) => _reflect(habit, cycle),
          ),
        ]);
      }
      final hasLight = stats.activeDays.isNotEmpty;
      if (!hasLight && _session.period != LightPeriod.allTime) {
        sections.add(
          Center(
            child: TextButton(
              onPressed: () => _setPeriod(LightPeriod.allTime),
              child: AppButtonLabel(strings.lightSeeAllTimeAction),
            ),
          ),
        );
      }
      if (hasLight) {
        sections.addAll([
          StatsSectionLabel(
            stats.isHabitScope
                ? strings.habitStatsDaysDoneLabel
                : strings.lightCurveLabel,
          ),
          AccumulationChart(
            points: stats.cumulative,
            dateLabel: (date) => formatDisplayDate(date, strings),
            axisLabel: strings.lightCurveHint,
          ),
          StatsSectionLabel(strings.lightCalendarLabel),
          HeatmapPanel(
            key: ValueKey(_session.period),
            countsByDay: stats.isHabitScope
                ? stats.checkInsByDay
                : stats.countsByDay,
            intensityByDay: stats.isHabitScope
                ? stats.checkInsByDay
                : stats.lightByDay,
            onDayTap: (day) => _openDay(day, stats, names),
          ),
        ]);
        if (stats.breakdown.isNotEmpty) {
          sections.addAll([
            StatsSectionLabel(strings.lightBreakdownLabel),
            _Breakdown(
              shares: stats.breakdown,
              names: names,
              onTap: (share) => _setScope(share.entity),
            ),
          ]);
        }
        if (!stats.moments.isEmpty) {
          sections.addAll([
            StatsSectionLabel(strings.lightMomentsLabel),
            _Moments(
              moments: stats.moments,
              names: names,
              onOpenStar: (star) => _openStars([star], 0),
            ),
          ]);
        }
      }
    }

    final navigationHeight = stats.isStarScope ? 64.0 : 128.0;
    return PopScope(
      canPop: _session.scope == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _session.scope == null) return;
        final trail = names.trail(_session.scope);
        _setScope(trail.length > 1 ? trail[trail.length - 2] : null);
      },
      child: Scaffold(
        backgroundColor: context.colors.night,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _LightTitleHero(title: strings.lightPageTitle),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedLightNavigationDelegate(
                  height: navigationHeight,
                  child: _LightNavigationBar(
                    trail: names.trail(_session.scope),
                    names: names,
                    period: stats.isStarScope ? null : _session.period,
                    onScopeTap: _setScope,
                    onPeriodTap: _pickPeriod,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  kPageInsetCompact,
                  kSpaceLg,
                  kPageInsetCompact,
                  kSpaceXxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < sections.length; i++) ...[
                          if (i > 0)
                            SizedBox(
                              height: sections[i] is StatsSectionLabel
                                  ? kSpaceLg
                                  : kSpaceSm,
                            ),
                          StaggeredEntrance(
                            index: 2 + i ~/ 2,
                            child: sections[i],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A cycle whose reflection was left for later is reflected on from here.
  Future<void> _reflect(Habit habit, HabitCycle cycle) async {
    final controller = EntityInsightsScope.maybeOf(context);
    final cycleRepository = HabitCycleScope.read(context);
    if (controller == null || cycleRepository == null) return;
    await openHabitCycleReflection(
      navigator: Navigator.of(context),
      habit: habit,
      cycle: cycle,
      habitRepository: controller.habits,
      cycleRepository: cycleRepository,
    );
  }

  Future<void> _openStars(List<Star> stars, int index) async {
    final controller = EntityInsightsScope.maybeOf(context);
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StarReaderScreen(
          repository: controller.stars,
          initialStars: stars,
          startIndex: index,
          allowEdit: true,
          projectsById: {
            for (final project in controller.projects.getAll())
              project.id: project,
          },
          projectRepository: controller.projects,
          starsShapeRepository: controller.shapes,
        ),
      ),
    );
  }

  Future<void> _openDay(DateTime day, LightStats stats, _Names names) async {
    final victories = [
      for (final star in stats.victories)
        if (dateOnly(star.achievedDate!) == day) star,
    ];
    final cycles = [
      for (final cycle in stats.cycles)
        if (dateOnly(cycle.completedDate) == day) cycle,
    ];
    final checkedHabits = {
      for (final completion in stats.completions)
        if (dateOnly(completion.date) == day) completion.habitId,
    };
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (sheetContext) => _DaySheet(
        day: day,
        victories: victories,
        cycles: cycles,
        habits: [
          for (final id in checkedHabits)
            if (names.habits[id] != null) names.habits[id]!,
        ],
        names: names,
        onStarTap: (index) {
          Navigator.of(sheetContext).pop();
          _openStars(victories, index);
        },
      ),
    );
  }
}

class _LightTitleHero extends StatelessWidget {
  const _LightTitleHero({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleZone = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, 143),
            width: constraints.maxWidth.clamp(250.0, 390.0),
            height: 96,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .14, .58, 1],
                ).createShader(bounds),
                child: NightlightStarfield(
                  starCount: 52,
                  color: colors.gold,
                  intensity: 1.55,
                  glowTightness: 1.45,
                  glowIntensity: .5,
                  exclusionZones: [titleZone],
                ),
              ),
              Align(
                alignment: const Alignment(0, -.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kPageInsetCompact,
                  ),
                  child: ResponsiveContent(
                    child: StaggeredEntrance(
                      index: 0,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kFontBranding,
                          fontSize: 58,
                          height: 1.05,
                          color: colors.gold,
                          shadows: [
                            Shadow(
                              color: colors.gold.withValues(alpha: .68),
                              blurRadius: 14,
                            ),
                            Shadow(
                              color: colors.gold.withValues(alpha: .3),
                              blurRadius: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Resolves scope entities to names, icons and their parent chain.
class _Names {
  const _Names({
    required this.strings,
    required this.projects,
    required this.stars,
    required this.habits,
  });

  final AppStrings strings;
  final Map<int, Project> projects;
  final Map<int, Star> stars;
  final Map<int, Habit> habits;

  Project? projectOf(InsightEntity entity) => switch (entity.kind) {
    InsightEntityKind.project => projects[entity.id],
    InsightEntityKind.star => projects[stars[entity.id]?.projectId],
    InsightEntityKind.habit => projects[habits[entity.id]?.projectId],
    InsightEntityKind.area => null,
  };

  String label(InsightEntity entity) => switch (entity.kind) {
    InsightEntityKind.area => entity.area!.displayName(strings),
    InsightEntityKind.project =>
      projects[entity.id]?.displayName ?? strings.insightUnavailable,
    InsightEntityKind.star =>
      stars[entity.id]?.displayTitle ?? strings.insightUnavailable,
    InsightEntityKind.habit =>
      habits[entity.id]?.displayTitle ?? strings.insightUnavailable,
  };

  IconData icon(InsightEntity entity) {
    switch (entity.kind) {
      case InsightEntityKind.area:
        return entity.area!.icon;
      case InsightEntityKind.project:
        final slug = projects[entity.id]?.iconSlug ?? '';
        return slug.isEmpty ? Icons.hub_outlined : iconForSlug(slug);
      case InsightEntityKind.star:
        final slug = stars[entity.id]?.iconSlug ?? '';
        return slug.isEmpty ? StarKind.lit.icon : iconForSlug(slug);
      case InsightEntityKind.habit:
        final slug = habits[entity.id]?.iconSlug ?? '';
        return slug.isEmpty ? StarKind.pulsar.icon : iconForSlug(slug);
    }
  }

  /// Everything › area › constellation › activity, down to [scope].
  List<InsightEntity?> trail(InsightEntity? scope) {
    if (scope == null) return const [null];
    if (scope.kind == InsightEntityKind.area) return [null, scope];
    final project = projectOf(scope);
    return [
      null,
      if (project != null) InsightEntity.area(project.area),
      if (project != null && scope.kind != InsightEntityKind.project)
        InsightEntity.project(project.id),
      scope,
    ];
  }
}

/// A one-line breadcrumb. Every ancestor stays visible as a compact icon-only
/// step while the current scope uses the remaining width for its label.
class _ScopeTrail extends StatelessWidget {
  const _ScopeTrail({
    required this.trail,
    required this.names,
    required this.onTap,
  });

  final List<InsightEntity?> trail;
  final _Names names;
  final ValueChanged<InsightEntity?> onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    String label(InsightEntity? entity) =>
        entity == null ? strings.lightScopeAll : names.label(entity);
    IconData icon(InsightEntity? entity) =>
        entity == null ? Icons.auto_awesome : names.icon(entity);
    final current = trail.last;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final entity in trail.take(trail.length - 1)) ...[
          Tooltip(
            message: label(entity),
            child: Semantics(
              button: true,
              label: label(entity),
              child: InkWell(
                onTap: () => onTap(entity),
                borderRadius: BorderRadius.circular(kRadiusField),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: selectableDecoration(
                    context.colors,
                    selected: false,
                  ),
                  child: Icon(
                    icon(entity),
                    size: 16,
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 12,
            color: context.colors.muted,
          ),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: AppChoiceChip(
              key: const ValueKey('light-current-scope'),
              label: label(current),
              icon: icon(current),
              selected: true,
              onPressed: () => onTap(current),
            ),
          ),
        ),
      ],
    );
  }
}

String _periodLabel(BuildContext context, LightPeriod value) => switch (value) {
  LightPeriod.allTime => context.strings.lightPeriodAllTime,
  LightPeriod.year => context.strings.lightPeriodYear,
  LightPeriod.month => context.strings.lightPeriodMonth,
};

class _LightNavigationBar extends StatelessWidget {
  const _LightNavigationBar({
    required this.trail,
    required this.names,
    required this.period,
    required this.onScopeTap,
    required this.onPeriodTap,
  });

  final List<InsightEntity?> trail;
  final _Names names;
  final LightPeriod? period;
  final ValueChanged<InsightEntity?> onScopeTap;
  final VoidCallback onPeriodTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scope = _ScopeTrail(trail: trail, names: names, onTap: onScopeTap);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.night),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPageInsetCompact),
          child: period == null
              ? Center(child: scope)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 48, child: scope),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Tooltip(
                        message: context.strings.lightPeriodFilterLabel,
                        child: InkWell(
                          key: const ValueKey('light-period-button'),
                          onTap: onPeriodTap,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            decoration: selectableDecoration(
                              colors,
                              selected: true,
                              radius: kRadiusPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 14,
                                  color: colors.gold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _periodLabel(context, period!),
                                  key: const ValueKey('light-period-value'),
                                  maxLines: 1,
                                  style: context.typography.microLabel.copyWith(
                                    color: colors.text,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.selected});

  final LightPeriod selected;

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      title: AppSheetTitle(context.strings.lightPeriodFilterLabel),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in LightPeriod.values) ...[
              if (value != LightPeriod.values.first)
                const SizedBox(height: kSpaceSm),
              AppChoiceChip(
                label: _periodLabel(context, value),
                icon: value == selected
                    ? Icons.check_rounded
                    : Icons.calendar_today_outlined,
                selected: value == selected,
                expand: true,
                onPressed: () => Navigator.of(context).pop(value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinnedLightNavigationDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedLightNavigationDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_PinnedLightNavigationDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

/// The headline: how much light (or, for a pulsar, how many days done),
/// with what it is made of underneath.
class _LightHero extends StatelessWidget {
  const _LightHero({required this.stats});

  final LightStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final habitScope = stats.isHabitScope;
    final value = habitScope ? stats.daysDone : stats.light;
    final parts = <String>[
      if (!habitScope && stats.victories.isNotEmpty)
        strings.starsCount(stats.victories.length),
      if (stats.cycles.isNotEmpty)
        strings.lightCyclesCount(stats.cycles.length),
      if (habitScope && stats.cycleLight > 0)
        '${stats.cycleLight} ${strings.intensityLabel}',
      if (!habitScope && stats.activeDays.isNotEmpty)
        strings.lightDaysCount(stats.activeDays.length),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpaceLg - 4,
        horizontal: kSpaceMd,
      ),
      decoration: panelDecoration(colors),
      child: Column(
        children: [
          Icon(
            habitScope ? StarKind.pulsar.icon : Icons.star,
            size: 26,
            color: value > 0 ? colors.gold : colors.muted,
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            '$value',
            style: context.typography.immersivePageTitle.copyWith(
              fontFamily: kFontMono,
              fontSize: 40,
              color: value > 0 ? colors.gold : colors.text,
            ),
          ),
          Text(
            habitScope
                ? strings.habitStatsDaysDoneLabel
                : strings.intensityLabel,
            style: context.typography.microLabel,
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: kSpaceSm),
            Text(
              parts.join(' · '),
              textAlign: TextAlign.center,
              style: context.typography.supporting,
            ),
          ],
          const SizedBox(height: kSpaceSm),
          Text(
            value > 0 ? strings.lightHeadline : strings.lightHeadlineEmpty,
            textAlign: TextAlign.center,
            style: context.typography.body,
          ),
        ],
      ),
    );
  }
}

/// "Where it shines": the scope's children by light, each one a step
/// down into it.
class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.shares,
    required this.names,
    required this.onTap,
  });

  final List<LightShare> shares;
  final _Names names;
  final ValueChanged<LightShare> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final max = shares.first.light;
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final share in shares)
              InkWell(
                onTap: () => onTap(share),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceMd,
                    vertical: kSpaceSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: share.entity.kind == InsightEntityKind.area
                                ? AreaTag(
                                    area: share.entity.area!,
                                    iconSize: 16,
                                    fontSize: 14,
                                    textColor: colors.text,
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        names.icon(share.entity),
                                        size: 16,
                                        color: colors.gold,
                                      ),
                                      const SizedBox(width: kSpaceXs),
                                      Expanded(
                                        child: Text(
                                          names.label(share.entity),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.typography.body,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(width: kSpaceSm),
                          Icon(Icons.star, size: 14, color: colors.gold),
                          const SizedBox(width: 4),
                          Text(
                            '${share.light}',
                            style: context.typography.supporting.copyWith(
                              color: colors.text,
                              fontFamily: kFontMono,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: colors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpaceXs),
                      StatsGlowBar(value: max == 0 ? 0 : share.light / max),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The period's highlights, one row each.
class _Moments extends StatelessWidget {
  const _Moments({
    required this.moments,
    required this.names,
    required this.onOpenStar,
  });

  final LightMoments moments;
  final _Names names;
  final ValueChanged<Star> onOpenStar;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    String date(DateTime value) => formatDisplayDate(value, strings);
    final firstVictory = moments.firstVictory;
    final run = moments.longestRun;
    final cycle = moments.longestCycle;
    final rows = <Widget>[
      if (firstVictory != null)
        _MomentRow(
          icon: Icons.flag_rounded,
          title: strings.momentFirstVictory,
          value: firstVictory.displayTitle,
          detail: date(firstVictory.achievedDate!),
          onTap: () => onOpenStar(firstVictory),
        ),
      if (moments.firstDay != null)
        _MomentRow(
          icon: Icons.flag_rounded,
          title: strings.momentFirstDay,
          value: date(moments.firstDay!),
        ),
      if (moments.brightestDay != null)
        _MomentRow(
          icon: Icons.wb_sunny_outlined,
          title: strings.momentBrightestDay,
          value: date(moments.brightestDay!),
          detail: '${moments.brightestDayLight} ${strings.intensityLabel}',
        ),
      if (run != null)
        _MomentRow(
          icon: Icons.linear_scale_rounded,
          title: strings.momentLongestRun,
          value: strings.habitStatsDays(run.length),
          detail: '${date(run.start)} – ${date(run.end)}',
        ),
      if (moments.favouriteWeekday != null)
        _MomentRow(
          icon: Icons.event_available_rounded,
          title: strings.momentFavouriteWeekday,
          value: strings.weekdayNames[moments.favouriteWeekday! - 1],
        ),
      if (moments.brightestMonth != null)
        _MomentRow(
          icon: Icons.calendar_month_rounded,
          title: strings.momentBrightestMonth,
          value: strings.monthTitle(moments.brightestMonth!),
          detail: '${moments.brightestMonthLight} ${strings.intensityLabel}',
        ),
      if (cycle != null)
        _MomentRow(
          icon: Icons.autorenew_rounded,
          title: strings.momentLongestCycle,
          value: strings.cycleHistoryItem(cycle.length),
          detail:
              '${names.habits[cycle.habitId]?.displayTitle ?? ''} · '
              '${date(cycle.completedDate)}',
        ),
    ];
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: rows),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd,
          vertical: kSpaceSm + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.gold),
            const SizedBox(width: kSpaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.typography.microLabel),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: context.typography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null && detail!.isNotEmpty)
                    Text(detail!, style: context.typography.supporting),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

/// A pulsar's completed cycles, newest first, each with the reward it
/// earned; one whose reflection was left for later offers it again.
class _CycleHistory extends StatelessWidget {
  const _CycleHistory({required this.cycles, required this.onReflect});

  final List<HabitCycle> cycles;
  final ValueChanged<HabitCycle> onReflect;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final pending = cycles.where((c) => !c.resolved).firstOrNull;
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending != null)
              Padding(
                padding: const EdgeInsets.all(kSpaceMd),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => onReflect(pending),
                    icon: const Icon(Icons.auto_awesome),
                    label: AppButtonLabel(strings.cycleReflectAction),
                  ),
                ),
              ),
            for (final cycle in cycles)
              InkWell(
                // Only a cycle with answers has something more to read.
                onTap: cycle.hasReflection
                    ? () => showHabitCycleDetail(context, cycle)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceMd,
                    vertical: kSpaceSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.autorenew_rounded,
                        size: 20,
                        color: colors.gold,
                      ),
                      const SizedBox(width: kSpaceSm),
                      Expanded(
                        child: Text(
                          '${strings.cycleHistoryItem(cycle.length)} · '
                          '${formatDisplayDate(cycle.completedDate, strings)}',
                          style: context.typography.body,
                        ),
                      ),
                      if (cycle.hasReflection) ...[
                        Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: colors.muted,
                        ),
                        const SizedBox(width: kSpaceXs),
                      ],
                      IntensityBolts(intensity: cycle.intensity, size: 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single star's own page: when it was lit and how brightly — or, for a
/// goal, a gentle note that its light is still to come.
class _StarFacts extends StatelessWidget {
  const _StarFacts({required this.star});

  final Star star;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    String date(DateTime value) => formatDisplayDate(value, strings);
    final achieved = star.achievedDate;
    final rows = <Widget>[
      if (achieved != null) ...[
        _MomentRow(
          icon: Icons.star,
          title: strings.insightAchieved,
          value: date(achieved),
        ),
        if (star.intensity != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceMd,
              vertical: kSpaceSm + 2,
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, size: 22, color: colors.gold),
                const SizedBox(width: kSpaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.intensityLabel,
                        style: context.typography.microLabel,
                      ),
                      const SizedBox(height: 4),
                      IntensityBolts(intensity: star.intensity!, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (dayDiff(star.createdAt, achieved) > 0)
          _MomentRow(
            icon: Icons.hourglass_bottom_rounded,
            title: strings.insightDuration,
            value: strings.habitStatsDays(dayDiff(star.createdAt, achieved)),
          ),
      ],
      _MomentRow(
        icon: Icons.add_circle_outline,
        title: strings.insightCreated,
        value: date(star.createdAt),
      ),
      if (star.dead && star.deadDate != null)
        _MomentRow(
          icon: StarKind.dead.icon,
          title: strings.insightArchived,
          value: date(star.deadDate!),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: panelDecoration(colors),
          child: Column(children: rows),
        ),
        if (star.isUnlit) ...[
          const SizedBox(height: kSpaceMd),
          Text(
            strings.lightGoalWaitingBody,
            textAlign: TextAlign.center,
            style: context.typography.supporting,
          ),
        ],
      ],
    );
  }
}

/// Everything one calendar day held: its victories (each opens the star
/// reader), completed cycles and checked pulsars.
class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.day,
    required this.victories,
    required this.cycles,
    required this.habits,
    required this.names,
    required this.onStarTap,
  });

  final DateTime day;
  final List<Star> victories;
  final List<HabitCycle> cycles;
  final List<Habit> habits;
  final _Names names;
  final ValueChanged<int> onStarTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final empty = victories.isEmpty && cycles.isEmpty && habits.isEmpty;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            formatDisplayDate(day, strings),
            style: TextStyle(
              fontFamily: kFontMono,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: colors.text,
            ),
          ),
          const SizedBox(height: kSpaceMd),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpaceLg),
              child: StatsEmptyState(strings.lightHeadlineEmpty),
            ),
          for (var i = 0; i < victories.length; i++) ...[
            LitStarCard(
              star: victories[i],
              project: names.projects[victories[i].projectId],
              onTap: () => onStarTap(i),
            ),
            const SizedBox(height: kSpaceSm),
          ],
          for (final cycle in cycles)
            _DayRow(
              icon: Icons.autorenew_rounded,
              title: names.habits[cycle.habitId]?.displayTitle ?? '',
              trailing: IntensityBolts(intensity: cycle.intensity, size: 14),
              detail: strings.cycleHistoryItem(cycle.length),
            ),
          for (final habit in habits)
            _DayRow(
              icon: habit.iconSlug.isEmpty
                  ? StarKind.pulsar.icon
                  : iconForSlug(habit.iconSlug),
              title: habit.displayTitle,
              trailing: Icon(Icons.check_circle, size: 18, color: colors.gold),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.detail,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceXs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.gold),
          const SizedBox(width: kSpaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.typography.body),
                if (detail != null && detail!.isNotEmpty)
                  Text(detail!, style: context.typography.supporting),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
