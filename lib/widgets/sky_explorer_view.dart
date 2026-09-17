import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../screens/area_detail_screen.dart';
import '../screens/constellation_screen.dart';
import '../screens/pulsar_reader_screen.dart';
import '../screens/star_reader_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_intro_target.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/date_format.dart';
import '../utils/habit_stats.dart';
import '../utils/icon_for_slug.dart';
import 'app_field.dart';
import 'area_filter_sheet.dart';
import 'area_tag.dart';
import 'dead_star_card.dart';
import 'lit_star_card.dart';
import 'navigate_here_button.dart';
import 'pulsar_card.dart';
import 'responsive_content.dart';
import 'sky_navigation_target.dart';
import 'unlit_star_card.dart';

enum _SkyMode { supernovas, constellations, stars }

/// One flat-list row — either a [Star] (lit, unlit or dead) or a [Habit]
/// (a pulsar, or dead if it's been deleted) — wrapped with a shared
/// [sortKey] so the two can be merged into one newest-first list without
/// either side needing to know about the other's shape.
class _SkyEntry {
  _SkyEntry.fromStar(Star star)
    : star = star,
      habit = null,
      kind = star.kind,
      sortKey = star.achievedDate ?? star.createdAt;

  _SkyEntry.fromHabit(Habit habit)
    : star = null,
      habit = habit,
      // A deleted pulsar is a dead star like any other — it just remembers
      // what it was, which is what [DeadStarCard.fromHabit] shows.
      kind = habit.dead ? StarKind.dead : StarKind.pulsar,
      sortKey = habit.createdAt;

  final Star? star;
  final Habit? habit;
  final StarKind kind;
  final DateTime sortKey;

  String get title => (star?.title ?? habit!.title);
  String? get description => star?.description ?? habit?.description;
}

/// A switch between three views of the same underlying data — Supernovas
/// (the 8 fixed life areas, tap one for its own detail page), Constellations
/// (every project across whichever areas are in the area filter, tap one to
/// open its [ConstellationScreen]), and Stars (every star and pulsar across
/// those same areas, flat, newest first, further narrowed by a kind-filter
/// row). Constellations and Stars share one area filter (default: every
/// area), opened from [showAreaFilterSheet].
///
/// Nascent stars appear in none of the three: they have no record behind
/// them, only an empty slot on a shape (see [kListableStarKinds]).
///
/// The Sky's search popup (`SkySearchScreen`) is this widget's
/// only caller — every card's "take me there" button calls [onNavigateTo]
/// unconditionally, and [onModeLabelChanged] is how the popup's own AppBar
/// title tracks whichever of the three views is currently selected, since
/// that label used to be drawn inline here (freeing that vertical space was
/// the point of moving it up into the popup's title bar).
class SkyExplorerView extends StatefulWidget {
  const SkyExplorerView({
    super.key,
    required this.projectRepository,
    required this.starRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.onNavigateTo,
    required this.onModeLabelChanged,
  });

  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;

  /// See [SkyNavigationTarget] — called when a card's "take me there" button
  /// is tapped.
  final ValueChanged<SkyNavigationTarget> onNavigateTo;

  /// Called once on mount and again every time the selected level
  /// (Supernovas/Constellations/Stars) changes, with that level's own
  /// already-localized name.
  final ValueChanged<String> onModeLabelChanged;

  @override
  State<SkyExplorerView> createState() => _SkyExplorerViewState();
}

class _SkyExplorerViewState extends State<SkyExplorerView> {
  _SkyMode _mode = _SkyMode.supernovas;

  /// Whether [_syncModeToTour] has already forced Supernovas out once.
  ///
  /// Guards it from doing so a second time — see its own doc comment for
  /// why a single correction is all it should ever make.
  bool _autoSwitchedModeForTour = false;
  final _queryController = TextEditingController();
  String _query = '';
  Set<StarKind> _kindFilter = {...kListableStarKinds};
  Set<LifeArea> _areaFilter = {...LifeArea.values};

  List<Project> get _filteredAreaProjects => widget.projectRepository
      .getAll()
      .where((p) => _areaFilter.contains(p.area))
      .toList();

  Map<int, Project> get _projectsById => {
    for (final project in _filteredAreaProjects) project.id: project,
  };

  List<Star> _starsForProject(int projectId) =>
      widget.starRepository.getAllForProject(projectId);

  int _activePulsarCountForProject(int projectId) {
    var count = 0;
    for (final habit in widget.habitRepository.getActiveForProject(projectId)) {
      if (isHabitLit(habit, _countsByDayFor(habit.id))) count++;
    }
    return count;
  }

  Map<DateTime, int> _countsByDayFor(int habitId) {
    return habitCompletionCountsByDay(
      widget.habitCompletionRepository.getAllForHabit(habitId),
    );
  }

  List<Project> get _filteredProjects {
    final query = _query.trim().toLowerCase();
    final projects = _filteredAreaProjects;
    if (query.isEmpty) return projects;
    return projects.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  /// Every star and pulsar across the filtered areas' projects, of every
  /// kind, newest first — the unfiltered pool the kind-filter counts and the
  /// flat list itself are both drawn from.
  List<_SkyEntry> get _allEntries {
    final projectIds = _projectsById.keys.toSet();
    final entries = <_SkyEntry>[
      for (final star in widget.starRepository.getAll())
        if (projectIds.contains(star.projectId)) _SkyEntry.fromStar(star),
      for (final projectId in projectIds)
        for (final habit in widget.habitRepository.getAllForProject(projectId))
          _SkyEntry.fromHabit(habit),
    ];
    entries.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return entries;
  }

  List<_SkyEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    return _allEntries.where((e) {
      if (!_kindFilter.contains(e.kind)) return false;
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          (e.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  /// The [Star]-backed subset of [_filteredEntries], in the same order —
  /// what [StarReaderScreen]'s prev/next actually browses, since pulsars
  /// aren't part of that reader. Keyed on which entity is behind the row,
  /// not on its kind: a dead row can be either.
  List<Star> _filteredStarsOnly() {
    return _filteredEntries
        .where((e) => e.star != null)
        .map((e) => e.star!)
        .toList();
  }

  String _labelFor(_SkyMode mode, AppStrings strings) => switch (mode) {
    _SkyMode.supernovas => strings.skyModeSupernovas,
    _SkyMode.constellations => strings.constellationsModeLabel,
    _SkyMode.stars => strings.listModeLabel,
  };

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Deferred a frame — this fires a callback that ends up calling setState
    // on the parent (`SkySearchScreen`'s AppBar title), which isn't safe
    // to do synchronously while this widget is still mounting/building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onModeLabelChanged(_labelFor(_mode, context.strings));
      if (mounted) Tour.read(context).start('search-stars');
    });
  }

  Future<void> _openArea(LifeArea area) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailScreen(
          area: area,
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
          projectRepository: widget.projectRepository,
          starRepository: widget.starRepository,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openProject(Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConstellationScreen(
          project: project,
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openStarReader(int index) async {
    final stars = _filteredStarsOnly();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialStars: stars,
          startIndex: index,
          allowEdit: true,
          projectsById: _projectsById,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshStars: _filteredStarsOnly,
          onNavigateTo: (project, starId) =>
              widget.onNavigateTo(SkyStarTarget(project, starId: starId)),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openHabitReader(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PulsarReaderScreen(
          habit: habit,
          project: _projectsById[habit.projectId],
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openAreaFilter() async {
    final result = await showAreaFilterSheet(
      context,
      selectedAreas: _areaFilter,
      selectedKinds: _mode == _SkyMode.stars ? _kindFilter : null,
    );
    if (result == null) return;
    setState(() {
      _areaFilter = result.areas;
      final kinds = result.kinds;
      if (kinds != null) _kindFilter = kinds;
    });
  }

  /// Switches out of Supernovas on its own once the `search-stars` tour
  /// moves past its intro/toggle steps — every step after that (the search
  /// field, the filter button, and the filter sheet's own three steps past
  /// that) only exists in Stars/Constellations mode, and without this the
  /// tour's own `stepTimeout` (see `main.dart`) can elapse and silently
  /// skip the step before the user gets around to tapping the mode toggle
  /// themselves.
  ///
  /// Can't key this off [TourScope.orderAt]: it only resolves orders that
  /// have registered at least once, and the search field/filter button
  /// never have while stuck in Supernovas — the very case this exists to
  /// unstick. `index > 1` is safe instead because orders 1-2 (the intro
  /// card, then the toggle) are the only targets this tour ever mounts in
  /// Supernovas mode, and they are always step indices 0 and 1.
  ///
  /// [_autoSwitchedModeForTour] makes this a one-shot: the tour's own later
  /// steps (5-7, in the filter sheet — see `area_filter_sheet.dart`) only
  /// ever mount if the user actually opens that sheet, which nothing here
  /// forces, so a tour that reaches this point without that happening sits
  /// waiting out [stepTimeout] on each of them in turn — up to roughly half
  /// a minute — every time this screen is left and reopened before that
  /// finishes, `controller.index` is still `> 1` and `activeTour` is still
  /// `'search-stars'`, and without this guard a user who had switched back
  /// to Supernovas on their own would keep getting silently bounced back to
  /// Stars on every single visit until that timeout finally runs out in the
  /// background — confirmed live. One correction is enough to get the tour
  /// itself moving again; a second, third, nth one is just the app fighting
  /// a choice the user already made.
  void _syncModeToTour(BuildContext context) {
    final controller = Tour.of(context);
    if (_autoSwitchedModeForTour ||
        controller.activeTour != 'search-stars' ||
        controller.index <= 1 ||
        _mode != _SkyMode.supernovas) {
      return;
    }
    _autoSwitchedModeForTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mode != _SkyMode.supernovas) return;
      setState(() => _mode = _SkyMode.stars);
      widget.onModeLabelChanged(_labelFor(_mode, context.strings));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    _syncModeToTour(context);
    final allEntries = _mode == _SkyMode.stars ? _allEntries : const <_SkyEntry>[];
    final filteredEntries = _mode == _SkyMode.stars
        ? _filteredEntries
        : const <_SkyEntry>[];
    final areaFilterActive = _areaFilter.length != LifeArea.values.length;

    return Container(
      color: colors.night,
      child: Column(
        children: [
          // Only the fixed header chrome is width-capped here — the
          // Expanded list below stays full width so its own scrollbar
          // sits at the true page edge on wide viewports rather than
          // hugging a centered column (see ResponsiveContent's doc).
          TourIntroTarget(
            tour: 'search-stars',
            order: 1,
            title: strings.searchTourIntroTitle,
            description: strings.searchTourIntroBody,
          ),
          ResponsiveContent(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: HintTarget(
                    tour: 'search-stars',
                    order: 2,
                    showArrow: true,
                    spotlightPadding: const EdgeInsets.all(8),
                    contentBuilder: appTourStepCard,
                    title: strings.searchTourModeTitle,
                    description: strings.searchTourModeBody,
                    child: SegmentedButton<_SkyMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _SkyMode.supernovas,
                          icon: Icon(Icons.flare, size: 20),
                        ),
                        ButtonSegment(
                          value: _SkyMode.constellations,
                          icon: Icon(Icons.auto_awesome, size: 20),
                        ),
                        ButtonSegment(
                          value: _SkyMode.stars,
                          icon: Icon(Icons.star, size: 20),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (selection) {
                        final mode = selection.first;
                        setState(() => _mode = mode);
                        widget.onModeLabelChanged(_labelFor(mode, strings));
                      },
                    ),
                  ),
                ),
                if (_mode != _SkyMode.supernovas) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: HintTarget(
                            tour: 'search-stars',
                            order: 3,
                            showArrow: true,
                            contentBuilder: appTourStepCard,
                            title: strings.searchTourFieldTitle,
                            description: strings.searchTourFieldBody,
                            child: AppTextField(
                              controller: _queryController,
                              hintText: strings.searchHint,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              prefixIcon: Icon(
                                Icons.search,
                                color: colors.muted,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        HintTarget(
                          tour: 'search-stars',
                          order: 4,
                          showArrow: true,
                          contentBuilder: appTourStepCard,
                          title: strings.searchTourFilterButtonTitle,
                          description: strings.searchTourFilterButtonBody,
                          child: _AreaFilterButton(
                            active: areaFilterActive,
                            tooltip: strings.filterAreasAction,
                            onTap: _openAreaFilter,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (_mode) {
              // All 8 cards are meant to read as one screen, no scrolling
              // needed — LayoutBuilder + a min-height ConstrainedBox lets
              // them center within the available space on any normal
              // phone, while SingleChildScrollView is just a safety net
              // for unusually short screens or large text scales, rather
              // than the primary way this is meant to be viewed (same
              // pattern as AdmireStarsScreen's area picker).
              _SkyMode.supernovas => LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: ResponsiveContent(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < LifeArea.values.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _AreaCard(
                                  area: LifeArea.values[i],
                                  onTap: () => _openArea(LifeArea.values[i]),
                                  onNavigateTo: () => widget.onNavigateTo(
                                    SkyAreaTarget(LifeArea.values[i]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _SkyMode.constellations => _ConstellationsList(
                hasAnyProjects: _filteredAreaProjects.isNotEmpty,
                filteredProjects: _filteredProjects,
                starsForProject: _starsForProject,
                activePulsarCountForProject: _activePulsarCountForProject,
                onTap: _openProject,
                onNavigateTo: widget.onNavigateTo,
              ),
              _SkyMode.stars => _FlatList(
                hasAnyEntries: allEntries.isNotEmpty,
                entries: filteredEntries,
                projectsById: _projectsById,
                countsByDayFor: _countsByDayFor,
                onOpenStar: (entry) => _openStarReader(
                  _filteredStarsOnly().indexWhere(
                    (s) => s.id == entry.star!.id,
                  ),
                ),
                onOpenHabit: (habit) => _openHabitReader(habit),
                onNavigateTo: widget.onNavigateTo,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.onTap,
    required this.onNavigateTo,
  });

  final LifeArea area;
  final VoidCallback onTap;
  final VoidCallback onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: panelDecoration(colors),
          child: Row(
            children: [
              // Mirrors the trailing button's own width so the tag stays
              // visually centered rather than skewed toward the left edge.
              const SizedBox(width: 34),
              Expanded(
                child: Center(
                  child: AreaTag(area: area, iconSize: 20, fontSize: 16),
                ),
              ),
              NavigateHereButton(
                onTap: onNavigateTo,
                tooltip: strings.takeMeThereAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The filter trigger next to the search field on the Constellations/Stars
/// views — opens [showAreaFilterSheet]. Gold-highlighted (with a small dot)
/// whenever the current filter excludes at least one area, so it's obvious
/// at a glance that the list isn't showing everything.
class _AreaFilterButton extends StatelessWidget {
  const _AreaFilterButton({
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            width: 48,
            height: 48,
            decoration: selectableDecoration(colors, selected: active),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune,
                  size: 20,
                  color: active ? colors.gold : colors.muted,
                ),
                if (active)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.gold,
                        shape: BoxShape.circle,
                      ),
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

class _ConstellationsList extends StatelessWidget {
  const _ConstellationsList({
    required this.hasAnyProjects,
    required this.filteredProjects,
    required this.starsForProject,
    required this.activePulsarCountForProject,
    required this.onTap,
    required this.onNavigateTo,
  });

  final bool hasAnyProjects;
  final List<Project> filteredProjects;
  final List<Star> Function(int projectId) starsForProject;
  final int Function(int projectId) activePulsarCountForProject;
  final void Function(Project) onTap;
  final ValueChanged<SkyNavigationTarget> onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (!hasAnyProjects) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            strings.skyEmptyConstellations,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }
    if (filteredProjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            strings.noSearchResults,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: filteredProjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = filteredProjects[index];
        final stars = starsForProject(project.id);
        final litStars = stars.where((s) => s.isLit).toList();
        final unlitStars = stars.where((s) => s.isUnlit).length;
        final activePulsars = activePulsarCountForProject(project.id);
        return ResponsiveContent(
          child: _ProjectCard(
            project: project,
            starCount: litStars.length,
            lastStarDate: litStars.isEmpty
                ? null
                : litStars
                      .map((s) => s.achievedDate!)
                      .reduce((a, b) => a.isAfter(b) ? a : b),
            combinedIntensity: litStars.fold<int>(
              0,
              (sum, s) => sum + s.intensity!,
            ),
            unlitStars: unlitStars,
            activePulsars: activePulsars,
            onTap: () => onTap(project),
            onNavigateTo: () => onNavigateTo(SkyProjectTarget(project)),
          ),
        );
      },
    );
  }
}

/// The "Stars" flat list — lit, unlit, dead and pulsar all mixed together,
/// each rendered by the card suited to its kind.
class _FlatList extends StatelessWidget {
  const _FlatList({
    required this.hasAnyEntries,
    required this.entries,
    required this.projectsById,
    required this.countsByDayFor,
    required this.onOpenStar,
    required this.onOpenHabit,
    required this.onNavigateTo,
  });

  final bool hasAnyEntries;
  final List<_SkyEntry> entries;
  final Map<int, Project> projectsById;
  final Map<DateTime, int> Function(int habitId) countsByDayFor;
  final void Function(_SkyEntry entry) onOpenStar;
  final void Function(Habit habit) onOpenHabit;
  final ValueChanged<SkyNavigationTarget> onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (!hasAnyEntries) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            strings.skyEmptyStars,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            strings.noSearchResults,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final project =
            projectsById[entry.star?.projectId ?? entry.habit?.projectId];
        // No project resolved (stale data) means no world position to jump
        // to either — the button is simply omitted for that card. Exactly
        // one of star/habit is ever set per entry, so passing both ids
        // through unconditionally always names the right one.
        final navigateTo = project == null
            ? null
            : () => onNavigateTo(
                SkyStarTarget(
                  project,
                  starId: entry.star?.id,
                  habitId: entry.habit?.id,
                ),
              );

        final Widget card;
        switch (entry.kind) {
          case StarKind.lit:
            card = LitStarCard(
              star: entry.star!,
              project: project,
              onTap: () => onOpenStar(entry),
              onNavigateTo: navigateTo,
            );
          case StarKind.unlit:
            card = UnlitStarCard(
              star: entry.star!,
              project: project,
              onTap: () => onOpenStar(entry),
              onNavigateTo: navigateTo,
            );
          // The one kind that can come from either repository — which is
          // exactly what the card has to say, since a dead star only ever
          // comes back as what it was.
          case StarKind.dead:
            card = entry.habit != null
                ? DeadStarCard.fromHabit(
                    habit: entry.habit!,
                    project: project,
                    onTap: () => onOpenHabit(entry.habit!),
                    onNavigateTo: navigateTo,
                  )
                : DeadStarCard.fromStar(
                    star: entry.star!,
                    project: project,
                    onTap: () => onOpenStar(entry),
                    onNavigateTo: navigateTo,
                  );
          case StarKind.pulsar:
            final habit = entry.habit!;
            final countsByDay = countsByDayFor(habit.id);
            card = PulsarCard(
              habit: habit,
              project: project,
              currentStreak: habitCurrentStreak(habit, countsByDay),
              isLit: isHabitLit(habit, countsByDay),
              onTap: () => onOpenHabit(habit),
              onNavigateTo: navigateTo,
            );
          // Never listed — see [kListableStarKinds].
          case StarKind.nascent:
            return const SizedBox.shrink();
        }
        return ResponsiveContent(child: card);
      },
    );
  }
}

/// A constellation card — big icon + name up top, which supernova it
/// belongs to (results span every area in the filter, so this is no longer
/// implicit from context), a secondary detail row below, and gold-tinted
/// metric badges for lit stars, unlit stars, and active pulsars.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.starCount,
    required this.lastStarDate,
    required this.combinedIntensity,
    required this.unlitStars,
    required this.activePulsars,
    required this.onTap,
    required this.onNavigateTo,
  });

  final Project project;
  final int starCount;
  final DateTime? lastStarDate;
  final int combinedIntensity;
  final int unlitStars;
  final int activePulsars;
  final VoidCallback onTap;
  final VoidCallback onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final borderRadius = BorderRadius.circular(kRadiusCard);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: panelDecoration(colors),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            // So the trailing NavigateHereButton below can be centered
            // against the row's full height (via the Column wrapping it)
            // while the icon/text stay top-aligned next to the title line.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconForSlug(project.iconSlug),
                      color: colors.gold,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: colors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AreaTag(
                          area: project.area,
                          iconSize: 14,
                          fontSize: 13,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _StatChip(
                              icon: Icons.auto_awesome_outlined,
                              text: strings.createdOnLabel(
                                formatDisplayDate(project.createdAt, strings),
                              ),
                            ),
                            if (lastStarDate != null)
                              _StatChip(
                                icon: Icons.schedule,
                                text: strings.lastStarLabel(
                                  formatDisplayDate(lastStarDate!, strings),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MetricBadge(
                              icon: Icons.star,
                              text: strings.starsCount(starCount),
                            ),
                            _MetricBadge(
                              icon: Icons.offline_bolt,
                              text: strings.intensityCount(
                                combinedIntensity,
                              ),
                            ),
                            if (unlitStars > 0)
                              _MetricBadge(
                                icon: StarKind.unlit.icon,
                                text: strings.unlitStarsBadge(unlitStars),
                              ),
                            if (activePulsars > 0)
                              _MetricBadge(
                                icon: StarKind.pulsar.icon,
                                text: strings.activePulsarsBadge(
                                  activePulsars,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NavigateHereButton(
                        onTap: onNavigateTo,
                        tooltip: strings.takeMeThereAction,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: colors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.gold),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.accentDim),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12.5, color: colors.muted)),
      ],
    );
  }
}

