import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/habit_cycle.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_media.dart';
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
import '../utils/badge_schema.dart';
import '../utils/light_stats.dart';
import '../utils/responsive.dart';
import '../utils/star_card_info.dart';
import '../widgets/app_choice_chip.dart';
import '../widgets/area_icon.dart';
import '../widgets/area_tag.dart';
import '../widgets/badge_icon.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/glow_icon.dart';
import '../widgets/habit_cycle_detail_dialog.dart';
import '../widgets/habit_cycle_host.dart';
import '../widgets/habit_cycle_scope.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import '../widgets/sky_explorer_view.dart';
import '../widgets/sky_navigation_target.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/stats/accumulation_chart.dart';
import '../widgets/stats/stats_widgets.dart';
import 'star_reader_screen.dart';
import 'today_habits_screen.dart';

/// Where "Your Light" was left when opened from the Galaxy menu, so coming
/// back restores the scope and period instead of starting over.
class LightSession {
  InsightEntity? scope;
  LightPeriod period = LightPeriod.allTime;
  DateTime? calendarMonth;
  double scrollOffset = 0;
}

/// Opens "Your Light" on [scope] (everything when null).
Future<SkyNavigationTarget?> openLightPage(
  BuildContext context, {
  InsightEntity? scope,
  LightSession? session,
}) async {
  return Navigator.of(context).push<SkyNavigationTarget>(
    MaterialPageRoute<SkyNavigationTarget>(
      builder: (_) => LightScreen(initialScope: scope, session: session),
    ),
  );
}

/// Every per-entity "Statistics" button (Sky cards, Galaxy tooltips, area
/// and constellation docks, the readers) lands here, on its own scope.
Future<void> openEntityStatistics(
  BuildContext context,
  InsightEntity entity,
) async {
  await openLightPage(context, scope: entity);
}

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
  late final ScrollController _scrollController;
  bool _isFlyingToGalaxy = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _session.scrollOffset,
    )..addListener(() => _session.scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _session.scrollOffset = _scrollController.offset;
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _setScope(InsightEntity? scope) =>
      setState(() => _session.scope = scope);

  void _setPeriod(LightPeriod period) =>
      setState(() => _session.period = period);

  void _exitStatistics() => Navigator.of(context).pop();

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
        StatsNote(
          (stats.isHabitScope ? stats.daysDone : stats.light) > 0
              ? strings.lightOverviewNote
              : '${strings.lightHeadlineEmpty} ${strings.lightOverviewNote}',
        ),
      ]);
      final scope = _session.scope;
      if (scope == null ||
          scope.kind == InsightEntityKind.area ||
          scope.kind == InsightEntityKind.project) {
        sections.addAll([
          StatsSectionLabel(strings.managementSectionLabel),
          _ManageActivitiesButton(
            label: strings.manageActivities,
            onPressed: () => openTodayHabits(context, scope),
          ),
        ]);
      }
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
          StatsNote(strings.cycleHistoryNote),
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
            axisLabel: strings.lightCurveLabel,
          ),
          StatsNote(strings.lightCurveHint),
          StatsSectionLabel(strings.lightCalendarLabel),
          HeatmapPanel(
            key: ValueKey(_session.period),
            countsByDay: stats.isHabitScope
                ? stats.checkInsByDay
                : stats.countsByDay,
            intensityByDay: stats.isHabitScope
                ? stats.checkInsByDay
                : stats.lightByDay,
            onDayTap: _openDay,
            initialMonth: _session.calendarMonth,
            onMonthChanged: (month) => _session.calendarMonth = month,
          ),
          StatsNote(strings.lightCalendarNote),
        ]);
        if (stats.breakdown.isNotEmpty) {
          sections.addAll([
            StatsSectionLabel(strings.lightBreakdownLabel),
            _Breakdown(
              shares: stats.breakdown,
              names: names,
              onTap: (share) => _setScope(share.entity),
            ),
            StatsNote(strings.lightBreakdownNote),
          ]);
        }
        if (!stats.moments.isEmpty) {
          sections.addAll([
            StatsSectionLabel(strings.lightMomentsLabel),
            _Moments(
              stats: stats,
              moments: stats.moments,
              names: names,
              onOpenStar: (star) => _openStars([star], 0),
              onOpenDay: _openDay,
              onOpenRun: (run) => _openRun(stats, run),
              onOpenMonth: (month) => _openMonth(stats, month),
            ),
            StatsNote(strings.lightMomentsNote),
          ]);
        }
      }
    }

    final navigationHeight = stats.isStarScope
        ? 64.0
        : isWideLayout(context)
        ? 88.0
        : 140.0;
    return PopScope(
      canPop: _isFlyingToGalaxy || _session.scope == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isFlyingToGalaxy || _session.scope == null) return;
        final trail = names.trail(_session.scope);
        _setScope(trail.length > 1 ? trail[trail.length - 2] : null);
      },
      child: Scaffold(
        backgroundColor: context.colors.night,
        body: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
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
                    onExit: _exitStatistics,
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
    final starIds = stars.map((star) => star.id).toList(growable: false);

    List<Star> refreshStars() {
      final currentById = {
        for (final star in controller.stars.getAll()) star.id: star,
      };
      return starIds.map((id) => currentById[id]).whereType<Star>().toList();
    }

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
          refreshStars: refreshStars,
        ),
      ),
    );
  }

  Future<SkyNavigationTarget?> _openDay(
    DateTime day, {
    bool flyToGalaxy = true,
  }) async {
    final controller = EntityInsightsScope.maybeOf(context);
    if (controller == null ||
        controller.areaVisions == null ||
        controller.reflections == null ||
        controller.settings == null) {
      return null;
    }
    final session = SkyExplorerSession()..modeIndex = 2;
    final target = await Navigator.of(context).push<SkyNavigationTarget>(
      MaterialPageRoute<SkyNavigationTarget>(
        builder: (_) => Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: context.colors.night,
          body: SafeArea(
            maintainBottomViewPadding: true,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: SkyExplorerView(
                projectRepository: controller.projects,
                starRepository: controller.stars,
                habitRepository: controller.habits,
                habitCompletionRepository: controller.completions,
                starsShapeRepository: controller.shapes,
                areaVisionRepository: controller.areaVisions!,
                reflectionAnswerRepository: controller.reflections!,
                settings: controller.settings!,
                session: session,
                dayContext: SkyDayContext(day: day, entity: _session.scope),
                onNavigateTo: (value) => Navigator.of(context).pop(value),
              ),
            ),
          ),
        ),
      ),
    );
    if (target == null || !mounted || !flyToGalaxy) return target;
    _flyToGalaxy(target);
    return target;
  }

  Future<void> _openRun(LightStats stats, LightRun run) async {
    final target = await showAppSheet<SkyNavigationTarget>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheetContext) => _LightRunSheet(
        stats: stats,
        run: run,
        onDayTap: (value) async {
          final target = await _openDay(value, flyToGalaxy: false);
          if (target != null && sheetContext.mounted) {
            Navigator.of(sheetContext).pop(target);
          }
        },
      ),
    );
    if (target != null && mounted) _flyToGalaxy(target);
  }

  Future<void> _openMonth(LightStats stats, DateTime month) async {
    final target = await showAppSheet<SkyNavigationTarget>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * .85).clamp(0.0, 600.0),
      ),
      builder: (sheetContext) => _BrightestMonthSheet(
        stats: stats,
        month: month,
        onDayTap: (value) async {
          final target = await _openDay(value, flyToGalaxy: false);
          if (target != null && sheetContext.mounted) {
            Navigator.of(sheetContext).pop(target);
          }
        },
      ),
    );
    if (target != null && mounted) _flyToGalaxy(target);
  }

  void _flyToGalaxy(SkyNavigationTarget target) {
    setState(() => _isFlyingToGalaxy = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(target);
    });
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
        entity == null ? Icons.explore : names.icon(entity);
    Widget entityIcon(
      InsightEntity? entity, {
      required double size,
      required Color color,
    }) {
      if (entity?.kind == InsightEntityKind.area) {
        // Area SVGs fill their square more fully than Material icons. Keep the
        // same footprint in the breadcrumb, but optically scale the artwork.
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: AreaIcon(
              area: entity!.area!,
              size: size,
              color: color,
            ),
          ),
        );
      }
      return Icon(icon(entity), size: size, color: color);
    }

    final current = trail.last;
    return Row(
      key: const ValueKey('light-scope-trail'),
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
                  child: entityIcon(
                    entity,
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
              icon: current?.kind == InsightEntityKind.area
                  ? null
                  : icon(current),
              leading: current?.kind == InsightEntityKind.area
                  ? SizedBox.square(
                      dimension: 16,
                      child: Center(
                        child: AreaIcon(
                          area: current!.area!,
                          size: 16,
                          color: context.colors.gold,
                        ),
                      ),
                    )
                  : null,
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
    required this.onExit,
  });

  final List<InsightEntity?> trail;
  final _Names names;
  final LightPeriod? period;
  final ValueChanged<InsightEntity?> onScopeTap;
  final VoidCallback onPeriodTap;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scope = _ScopeTrail(trail: trail, names: names, onTap: onScopeTap);
    final periodButton = period == null
        ? null
        : _PeriodButton(period: period!, onTap: onPeriodTap);
    // With room to spare the period button sits at the right edge of the
    // content column, level with the trail; an invisible twin on the left
    // keeps the trail centred. Narrower, it goes back under the trail.
    final beside = periodButton != null && isWideLayout(context);
    Widget withExit(Widget child) => Row(
      children: [
        const SizedBox(width: 34),
        const SizedBox(width: kSpaceXs),
        Expanded(child: child),
        const SizedBox(width: kSpaceXs),
        _ExitStatisticsButton(onTap: onExit),
      ],
    );
    return DecoratedBox(
      key: const ValueKey('light-navigation-bar'),
      decoration: BoxDecoration(color: colors.night),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPageInsetCompact),
          child: periodButton == null
              ? withExit(Center(child: scope))
              : beside
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: withExit(
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Visibility(
                            visible: false,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: _PeriodButton(
                              period: period!,
                              onTap: onPeriodTap,
                              keyed: false,
                            ),
                          ),
                        ),
                        Expanded(child: SizedBox(height: 48, child: scope)),
                        periodButton,
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      SizedBox(height: 48, child: withExit(scope)),
                      const SizedBox(height: 22),
                      periodButton,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExitStatisticsButton extends StatelessWidget {
  const _ExitStatisticsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: context.strings.closeAction,
      child: InkWell(
        key: const ValueKey('light-exit-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: Container(
          width: 34,
          height: 34,
          decoration: selectableDecoration(colors, selected: false),
          child: Icon(Icons.close_rounded, size: 18, color: colors.text),
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.period,
    required this.onTap,
    this.keyed = true,
  });

  final LightPeriod period;
  final VoidCallback onTap;

  /// False for the invisible twin that only reserves space.
  final bool keyed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: context.strings.lightPeriodFilterLabel,
      child: InkWell(
        key: keyed ? const ValueKey('light-period-button') : null,
        onTap: onTap,
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
              Icon(Icons.calendar_month_outlined, size: 14, color: colors.gold),
              const SizedBox(width: 6),
              Text(
                _periodLabel(context, period),
                key: keyed ? const ValueKey('light-period-value') : null,
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

class _ManageActivitiesButton extends StatelessWidget {
  const _ManageActivitiesButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ElevatedButton.icon(
        key: const ValueKey('light-manage-activities'),
        onPressed: onPressed,
        icon: const Icon(Icons.checklist_rounded),
        label: AppButtonLabel(label),
      ),
    );
  }
}

/// The headline: how much light (or, for a pulsar, how many days done),
/// then the results as a wall of glowing badges — the page's first
/// impression of what has been lit.
class _LightHero extends StatelessWidget {
  const _LightHero({required this.stats});

  final LightStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final habitScope = stats.isHabitScope;
    final value = habitScope ? stats.daysDone : stats.light;
    final moments = stats.moments;
    final run = moments.longestRun;
    int media(StarMediaKind kind) => stats.victories.fold<int>(
      0,
      (sum, star) => sum + star.mediaCount(kind),
    );
    final badges = <_ResultBadge>[
      if (!habitScope && stats.victories.isNotEmpty)
        _ResultBadge(
          Icons.star_rounded,
          strings.starsCount(stats.victories.length),
        ),
      if (!habitScope && stats.activeDays.isNotEmpty)
        _ResultBadge(
          Icons.calendar_month_rounded,
          strings.lightDaysCount(stats.activeDays.length),
        ),
      if (stats.cycles.isNotEmpty)
        _ResultBadge(
          Icons.autorenew_rounded,
          strings.lightCyclesCount(stats.cycles.length),
        ),
      if (habitScope && stats.cycleLight > 0)
        _ResultBadge(
          Icons.bolt_rounded,
          strings.intensityCount(stats.cycleLight),
        ),
      if (run != null && stats.scope?.kind != InsightEntityKind.project)
        _ResultBadge(
          Icons.local_fire_department_rounded,
          strings.habitStatsDays(run.length),
        ),
      if (moments.brightestDay != null && moments.brightestDayLight > 0)
        _ResultBadge(
          Icons.wb_sunny_outlined,
          '${strings.momentBrightestDay} · '
          '${strings.intensityCount(moments.brightestDayLight)}',
        ),
      if (moments.brightestMonth != null && moments.brightestMonthLight > 0)
        _ResultBadge(
          Icons.date_range,
          '${strings.momentBrightestMonth} · '
          '${strings.intensityCount(moments.brightestMonthLight)}',
        ),
      if (stats.scope == null &&
          stats.projects.map((project) => project.area).toSet().length > 1)
        _ResultBadge(
          Icons.circle_outlined,
          strings.activeAreasCount(
            stats.projects.map((project) => project.area).toSet().length,
          ),
        ),
      if ((stats.scope == null ||
              stats.scope!.kind == InsightEntityKind.area) &&
          stats.projects.isNotEmpty)
        _ResultBadge(
          Icons.insights_outlined,
          strings.activeProjectsCount(stats.projects.length),
        ),
      if (!habitScope && media(StarMediaKind.photo) > 0)
        _ResultBadge(
          Icons.photo_library_outlined,
          '${media(StarMediaKind.photo)}',
        ),
      if (!habitScope && media(StarMediaKind.voice) > 0)
        _ResultBadge(Icons.mic_none_rounded, '${media(StarMediaKind.voice)}'),
      if (!habitScope && media(StarMediaKind.video) > 0)
        _ResultBadge(Icons.videocam_outlined, '${media(StarMediaKind.video)}'),
      if (!habitScope && media(StarMediaKind.link) > 0)
        _ResultBadge(Icons.link_rounded, '${media(StarMediaKind.link)}'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpaceLg - 4,
        horizontal: kSpaceMd,
      ),
      decoration: panelDecoration(colors),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GlowIcon(
                habitScope ? StarKind.pulsar.icon : Icons.bolt_rounded,
                size: 52,
                glow: value > 0 ? 1.4 : 0,
                color: value > 0 ? colors.gold : colors.muted,
              ),
              const SizedBox(width: kSpaceSm),
              Text(
                '$value',
                style: context.typography.immersivePageTitle.copyWith(
                  fontFamily: kFontMono,
                  fontSize: 44,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: kSpaceMd),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: kSpaceSm,
              runSpacing: kSpaceSm,
              children: [
                for (final badge in badges) _ResultBadgeChip(badge: badge),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One result on the overview: a glowing icon and its figure.
class _ResultBadge {
  const _ResultBadge(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// A badge's words in Proper Case ("12 days" becomes "12 Days"); the
/// strings behind them are plain count phrases that also read inside
/// sentences elsewhere.
String _properCase(String text) => text.splitMapJoin(
  RegExp(r'\S+'),
  onMatch: (match) {
    final word = match[0]!;
    return word[0].toUpperCase() + word.substring(1);
  },
);

class _ResultBadgeChip extends StatelessWidget {
  const _ResultBadgeChip({required this.badge});

  final _ResultBadge badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.night.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: colors.nightBorder, width: kBorderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlowIcon(badge.icon, size: 18, color: colors.gold),
          const SizedBox(width: 8),
          Text(
            _properCase(badge.text),
            style: context.typography.supporting.copyWith(
              color: colors.text,
              fontFamily: kFontMono,
              fontWeight: FontWeight.w700,
            ),
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
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: colors.gold,
                          ),
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
    required this.stats,
    required this.moments,
    required this.names,
    required this.onOpenStar,
    required this.onOpenDay,
    required this.onOpenRun,
    required this.onOpenMonth,
  });

  final LightStats stats;
  final LightMoments moments;
  final _Names names;
  final ValueChanged<Star> onOpenStar;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<LightRun> onOpenRun;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    String date(DateTime value) => formatDisplayDate(value, strings);
    final firstVictory = moments.firstVictory;
    final latestVictory = moments.latestVictory;
    final run = moments.longestRun;
    final cycle = moments.longestCycle;
    final aggregate = stats.scope == null || stats.scope!.aggregate;
    final showRun = stats.scope?.kind != InsightEntityKind.project;
    final rows = <Widget>[
      if (firstVictory != null)
        _MomentRow(
          key: const ValueKey('moment-first-victory'),
          icon: Icons.flag_rounded,
          title: strings.momentFirstVictory,
          value: firstVictory.displayTitle,
          detail: date(firstVictory.achievedDate!),
          onTap: () => onOpenStar(firstVictory),
        ),
      if (latestVictory != null && latestVictory.id != firstVictory?.id)
        _MomentRow(
          key: const ValueKey('moment-latest-victory'),
          icon: Icons.auto_awesome_rounded,
          title: strings.momentLatestVictory,
          value: latestVictory.displayTitle,
          detail: date(latestVictory.achievedDate!),
          onTap: () => onOpenStar(latestVictory),
        ),
      if (!aggregate && moments.firstDay != null)
        _MomentRow(
          key: const ValueKey('moment-first-day'),
          icon: Icons.flag_rounded,
          title: strings.momentFirstDay,
          value: date(moments.firstDay!),
          onTap: () => onOpenDay(moments.firstDay!),
        ),
      if (moments.brightestDay != null)
        _MomentRow(
          key: const ValueKey('moment-brightest-day'),
          icon: Icons.wb_sunny_outlined,
          title: strings.momentBrightestDay,
          value: date(moments.brightestDay!),
          detail: '${moments.brightestDayLight} ${strings.intensityLabel}',
          onTap: () => onOpenDay(moments.brightestDay!),
        ),
      if (run != null && showRun)
        _MomentRow(
          key: const ValueKey('moment-longest-run'),
          icon: Icons.linear_scale_rounded,
          title: strings.momentLongestRun,
          value: strings.habitStatsDays(run.length),
          detail: '${date(run.start)} – ${date(run.end)}',
          onTap: () => onOpenRun(run),
        ),
      if (moments.brightestMonth != null)
        _MomentRow(
          key: const ValueKey('moment-brightest-month'),
          icon: Icons.calendar_month_rounded,
          title: strings.momentBrightestMonth,
          value: strings.monthTitle(moments.brightestMonth!),
          detail: '${moments.brightestMonthLight} ${strings.intensityLabel}',
          onTap: () => onOpenMonth(moments.brightestMonth!),
        ),
      if (!aggregate && cycle != null)
        _MomentRow(
          key: const ValueKey('moment-longest-cycle'),
          icon: Icons.autorenew_rounded,
          title: strings.momentLongestCycle,
          value: strings.cycleHistoryItem(cycle.length),
          detail:
              '${names.habits[cycle.habitId]?.displayTitle ?? ''} · '
              '${date(cycle.completedDate)}',
          onTap: () => showHabitCycleDetail(context, cycle),
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
    super.key,
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
            GlowIcon(icon, size: 22, color: colors.gold),
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

/// The per-day maps the Light sheets read: a pulsar counts its check-ins,
/// everything else its lit stars and their intensity.
({Map<DateTime, int> counts, Map<DateTime, int> levels}) _sheetDayMaps(
  LightStats stats,
) {
  return stats.isHabitScope
      ? (counts: stats.checkInsByDay, levels: stats.checkInsByDay)
      : (counts: stats.countsByDay, levels: stats.lightByDay);
}

/// Totals for the days a Light sheet shows: days with light, lit stars,
/// intensity, and the brightest day. Intensity and the brightest day are
/// left out for a pulsar, whose days all weigh the same.
class _LightSheetSummary extends StatelessWidget {
  const _LightSheetSummary({
    super.key,
    required this.days,
    required this.counts,
    required this.levels,
    required this.showIntensity,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final Map<DateTime, int> counts;
  final Map<DateTime, int> levels;
  final bool showIntensity;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    var lit = 0;
    var stars = 0;
    var intensity = 0;
    DateTime? brightest;
    var brightestLevel = 0;
    for (final day in days) {
      final count = counts[day] ?? 0;
      if (count > 0) lit++;
      stars += count;
      final level = levels[day] ?? 0;
      intensity += level;
      if (level > brightestLevel) {
        brightestLevel = level;
        brightest = day;
      }
    }
    Widget stat(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.gold),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.typography.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    final brightestDay = brightest;

    Widget? brightestBlock;
    double titleWidth = 0;
    if (showIntensity && brightestDay != null) {
      final titleStyle = context.typography.body.copyWith(
        color: colors.text,
        fontWeight: FontWeight.w700,
      );
      final title = strings.momentBrightestDay;
      final painter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      // Icon (18) + gap (6) + the title: the width the separator matches.
      titleWidth = 24 + painter.width;
      // The two stacked badges together are as tall as the row they sit in
      // (the title's line, or its icon if that is taller), never more.
      const badgeGap = 2.0;
      final rowHeight = painter.height > 18 ? painter.height : 18.0;
      final badgeHeight = (rowHeight - badgeGap) / 2;
      final starCount = counts[brightestDay] ?? 0;
      brightestBlock = InkWell(
        onTap: () => onDayTap(brightestDay),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: kSpaceSm,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 18, color: colors.gold),
                  const SizedBox(width: 6),
                  Text(title, style: titleStyle),
                ],
              ),
              Text('–', style: titleStyle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RunDayBadge(
                    badge: makeBadge(
                      BadgeSlot.date,
                      Icons.calendar_today_rounded,
                      colors,
                      color: colors.gold,
                      value: formatDisplayDate(brightestDay, strings),
                      label: formatDisplayDate(brightestDay, strings),
                    ),
                  ),
                  const SizedBox(width: kSpaceMd),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RunDayBadge(
                        valueWidth: badgeHeight * 1.8,
                        iconSize: badgeHeight,
                        fontSize: badgeHeight / 1.1,
                        badge: intensityBadge(brightestLevel, colors, strings),
                      ),
                      const SizedBox(height: badgeGap),
                      _RunDayBadge(
                        valueWidth: badgeHeight * 1.8,
                        iconSize: badgeHeight,
                        fontSize: badgeHeight / 1.1,
                        badge: makeBadge(
                          BadgeSlot.litStars,
                          Icons.auto_awesome,
                          colors,
                          color: colors.gold,
                          value: '$starCount',
                          zero: starCount == 0,
                          label: strings.resultsStarsWord(starCount),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpaceMd),
      decoration: panelDecoration(colors),
      child: Column(
        children: [
          if (brightestBlock != null) ...[
            brightestBlock,
            const SizedBox(height: kSpaceSm),
            Container(
              width: titleWidth,
              height: 1,
              color: colors.muted.withValues(alpha: .35),
            ),
            const SizedBox(height: kSpaceSm),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: kSpaceMd,
            runSpacing: kSpaceSm,
            children: [
              stat(Icons.calendar_today_rounded, strings.habitStatsDays(lit)),
              stat(Icons.auto_awesome, strings.starsCount(stars)),
              if (showIntensity)
                stat(
                  Icons.bolt_rounded,
                  '$intensity ${strings.intensityLabel}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunDayBadge extends StatelessWidget {
  const _RunDayBadge({
    required this.badge,
    this.valueWidth,
    this.iconSize = 17.1,
    this.fontSize = 13.5,
  });

  final CardBadge badge;

  /// A fixed width for the value, so stacked badges line up their numbers.
  final double? valueWidth;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BadgeIcon(
          badge.icon,
          size: iconSize,
          color: badge.iconColor,
          endColor: badge.iconColorEnd,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: valueWidth,
          child: Text(
            badge.value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: badge.valueColor,
            ),
          ),
        ),
      ],
    );
    final label = badge.semanticLabel;
    return label == null ? content : Semantics(label: label, child: content);
  }
}

class _LightRunSheet extends StatelessWidget {
  const _LightRunSheet({
    required this.stats,
    required this.run,
    required this.onDayTap,
  });

  final LightStats stats;
  final LightRun run;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final maps = _sheetDayMaps(stats);
    final days = [
      for (var offset = 0; offset < run.length; offset++)
        addDays(run.start, offset),
    ];

    return AppSheetFrame(
      key: const ValueKey('light-run-sheet'),
      title: AppSheetTitle(strings.momentLongestRun),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          _LightSheetSummary(
            key: const ValueKey('light-run-summary'),
            days: days,
            counts: maps.counts,
            levels: maps.levels,
            showIntensity: !stats.isHabitScope,
            onDayTap: onDayTap,
          ),
          const SizedBox(height: kSpaceMd),
          _RunCalendar(
            days: days,
            counts: maps.counts,
            levels: maps.levels,
            onDayTap: onDayTap,
          ),
        ],
      ),
    );
  }
}

/// A run of days laid out like a booking calendar: seven columns, weeks
/// aligned to the weekday, the days joined by a thread. A cell shows its
/// day and how many stars it lit; its tint follows the day's intensity.
class _RunCalendar extends StatelessWidget {
  const _RunCalendar({
    required this.days,
    required this.counts,
    required this.levels,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final Map<DateTime, int> counts;
  final Map<DateTime, int> levels;
  final ValueChanged<DateTime> onDayTap;

  static const _cellHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lead = days.first.weekday - DateTime.monday;
    final rowCount = ((lead + days.length) / 7).ceil();
    Widget thread(int col, int first, int last) {
      if (first == last || col < first || col > last) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: col == first
            ? Alignment.centerRight
            : col == last
            ? Alignment.centerLeft
            : Alignment.center,
        child: FractionallySizedBox(
          widthFactor: col == first || col == last ? .5 : 1,
          child: Container(
            height: 2,
            color: colors.gold.withValues(alpha: .35),
          ),
        ),
      );
    }

    Widget cell(DateTime day) {
      final count = counts[day] ?? 0;
      final label = day.day == 1 || day == days.first
          ? '${day.day} ${strings.monthAbbreviations[day.month - 1]}'
          : '${day.day}';
      return Semantics(
        key: const ValueKey('light-run-day'),
        label:
            '${formatDisplayDate(day, strings)}, ${strings.starsCount(count)}',
        button: true,
        child: Material(
          // The sheet's own dark background, with the hairline border of the
          // panel the cells sit on.
          color: colors.night,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
          ),
          child: InkWell(
            onTap: () => onDayTap(day),
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              height: _cellHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: colors.gold),
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(colors),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in strings.weekdayAbbreviations)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < rowCount; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == rowCount - 1 ? 0 : 6),
              child: () {
                final first = row == 0 ? lead : 0;
                final last = row == rowCount - 1
                    ? (lead + days.length - 1) % 7
                    : 6;
                return SizedBox(
                  height: _cellHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(child: thread(col, first, last)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          for (var col = 0; col < 7; col++)
                            Expanded(
                              child: col < first || col > last
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: cell(days[row * 7 + col - lead]),
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }(),
            ),
        ],
      ),
    );
  }
}

class _BrightestMonthSheet extends StatefulWidget {
  const _BrightestMonthSheet({
    required this.stats,
    required this.month,
    required this.onDayTap,
  });

  final LightStats stats;
  final DateTime month;
  final ValueChanged<DateTime> onDayTap;

  @override
  State<_BrightestMonthSheet> createState() => _BrightestMonthSheetState();
}

class _BrightestMonthSheetState extends State<_BrightestMonthSheet> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);

  @override
  Widget build(BuildContext context) {
    final maps = _sheetDayMaps(widget.stats);
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final days = [
      for (var day = 1; day <= count; day++)
        DateTime(_month.year, _month.month, day),
    ];
    return AppSheetFrame(
      key: const ValueKey('brightest-month-sheet'),
      title: AppSheetTitle(context.strings.momentBrightestMonth),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              _LightSheetSummary(
                key: const ValueKey('brightest-month-summary'),
                days: days,
                counts: maps.counts,
                levels: maps.levels,
                showIntensity: !widget.stats.isHabitScope,
                onDayTap: widget.onDayTap,
              ),
              const SizedBox(height: kSpaceMd),
              HeatmapPanel(
                countsByDay: maps.counts,
                intensityByDay: maps.levels,
                initialMonth: _month,
                onMonthChanged: (value) => setState(() => _month = value),
                onDayTap: widget.onDayTap,
              ),
            ],
          ),
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
