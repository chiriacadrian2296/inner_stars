import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/constellation_shape.dart';
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
import '../utils/area_hero_art.dart';
import '../utils/habit_stats.dart';
import '../utils/responsive.dart';
import 'app_field.dart';
import 'area_filter_sheet.dart';
import 'date_range_filter_sheet.dart';
import 'kind_filter_sheet.dart';
import 'responsive_content.dart';
import 'search_result_card.dart';
import 'sky_navigation_target.dart';
import 'sort_filter_sheet.dart';
import 'star_glyph.dart';

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

  /// What "sort by intensity" means for this entry — a lit star's own
  /// 1-5 rating, or 0 for anything without one (unlit/dead/pulsar), same
  /// "nothing yet" reading as an empty date range elsewhere in this file.
  int get intensityValue => star?.intensity ?? 0;
}

/// A switch between three views of the same underlying data — Supernovas
/// (the 8 fixed life areas, tap one for its own detail page), Constellations
/// (every project across whichever areas are in the area filter, tap one to
/// open its [ConstellationScreen]), and Stars (every star and pulsar across
/// those same areas, flat, further narrowed by a kind filter and ordered by
/// whatever [showSortFilterSheet] is set to (newest first by default). Every
/// mode gets the same search field, but each has its own set of filter
/// buttons beside it: none in Supernovas (search runs alone — see
/// [_filteredSupernovaAreas]), area + date + sort in Constellations, area +
/// kind + date + sort in Stars. Each filter is its own sheet/button — area
/// ([showAreaFilterSheet], default: empty, meaning no restriction — see
/// [_areaFilter]'s own doc), kind ([showKindFilterSheet], Stars only, same
/// empty-means-unrestricted default), date range ([showDateRangeFilterSheet],
/// default: no range), and sort ([showSortFilterSheet], the one exception:
/// there's no "off" state, only a default) — rather than one combined sheet,
/// so each button's own face can say exactly what it narrows or how it's
/// ordering. In Constellations a project survives the date range if any one
/// of its own stars/pulsars falls inside it (and sorts by whichever one of
/// those is most recent/intense), since a project has no date or intensity
/// of its own.
///
/// Nascent stars appear in none of the three: they have no record behind
/// them, only an empty slot on a shape (see [kListableStarKinds]).
///
/// The Sky's search popup (`SkySearchScreen`) is this widget's only caller.
/// Each result's quick menu offers the actions that are actually available:
/// opening the result, and [onNavigateTo] when its position in the Sky can be
/// resolved. [onModeLabelChanged] is how the popup's own AppBar title tracks
/// whichever of the three views is currently selected, since that label used
/// to be drawn inline here (freeing that vertical space was the point of
/// moving it up into the popup's title bar).
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
  final _cardMenuController = SearchCardMenuController();

  /// Whether [_syncModeToTour] has already forced Supernovas out once.
  ///
  /// Guards it from doing so a second time — see its own doc comment for
  /// why a single correction is all it should ever make.
  bool _autoSwitchedModeForTour = false;
  final _queryController = TextEditingController();
  String _query = '';
  // Empty means unfiltered (every area/kind shown) rather than "show
  // nothing" — opening either filter sheet with nothing pre-checked is the
  // point: picking a filter is choosing what to *add*, not what to remove
  // from an already-full selection. See [_filteredAreaProjects] and
  // [_filteredEntries] for the "empty ⟺ no restriction" read side, and
  // [_isAreaFilterNarrowed]/[_isKindFilterNarrowed] for why an explicit full
  // selection (still reachable via each sheet's own "All areas"/"All kinds"
  // toggle) counts as just as unfiltered as empty does.
  Set<StarKind> _kindFilter = {};
  Set<LifeArea> _areaFilter = {};
  DateTimeRange? _dateRangeFilter;

  /// Which chip (if any) produced [_dateRangeFilter] — kept alongside it
  /// purely so a reopened sheet can still show the right chip highlighted
  /// instead of just "Custom". (The filter button itself always shows the
  /// actual span — see [_dateRangeButtonLabel] — rather than the preset's
  /// name, precisely so seeing it doesn't require opening the sheet.) See
  /// [DateRangePreset]'s own doc for why this can't just be recomputed from
  /// the range on demand.
  DateRangePreset _dateRangePreset = DateRangePreset.allTime;

  /// Unlike the three filters above, sorting has no "off" state to default
  /// to empty — results are always in *some* order — so these two start at
  /// whatever this file's lists always used to be sorted by (newest first)
  /// rather than at a neutral placeholder.
  SortField _sortField = SortField.date;
  SortDirection _sortDirection = SortDirection.descending;

  /// Applies [_sortDirection] to a raw ascending-sense comparison — the one
  /// place that flip happens, so [_filteredProjects] and [_filteredEntries]
  /// each only have to say what "ascending" means for their own items.
  int _directed(int ascendingCompare) =>
      _sortDirection == SortDirection.ascending
      ? ascendingCompare
      : -ascendingCompare;

  List<Project> get _filteredAreaProjects => widget.projectRepository
      .getAll()
      .where((p) => _areaFilter.isEmpty || _areaFilter.contains(p.area))
      .toList();

  /// The 8 fixed areas, narrowed by [_query] against each one's own
  /// localized display name — the same free-text search Constellations and
  /// Stars already do against a title/description, just applied to a fixed
  /// list instead of a repository (there's no area filter or kind filter
  /// here — you're already looking at every area, and a kind doesn't apply
  /// to one — so search is the only thing this mode's row offers).
  List<LifeArea> _filteredSupernovaAreas(AppStrings strings) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return LifeArea.values;
    return LifeArea.values
        .where((a) => a.displayName(strings).toLowerCase().contains(query))
        .toList();
  }

  Map<int, Project> get _projectsById => {
    for (final project in _filteredAreaProjects) project.id: project,
  };

  List<Star> _starsForProject(int projectId) =>
      widget.starRepository.getAllForProject(projectId);

  Map<DateTime, int> _countsByDayFor(int habitId) {
    return habitCompletionCountsByDay(
      widget.habitCompletionRepository.getAllForHabit(habitId),
    );
  }

  /// What "sort by date" means for a project — the most recent of its own
  /// lit stars, or [Project.createdAt] itself when it has none yet (its own
  /// birth is the only date it has to offer at that point).
  DateTime _projectSortDate(Project project) {
    final litDates = _starsForProject(project.id)
        .where((s) => s.isLit)
        .map((s) => s.achievedDate!);
    return litDates.isEmpty
        ? project.createdAt
        : litDates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// What "sort by intensity" means for a project — the same combined
  /// intensity across its lit stars that [_ProjectCard] shows as a badge.
  int _projectIntensity(Project project) =>
      _starsForProject(project.id)
          .where((s) => s.isLit)
          .fold<int>(0, (sum, s) => sum + s.intensity!);

  int _compareProjects(Project a, Project b) {
    final ascending = switch (_sortField) {
      SortField.date => _projectSortDate(a).compareTo(_projectSortDate(b)),
      SortField.intensity => _projectIntensity(
        a,
      ).compareTo(_projectIntensity(b)),
      SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return _directed(ascending);
  }

  List<Project> get _filteredProjects {
    final query = _query.trim().toLowerCase();
    final range = _dateRangeFilter;
    var projects = _filteredAreaProjects;
    // A project has no date of its own to compare — it's kept only if at
    // least one of its stars/pulsars actually falls inside the range,
    // same idea as the kind filter but resolved through [_allEntries]
    // rather than a field on [Project] itself.
    if (range != null) {
      final projectIdsInRange = _allEntries
          .where((e) => _isWithinRange(e.sortKey, range))
          .map((e) => e.star?.projectId ?? e.habit?.projectId)
          .whereType<int>()
          .toSet();
      projects = projects
          .where((p) => projectIdsInRange.contains(p.id))
          .toList();
    }
    if (query.isNotEmpty) {
      projects = projects
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    projects = [...projects]..sort(_compareProjects);
    return projects;
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

  int _compareEntries(_SkyEntry a, _SkyEntry b) {
    final ascending = switch (_sortField) {
      SortField.date => a.sortKey.compareTo(b.sortKey),
      SortField.intensity => a.intensityValue.compareTo(b.intensityValue),
      SortField.name => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    };
    return _directed(ascending);
  }

  List<_SkyEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    final range = _dateRangeFilter;
    final entries = _allEntries.where((e) {
      if (_kindFilter.isNotEmpty && !_kindFilter.contains(e.kind)) {
        return false;
      }
      if (range != null && !_isWithinRange(e.sortKey, range)) return false;
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          (e.description?.toLowerCase().contains(query) ?? false);
    }).toList();
    entries.sort(_compareEntries);
    return entries;
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
    _cardMenuController.dispose();
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
    );
    if (result == null) return;
    setState(() => _areaFilter = result);
  }

  Future<void> _openKindFilter() async {
    final result = await showKindFilterSheet(
      context,
      selectedKinds: _kindFilter,
    );
    if (result == null) return;
    setState(() => _kindFilter = result);
  }

  Future<void> _openDateRangeFilter() async {
    final result = await showDateRangeFilterSheet(
      context,
      initialRange: _dateRangeFilter,
      initialPreset: _dateRangePreset,
    );
    if (result == null) return;
    setState(() {
      _dateRangeFilter = result.range;
      _dateRangePreset = result.preset;
    });
  }

  Future<void> _openSortFilter() async {
    final result = await showSortFilterSheet(
      context,
      initialField: _sortField,
      initialDirection: _sortDirection,
    );
    if (result == null) return;
    setState(() {
      _sortField = result.field;
      _sortDirection = result.direction;
    });
  }

  /// Whether the current sort differs from this file's own long-standing
  /// default (newest first) — the button only lights up gold when it does,
  /// same "neutral vs. narrowed" reading the other three filter buttons use
  /// even though, unlike them, sorting itself is never actually "off".
  bool get _isSortNonDefault =>
      _sortField != SortField.date ||
      _sortDirection != SortDirection.descending;

  /// The sort button's own label — a neutral prompt at the default, otherwise
  /// the field's name plus an arrow standing in for the direction (e.g.
  /// "Intensità ↑"), so which way it's currently sorting is visible without
  /// opening the sheet.
  String _sortButtonLabel(AppStrings strings) {
    if (!_isSortNonDefault) return strings.sortButtonDefaultLabel;
    final field = switch (_sortField) {
      SortField.date => strings.sortFieldDate,
      SortField.intensity => strings.sortFieldIntensity,
      SortField.name => strings.sortFieldName,
    };
    final arrow = _sortDirection == SortDirection.ascending ? '↑' : '↓';
    return '$field $arrow';
  }

  /// Whether [_areaFilter] has actually narrowed anything from "everything".
  /// Only a *partial* selection counts — empty (the default) and the full
  /// set (still reachable via the sheet's own "All areas" toggle) both mean
  /// "no restriction", so neither one should light the button up.
  bool get _isAreaFilterNarrowed =>
      _areaFilter.isNotEmpty && _areaFilter.length != LifeArea.values.length;

  /// Same idea as [_isAreaFilterNarrowed], for [_kindFilter].
  bool get _isKindFilterNarrowed =>
      _kindFilter.isNotEmpty && _kindFilter.length != kListableStarKinds.length;

  /// The area-filter button's own label — a neutral prompt while nothing's
  /// narrowed, otherwise how many areas are currently picked (e.g. "2
  /// areas") rather than naming which ones.
  String _areaFilterButtonLabel(AppStrings strings) => _isAreaFilterNarrowed
      ? strings.activeAreasCount(_areaFilter.length)
      : strings.areaFilterDefaultLabel;

  /// Same idea as [_areaFilterButtonLabel], for [_kindFilter] (e.g. "3 star
  /// kinds").
  String _kindFilterButtonLabel(AppStrings strings) => _isKindFilterNarrowed
      ? strings.activeKindsCount(_kindFilter.length)
      : strings.kindFilterDefaultLabel;

  /// The date-filter button's own label — the section title while no range
  /// is set, otherwise the picked span itself (e.g. "15/06 - 03/07"), even
  /// when it came from one of the quick-preset chips: naming the preset
  /// ("Last week") would mean opening the sheet just to see which days that
  /// actually means, which is exactly what showing it here avoids. The year
  /// only gets printed (e.g. "15/06/25 - 03/07/25") when at least one side
  /// of the span falls outside the current year — otherwise it's implied
  /// and just adds clutter.
  String _dateRangeButtonLabel(AppStrings strings) {
    final range = _dateRangeFilter;
    if (range == null) return strings.dateRangeFilterSectionTitle;
    final currentYear = DateTime.now().year;
    final needsYear =
        range.start.year != currentYear || range.end.year != currentYear;
    final format = needsYear ? formatShortDateWithYear : formatShortDate;
    return '${format(range.start)} - ${format(range.end)}';
  }

  /// Whether [date] falls on or between [range]'s two days — inclusive of
  /// all of [DateTimeRange.end]'s own day, since the picker only ever hands
  /// back midnight-anchored dates and a star logged at, say, 8pm on the end
  /// day should still count as "within" it.
  bool _isWithinRange(DateTime date, DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return !date.isBefore(start) && !date.isAfter(end);
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
    final allEntries = _mode == _SkyMode.stars
        ? _allEntries
        : const <_SkyEntry>[];
    final filteredEntries = _mode == _SkyMode.stars
        ? _filteredEntries
        : const <_SkyEntry>[];
    final areaFilterActive = _isAreaFilterNarrowed;
    final kindFilterActive = _isKindFilterNarrowed;
    final dateRangeFilterActive = _dateRangeFilter != null;
    final sortNonDefault = _isSortNonDefault;

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
                        _cardMenuController.closeAll();
                        setState(() => _mode = mode);
                        widget.onModeLabelChanged(_labelFor(mode, strings));
                      },
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final searchField = HintTarget(
                      tour: 'search-stars',
                      order: 3,
                      showArrow: true,
                      contentBuilder: appTourStepCard,
                      title: strings.searchTourFieldTitle,
                      description: strings.searchTourFieldBody,
                      child: AppTextField(
                        controller: _queryController,
                        hintText: strings.searchHint,
                        onChanged: (value) {
                          _cardMenuController.closeAll();
                          setState(() => _query = value);
                        },
                        prefixIcon: Icon(
                          Icons.search,
                          color: colors.muted,
                          size: 20,
                        ),
                      ),
                    );

                    // Empty in Supernovas — no filter applies to a fixed
                    // grid of all 8 areas — otherwise area (+ kind, Stars
                    // only) + date, in that order.
                    final filterButtons = <Widget>[
                      if (_mode != _SkyMode.supernovas) ...[
                        HintTarget(
                          tour: 'search-stars',
                          order: 4,
                          showArrow: true,
                          contentBuilder: appTourStepCard,
                          title: strings.searchTourFilterButtonTitle,
                          description: strings.searchTourFilterButtonBody,
                          child: _FilterButton(
                            icon: Icons.tune,
                            active: areaFilterActive,
                            label: _areaFilterButtonLabel(strings),
                            tooltip: strings.filterAreasAction,
                            onTap: _openAreaFilter,
                          ),
                        ),
                        if (_mode == _SkyMode.stars)
                          _FilterButton(
                            icon: Icons.category_outlined,
                            active: kindFilterActive,
                            label: _kindFilterButtonLabel(strings),
                            tooltip: strings.filterKindAction,
                            onTap: _openKindFilter,
                          ),
                        _FilterButton(
                          icon: Icons.calendar_month,
                          active: dateRangeFilterActive,
                          label: _dateRangeButtonLabel(strings),
                          tooltip: strings.filterDateRangeAction,
                          onTap: _openDateRangeFilter,
                        ),
                        _FilterButton(
                          icon: Icons.sort,
                          active: sortNonDefault,
                          label: _sortButtonLabel(strings),
                          tooltip: strings.sortAction,
                          onTap: _openSortFilter,
                        ),
                      ],
                    ];

                    // Wide layouts keep search and its filter buttons on
                    // one row (search always exactly half; the buttons
                    // split the other half evenly, so the field's own flex
                    // matches their combined count). On a real phone width
                    // that same row leaves each button too little space for
                    // its own label (worst case: 3 buttons in Stars, each
                    // barely a sixth of the row) — narrow layouts get the
                    // buttons their own full-width row underneath instead,
                    // splitting only among themselves.
                    if (isWideLayout(context)) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: filterButtons.isEmpty
                                  ? 1
                                  : filterButtons.length,
                              child: searchField,
                            ),
                            for (final button in filterButtons) ...[
                              const SizedBox(width: 10),
                              Expanded(child: button),
                            ],
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            10,
                            20,
                            filterButtons.isEmpty ? 12 : 6,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: searchField,
                          ),
                        ),
                        if (filterButtons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < filterButtons.length;
                                  i++
                                ) ...[
                                  // 6, not the wide layout's 10 — matching
                                  // the gap above this row (between it and
                                  // the search field), which is also 6.
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(child: filterButtons[i]),
                                ],
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _cardMenuController.closeAll();
                }
                return false;
              },
              child: switch (_mode) {
                // A plain top-flowing ListView, like Constellations/Stars
                // below — deliberately not the old LayoutBuilder +
                // full-height ConstrainedBox + Column approach, which forced
                // this branch's box to at least fill the available height and
                // then, on wide layouts, had `ResponsiveContent`'s own
                // `Center` (there to cap width) center the whole card column
                // *within* that stretched box — a Column's own
                // `mainAxisAlignment` has no say over that, since the
                // centering was happening one level up. A plain ListView
                // sizes to its own content and never fights this: all 8
                // unfiltered still read as one screen with no scrolling
                // needed on any normal phone, and a search narrowed down to
                // one or two cards now sits right under the search row
                // instead of floating mid-screen.
                _SkyMode.supernovas => Builder(
                  builder: (context) {
                    final areas = _filteredSupernovaAreas(strings);
                    if (areas.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Center(
                          child: Text(
                            strings.noSearchResultsSupernovas,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: colors.muted),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                      itemCount: areas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final area = areas[index];
                        final projects = widget.projectRepository
                            .getAll()
                            .where((project) => project.area == area)
                            .toList();
                        final starCount = projects.fold<int>(
                          0,
                          (count, project) =>
                              count +
                              widget.starRepository
                                  .getAllForProject(project.id)
                                  .length +
                              widget.habitRepository
                                  .getAllForProject(project.id)
                                  .length,
                        );
                        return ResponsiveContent(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _AreaCard(
                              area: area,
                              constellationCount: projects.length,
                              starCount: starCount,
                              menuController: _cardMenuController,
                              onTap: () => _openArea(area),
                              onNavigateTo: () =>
                                  widget.onNavigateTo(SkyAreaTarget(area)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                _SkyMode.constellations => _ConstellationsList(
                  hasAnyProjects: _filteredAreaProjects.isNotEmpty,
                  filteredProjects: _filteredProjects,
                  starsForProject: _starsForProject,
                  shapeForProject: (project) => project.starsShapeId == null
                      ? null
                      : widget.starsShapeRepository
                            .getById(project.starsShapeId!)
                            ?.shape,
                  menuController: _cardMenuController,
                  onTap: _openProject,
                  onNavigateTo: widget.onNavigateTo,
                ),
                _SkyMode.stars => _FlatList(
                  hasAnyEntries: allEntries.isNotEmpty,
                  entries: filteredEntries,
                  projectsById: _projectsById,
                  countsByDayFor: _countsByDayFor,
                  query: _query,
                  menuController: _cardMenuController,
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
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.constellationCount,
    required this.starCount,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
  });

  final LifeArea area;
  final int constellationCount;
  final int starCount;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SearchResultCard(
      menuId: 'area:${area.name}',
      menuController: menuController,
      onTap: onTap,
      visual: SearchArtworkVisual(
        asset: kAreaHeroArt[area]?.skyAsset,
        fallbackIcon: Icons.flare,
      ),
      content: SearchCardTextContent(
        title: area.displayName(strings),
        primary:
            '${strings.areaConstellationsStatLabel}: $constellationCount · '
            '${strings.areaStarsStatLabel}: $starCount',
      ),
      actions: [
        SearchCardAction(
          icon: Icons.open_in_new_rounded,
          label: strings.searchCardOpenAction,
          onTap: onTap,
        ),
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: strings.takeMeThereAction,
          onTap: onNavigateTo,
        ),
      ],
    );
  }
}

/// A filter trigger next to the search field on the Constellations/Stars
/// views — opens [showAreaFilterSheet], [showKindFilterSheet],
/// [showDateRangeFilterSheet], or [showSortFilterSheet] depending on
/// [icon]/[onTap]. [label] carries the current state right on the button's
/// own face (a neutral prompt while nothing's narrowed, a summary like "2
/// areas", the actual span "15/06 - 03/07", or "Intensity ↓" once something
/// is), so there's no need to open the sheet just to
/// see what's already set. Gold-highlighted whenever [active], same "lit vs
/// dark" rule as everywhere else that state is shown this way.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.active,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String label;
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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: selectableDecoration(colors, selected: active),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? colors.gold : colors.muted,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? colors.text : colors.muted,
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
    required this.shapeForProject,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
  });

  final bool hasAnyProjects;
  final List<Project> filteredProjects;
  final List<Star> Function(int projectId) starsForProject;
  final ConstellationShape? Function(Project project) shapeForProject;
  final SearchCardMenuController menuController;
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
            strings.noSearchResultsConstellations,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      // Horizontal margin comes from each item's own Padding below, applied
      // *inside* its ResponsiveContent instead of here — see that widget's
      // comment for why: it's what keeps a card's left edge lined up with
      // the search row above it on wide layouts.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: filteredProjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = filteredProjects[index];
        final stars = starsForProject(project.id);
        final litStars = stars.where((s) => s.isLit).toList();
        final unlitStars = stars.where((s) => s.isUnlit).length;
        return ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProjectCard(
              project: project,
              starCount: litStars.length,
              unlitStars: unlitStars,
              shape: shapeForProject(project),
              menuController: menuController,
              onTap: () => onTap(project),
              onNavigateTo: () => onNavigateTo(SkyProjectTarget(project)),
            ),
          ),
        );
      },
    );
  }
}

/// The "Stars" flat list — lit, unlit, dead and pulsar all mixed together,
/// each rendered through the shared compact Search card.
class _FlatList extends StatelessWidget {
  const _FlatList({
    required this.hasAnyEntries,
    required this.entries,
    required this.projectsById,
    required this.countsByDayFor,
    required this.query,
    required this.menuController,
    required this.onOpenStar,
    required this.onOpenHabit,
    required this.onNavigateTo,
  });

  final bool hasAnyEntries;
  final List<_SkyEntry> entries;
  final Map<int, Project> projectsById;
  final Map<DateTime, int> Function(int habitId) countsByDayFor;
  final String query;
  final SearchCardMenuController menuController;
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
            strings.noSearchResultsStars,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      // Horizontal margin comes from each item's own Padding below — see
      // the matching comment in [_ConstellationsList].
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
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

        if (entry.kind == StarKind.nascent) return const SizedBox.shrink();
        final open = entry.habit == null
            ? () => onOpenStar(entry)
            : () => onOpenHabit(entry.habit!);
        final habitCounts = entry.habit == null
            ? const <DateTime, int>{}
            : countsByDayFor(entry.habit!.id);
        final card = _SearchStarCard(
          entry: entry,
          project: project,
          query: query,
          currentStreak: entry.habit == null
              ? 0
              : habitCurrentStreak(entry.habit!, habitCounts),
          pulsarLit: entry.habit == null
              ? true
              : isHabitLit(entry.habit!, habitCounts),
          menuController: menuController,
          onTap: open,
          onNavigateTo: navigateTo,
        );
        return ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: card,
          ),
        );
      },
    );
  }
}

class _SearchStarCard extends StatelessWidget {
  const _SearchStarCard({
    required this.entry,
    required this.project,
    required this.query,
    required this.currentStreak,
    required this.pulsarLit,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
  });

  final _SkyEntry entry;
  final Project? project;
  final String query;
  final int currentStreak;
  final bool pulsarLit;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback? onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final kind = entry.kind;
    final description = entry.description;
    final normalizedQuery = query.trim().toLowerCase();
    final descriptionMatched =
        normalizedQuery.isNotEmpty &&
        (description?.toLowerCase().contains(normalizedQuery) ?? false);
    final deadDate = entry.star?.deadDate ?? entry.habit?.deadDate;
    final primary = switch (kind) {
      StarKind.lit => strings.intensityCount(entry.star!.intensity ?? 0),
      StarKind.unlit =>
        entry.star!.targetDate == null
            ? strings.noTargetDateLabel
            : '${strings.targetDateBadgeLabel} '
                  '${formatDisplayDate(entry.star!.targetDate!, strings)}',
      StarKind.pulsar => '${strings.streakBadgeLabel} $currentStreak',
      StarKind.dead =>
        deadDate == null
            ? strings.noDeadDateLabel
            : '${strings.deadDateBadgeLabel} '
                  '${formatDisplayDate(deadDate, strings)}',
      StarKind.nascent => kind.label(strings),
    };
    final eyebrow = kind == StarKind.dead && entry.habit != null
        ? '${kind.label(strings)} · ${strings.formerPulsarLabel}'
        : kind.label(strings);
    final actions = <SearchCardAction>[
      SearchCardAction(
        icon: Icons.open_in_new_rounded,
        label: strings.searchCardOpenAction,
        onTap: onTap,
      ),
      if (onNavigateTo != null)
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: strings.takeMeThereAction,
          onTap: onNavigateTo!,
        ),
    ];
    return SearchResultCard(
      menuId: entry.star == null
          ? 'habit:${entry.habit!.id}'
          : 'star:${entry.star!.id}',
      menuController: menuController,
      onTap: onTap,
      visual: SearchStarVisual(kind: kind, pulsarLit: pulsarLit),
      content: SearchCardTextContent(
        eyebrow: eyebrow,
        eyebrowColor: starKindColor(kind, context.colors, lit: pulsarLit),
        title: entry.title,
        breadcrumb: project == null
            ? null
            : '${project!.area.displayName(strings)} → ${project!.name}',
        description: descriptionMatched ? description : null,
        descriptionMatched: descriptionMatched,
        primary: primary,
      ),
      actions: actions,
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
    required this.unlitStars,
    required this.shape,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
  });

  final Project project;
  final int starCount;
  final int unlitStars;
  final ConstellationShape? shape;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SearchResultCard(
      menuId: 'project:${project.id}',
      menuController: menuController,
      onTap: onTap,
      visual: SearchConstellationVisual(shape: shape),
      content: SearchCardTextContent(
        title: project.name,
        breadcrumb: project.area.displayName(strings),
        primary:
            '${strings.starsCount(starCount)} · '
            '${strings.unlitStarsBadge(unlitStars)}',
      ),
      actions: [
        SearchCardAction(
          icon: Icons.open_in_new_rounded,
          label: strings.searchCardOpenAction,
          onTap: onTap,
        ),
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: strings.takeMeThereAction,
          onTap: onNavigateTo,
        ),
      ],
    );
  }
}
