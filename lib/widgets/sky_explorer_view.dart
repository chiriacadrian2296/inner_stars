import '../utils/area_section_icons.dart';
import '../utils/entity_insights.dart';
import 'entity_flip_card.dart';
import 'entity_insights_scope.dart';
import '../models/display_text.dart';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/constellation_layout.dart';
import '../data/constellation_shape.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/moodboard_repository.dart';
import '../data/project_repository.dart';
import '../data/reader_entries.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/sky_date_field.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../settings/settings_controller.dart';
import '../settings/sky_grid_size.dart';
import '../screens/area_detail_screen.dart';
import '../screens/constellation_screen.dart';
import '../screens/create_flow.dart';
import '../screens/moodboard_screen.dart';
import '../screens/new_project_screen.dart';
import '../screens/share_preview_screen.dart';
import '../screens/star_form_screen.dart';
import '../screens/star_reader_screen.dart';
import '../screens/vision_editor_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../tutorials/tutorial_replay.dart';
import '../utils/app_modals.dart';
import '../utils/area_hero_art.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import '../utils/habit_stats.dart';
import '../utils/icon_for_slug.dart';
import '../utils/page_settled.dart';
import '../utils/project_card_info.dart';
import '../utils/responsive.dart';
import '../utils/star_card_info.dart';
import '../utils/star_stats.dart';
import 'app_field.dart';
import 'app_footer_mark.dart';
import 'habit_cycle_scope.dart';
import 'filter_button.dart';
import 'filters_trigger_button.dart';
import 'project_picker.dart';
import 'gallery/gallery_cards.dart';
import 'area_filter_sheet.dart';
import 'date_range_filter_sheet.dart';
import 'creation_success_dialog.dart';
import 'kind_filter_sheet.dart';
import 'responsive_content.dart';
import 'search_result_card.dart';
import 'shareable_lit_star_card.dart';
import 'shareable_constellation_card.dart';
import 'shareable_goal_card.dart';
import 'shareable_pulsar_card.dart';
import 'results_count_row.dart';
import 'sky_navigation_target.dart';
import 'sky_view_mode_button.dart';
import 'sort_filter_sheet.dart';
import 'staggered_entrance.dart';
import 'star_glyph.dart';

enum _SkyMode { supernovas, constellations, stars }

enum _SkyActionStyle { pill, dock, edge, minimal }

/// Turns the shared Sky browser into the full-page view for one day opened
/// from Statistics. It deliberately keeps the normal Stars grid, controls,
/// cards and actions; only the day is a non-removable boundary.
class SkyDayContext {
  const SkyDayContext({required this.day, this.entity});

  final DateTime day;
  final InsightEntity? entity;
}

List<BoxShadow> _skyFabNavyShadow(AppColors colors) => [
  BoxShadow(
    color: colors.night.withValues(alpha: 0.9),
    blurRadius: 12,
    spreadRadius: 2,
    offset: const Offset(0, 4),
  ),
];

/// In-memory navigation state for Sky. Owned by Cosmo so opening a result,
/// flying to it, and later returning to Sky restores the exact working
/// context instead of constructing a fresh browser every time.
class SkyExplorerSession {
  int modeIndex = 0;

  /// What each tab (Areas, Constellations, Stars) keeps to itself: its search
  /// text, date range and sort. The area, constellation and kind filters
  /// below are shared across tabs.
  final tabs = List.generate(_SkyMode.values.length, (_) => SkyTabView());
  Set<StarKind> kindFilter = {...kListableStarKinds};
  Set<LifeArea> areaFilter = {...LifeArea.values};

  /// Stars only: the one constellation to show stars from (null = all).
  Set<int> projectFilterIds = {};
  final scrollOffsets = <int, double>{};
  Object? openCardMenuId;

  /// The detail page (area, constellation or star) its "take me there" was
  /// tapped on: Sky reopens it on top of the browser next time, so flying to
  /// something from its page and coming back lands on that page again.
  SkyResume? resume;
}

/// The part of the filters one tab keeps separately: see
/// [SkyExplorerSession.tabs].
class SkyTabView {
  String query = '';
  DateTimeRange? dateRange;
  DateRangePreset dateRangePreset = DateRangePreset.allTime;
  SortField sortField = SortField.date;
  SortDirection sortDirection = SortDirection.descending;

  /// Which date the range filter looks at, and which one "sort by date"
  /// uses — chosen separately, since filtering by when something happened
  /// and ordering by when it was made are different questions.
  SkyDateField rangeDateField = SkyDateField.created;
  SkyDateField sortDateField = SkyDateField.created;

  /// The cards turned face down on this tab; kept like the filters.
  final flipped = <InsightEntity>{};
}

sealed class SkyResume {
  const SkyResume();
}

class ResumeArea extends SkyResume {
  const ResumeArea(
    this.area, {
    this.scrollOffset = 0,
    this.previewOffsets = const {},
  });
  final LifeArea area;

  /// Where each section preview on the page was scrolled to.
  final Map<int, double> previewOffsets;

  /// Where the area page was scrolled to when it was left.
  final double scrollOffset;
}

class ResumeProject extends SkyResume {
  const ResumeProject(this.projectId, {this.transform});
  final int projectId;

  /// The constellation map's zoom/pan when it was left.
  final Matrix4? transform;
}

class ResumeStar extends SkyResume {
  const ResumeStar(this.anchorKey);
  final String anchorKey;
}

/// One flat-list row — either a [Star] (lit, unlit or dead) or a [Habit]
/// (a pulsar, or dead if it's been deleted) — wrapped with a shared
/// [dateFor] so the two can be merged into one list without either side
/// needing to know about the other's shape.
class _SkyEntry {
  _SkyEntry.fromStar(Star star) : star = star, habit = null, kind = star.kind;

  _SkyEntry.fromHabit(Habit habit)
    : star = null,
      habit = habit,
      // A deleted pulsar is a dead star like any other — it just remembers
      // what it was, which is what [DeadStarCard.fromHabit] shows.
      kind = habit.dead ? StarKind.dead : StarKind.pulsar;

  final Star? star;
  final Habit? habit;
  final StarKind kind;

  DateTime get createdAt => star?.createdAt ?? habit!.createdAt;

  /// The entry's date for [field], or null when it has none: a victory's
  /// achieved date and a goal's target date are the only "occurred" dates —
  /// habits and archived entries have no such date.
  DateTime? dateFor(SkyDateField field) {
    final star = this.star;
    return switch (field) {
      SkyDateField.created => createdAt,
      SkyDateField.modified => star?.lastModified ?? habit!.lastModified,
      SkyDateField.occurred => switch (kind) {
        StarKind.lit => star?.achievedDate,
        StarKind.unlit => star?.targetDate,
        _ => null,
      },
    };
  }

  String get title => (star?.displayTitle ?? habit!.displayTitle);
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
/// mode gets the same search field, but each has its own set of filters
/// beside it: none in Supernovas (search runs alone — see
/// [_filteredSupernovaAreas]), area + date + sort in Constellations, area +
/// kind + date + sort in Stars. On a wide layout each filter is its own
/// button/sheet beside the search field; on a narrow one they're all
/// collected behind a single trigger instead (see [FiltersTriggerButton]/
/// [_ControlsSheet]) so a phone doesn't carry a second permanent row under
/// the search field on every visit. Either way, each filter is its own
/// sheet — area
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
/// resolved.
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
    required this.settings,
    this.session,
    this.dayContext,
    required this.onNavigateTo,
  });

  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;

  /// Holds the list/grid choice and the grid's card size — listened to, so
  /// changing either from the view-mode sheet shows up here live.
  final SettingsController settings;
  final SkyExplorerSession? session;
  final SkyDayContext? dayContext;

  /// See [SkyNavigationTarget] — called when a card's "take me there" button
  /// is tapped.
  final ValueChanged<SkyNavigationTarget> onNavigateTo;

  @override
  State<SkyExplorerView> createState() => _SkyExplorerViewState();
}

class _SkyExplorerViewState extends State<SkyExplorerView>
    with SingleTickerProviderStateMixin {
  EntityInsightsController? _insightsController;

  Widget _flipTile(InsightEntity entity, Widget front) => EntityFlipCard(
    key: ValueKey(entity),
    entity: entity,
    front: front,
    flipped: _tab.flipped.contains(entity),
    onFlip: () {
      setState(() {
        if (!_tab.flipped.remove(entity)) _tab.flipped.add(entity);
      });
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = EntityInsightsScope.maybeOf(context);
    if (controller != _insightsController) {
      _insightsController?.removeListener(_refreshAndRebuild);
      _insightsController = controller;
      controller?.addListener(_refreshAndRebuild);
    }
  }

  late _SkyMode _mode;
  bool _modeReverse = false;
  late SkyDayContext? _dayContext;
  late final _modeAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );

  void _selectMode(_SkyMode mode) {
    if (mode == _mode) return;
    _cardMenuController.closeAll();
    setState(() {
      _modeReverse = mode.index < _mode.index;
      _mode = mode;
      _showBackToTop = false;
      _backToTopAvoidsFooter = false;
    });
    // The search box shows this tab's own text.
    _queryController.text = _query;
    _saveSession();
    _modeAnimation.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBackToTop(mode.index);
    });
  }

  /// Moves only one step in the same sequence as the segmented switch:
  /// Areas ↔ Constellations ↔ Stars.
  void _swipeMode(double horizontalVelocity) {
    const minimumVelocity = 180.0;
    if (horizontalVelocity.abs() < minimumVelocity) return;
    if (_dayContext != null) {
      _shiftDay(horizontalVelocity.isNegative ? 1 : -1);
      return;
    }
    final direction = horizontalVelocity.isNegative ? 1 : -1;
    final rawIndex = _mode.index + direction;
    if (rawIndex < 0 || rawIndex >= _SkyMode.values.length) return;
    final nextIndex = rawIndex;
    _selectMode(_SkyMode.values[nextIndex]);
  }

  void _shiftDay(int offset) {
    final current = _dayContext;
    if (current == null || offset == 0) return;
    _cardMenuController.closeAll();
    setState(() {
      _modeReverse = offset.isNegative;
      _dayContext = SkyDayContext(
        day: addDays(current.day, offset),
        entity: current.entity,
      );
      _tab.flipped.clear();
      _showBackToTop = false;
      _backToTopAvoidsFooter = false;
    });
    final controller = _scrollControllers[_SkyMode.stars.index];
    if (controller.hasClients) controller.jumpTo(0);
    _session.scrollOffsets[_SkyMode.stars.index] = 0;
    _modeAnimation.forward(from: 0);
  }

  late final SearchCardMenuController _cardMenuController;
  late final List<ScrollController> _scrollControllers;
  late final SkyExplorerSession _session;
  bool _showBackToTop = false;
  bool _backToTopAvoidsFooter = false;

  static const _backToTopRevealOffset = 240.0;
  static const _backToTopFooterDistance = 48.0;

  /// Whether [_syncModeToTour] has already forced Supernovas out once.
  ///
  /// Guards it from doing so a second time — see its own doc comment for
  /// why a single correction is all it should ever make.
  bool _autoSwitchedModeForTour = false;
  late final TextEditingController _queryController;
  // Filters model exactly what their sheets show: everything starts on,
  // and an empty set really means that nothing matches.
  late Set<StarKind> _kindFilter;
  late Set<LifeArea> _areaFilter;
  Set<int> _projectFilterIds = {};

  /// Which chip (if any) produced [_dateRangeFilter] — kept alongside it
  /// purely so a reopened sheet can still show the right chip highlighted
  /// instead of just "Custom". (The filter button itself always shows the
  /// actual span — see [_dateRangeButtonLabel] — rather than the preset's
  /// name, precisely so seeing it doesn't require opening the sheet.) See
  /// [DateRangePreset]'s own doc for why this can't just be recomputed from
  /// the range on demand.
  /// Unlike the three filters above, sorting has no "off" state to default
  /// to empty — results are always in *some* order — so these two start at
  /// whatever this file's lists always used to be sorted by (newest first)
  /// rather than at a neutral placeholder.

  /// The current tab's own search text, date range and sort. The tabs share
  /// the area, constellation and kind filters but not these: sorting stars by
  /// date and constellations by name, or searching one tab, doesn't touch
  /// the others.
  SkyTabView get _tab => _session.tabs[_mode.index];
  String get _query => _tab.query;
  set _query(String value) => _tab.query = value;
  DateTimeRange? get _dateRangeFilter => _tab.dateRange;
  set _dateRangeFilter(DateTimeRange? value) => _tab.dateRange = value;
  DateRangePreset get _dateRangePreset => _tab.dateRangePreset;
  set _dateRangePreset(DateRangePreset value) => _tab.dateRangePreset = value;
  SortField get _sortField => _tab.sortField;
  set _sortField(SortField value) => _tab.sortField = value;
  SortDirection get _sortDirection => _tab.sortDirection;
  set _sortDirection(SortDirection value) => _tab.sortDirection = value;

  /// The dates the current tab can filter/sort by: creation and
  /// modification always, "occurred" only when something visible has one
  /// (any constellation; a victory or goal among the Stars kinds).
  List<SkyDateField> _availableDateFields({Set<StarKind>? kinds}) {
    final hasOccurred =
        _mode == _SkyMode.constellations ||
        (kinds ?? _kindFilter).any(
          (k) => k == StarKind.lit || k == StarKind.unlit,
        );
    return [
      SkyDateField.created,
      SkyDateField.modified,
      if (hasOccurred) SkyDateField.occurred,
    ];
  }

  /// [field] if this tab can use it right now, otherwise creation — keeps a
  /// stored "occurred" choice harmless after the kind filter drops every
  /// kind that has one.
  SkyDateField _usableDateField(SkyDateField field, {Set<StarKind>? kinds}) =>
      _availableDateFields(kinds: kinds).contains(field)
      ? field
      : SkyDateField.created;

  SkyDateField get _rangeDateField => _usableDateField(_tab.rangeDateField);
  SkyDateField get _sortDateField => _usableDateField(_tab.sortDateField);
  late List<Project> _projectsCache;
  late List<Star> _starsCache;
  late List<Habit> _habitsCache;
  late Map<int, List<Star>> _starsByProjectCache;
  late Map<int, Map<DateTime, int>> _completionCountsCache;

  late Map<int, List<HabitCompletion>> _completionsByHabitCache;
  late Map<int, ConstellationShape> _shapesByIdCache;

  void _refreshDataCache() {
    _allEntriesMemo.clear();
    _projectsCache = widget.projectRepository.getAll();
    // A constellation deleted since the filter was set can't match anything.
    _projectFilterIds.removeWhere(
      (id) => !_projectsCache.any((p) => p.id == id),
    );
    _starsCache = widget.starRepository.getAll();
    _habitsCache = widget.habitRepository.getAll();
    _shapesByIdCache = {
      for (final shape in widget.starsShapeRepository.getAll())
        shape.id: shape.shape,
    };
    _starsByProjectCache = <int, List<Star>>{};
    for (final star in _starsCache) {
      (_starsByProjectCache[star.projectId] ??= <Star>[]).add(star);
    }
    for (final stars in _starsByProjectCache.values) {
      stars.sort((a, b) => a.slotSequence.compareTo(b.slotSequence));
    }
    final completions = widget.habitCompletionRepository.getAll();
    _completionsByHabitCache = <int, List<HabitCompletion>>{};
    for (final completion in completions) {
      (_completionsByHabitCache[completion.habitId] ??= []).add(completion);
    }
    _completionCountsCache = {
      for (final habit in _habitsCache)
        habit.id: habitCompletionCountsByDay(
          completions.where((entry) => entry.habitId == habit.id).toList(),
        ),
    };
  }

  void _refreshAndRebuild() {
    _refreshDataCache();
    if (mounted) setState(() {});
  }

  void _saveSession() {
    final session = _session;
    session
      ..modeIndex = _mode.index
      ..kindFilter = {..._kindFilter}
      ..areaFilter = {..._areaFilter}
      ..projectFilterIds = {..._projectFilterIds}
      ..openCardMenuId = _cardMenuController.openId;
    for (var i = 0; i < _scrollControllers.length; i++) {
      final controller = _scrollControllers[i];
      if (controller.hasClients) session.scrollOffsets[i] = controller.offset;
    }
  }

  /// Applies [_sortDirection] to a raw ascending-sense comparison — the one
  /// place that flip happens, so [_filteredProjects] and [_filteredEntries]
  /// each only have to say what "ascending" means for their own items.
  int _directed(int ascendingCompare) =>
      _sortDirection == SortDirection.ascending
      ? ascendingCompare
      : -ascendingCompare;

  List<Project> _areaProjectsFor(Set<LifeArea> areas) =>
      _projectsCache.where((p) => areas.contains(p.area)).toList();

  List<Project> get _filteredAreaProjects => _areaProjectsFor(_areaFilter);

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
      _starsByProjectCache[projectId] ?? const <Star>[];

  Map<DateTime, int> _countsByDayFor(int habitId) {
    return _completionCountsCache[habitId] ?? const <DateTime, int>{};
  }

  /// A project's date for [field]. "Occurred" is the most recent of its own
  /// lit stars, and null when it has none yet.
  DateTime? _projectDate(Project project, SkyDateField field) {
    switch (field) {
      case SkyDateField.created:
        return project.createdAt;
      case SkyDateField.modified:
        return project.lastModified;
      case SkyDateField.occurred:
        final litDates = _starsForProject(project.id)
            .where((s) => s.isLit)
            .map((s) => s.achievedDate!);
        return litDates.isEmpty
            ? null
            : litDates.reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  /// Orders two possibly-missing dates by [_sortDirection], always putting
  /// the missing ones last whichever way the list runs.
  int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return _directed(a.compareTo(b));
  }

  /// What "sort by intensity" means for a project — the same combined
  /// intensity across its lit stars that [_ProjectCard] shows as a badge.
  int _projectIntensity(Project project) {
    final habitIds = {
      for (final h in _habitsCache)
        if (h.projectId == project.id) h.id,
    };
    final cycles = HabitCycleScope.maybeOf(context)?.getAll() ?? const [];
    return _starsForProject(project.id)
            .where((s) => s.isLit)
            .fold<int>(0, (sum, s) => sum + s.intensity!) +
        cycleIntensityTotal(cycles, habitIds: habitIds);
  }

  int _compareProjects(Project a, Project b) {
    if (_sortField == SortField.date) {
      final field = _sortDateField;
      return _compareDates(_projectDate(a, field), _projectDate(b, field));
    }
    final ascending = switch (_sortField) {
      SortField.date => 0,
      SortField.intensity => _projectIntensity(
        a,
      ).compareTo(_projectIntensity(b)),
      SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return _directed(ascending);
  }

  List<Project> get _filteredProjects =>
      _projectsMatching()..sort(_compareProjects);

  /// The constellations the filters leave, unsorted. [areas] and [dateRange]
  /// stand in for the live filters, so a filter sheet can ask what a
  /// not-yet-applied choice would show ([dateRange] is a record because null
  /// is a valid range).
  List<Project> _projectsMatching({
    Set<LifeArea>? areas,
    ({DateTimeRange? range, SkyDateField field})? dateRange,
  }) {
    final query = _query.trim().toLowerCase();
    final range = dateRange != null ? dateRange.range : _dateRangeFilter;
    final field = dateRange != null ? dateRange.field : _rangeDateField;
    var projects = _areaProjectsFor(areas ?? _areaFilter);
    if (range != null) {
      projects = projects.where((p) {
        final date = _projectDate(p, field);
        return date != null && _isWithinRange(date, range);
      }).toList();
    }
    if (query.isNotEmpty) {
      projects = projects
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    return projects;
  }

  /// Every star and pulsar across the filtered areas' projects, of every
  /// kind, newest first — the unfiltered pool the kind-filter counts and the
  /// flat list itself are both drawn from.
  List<_SkyEntry> get _allEntries => _allEntriesFor(_areaFilter);

  // Building and sorting every entry of the sky is the expensive part of
  // typing in the search box, which asks for it several times per keystroke
  // (list, count, filter previews) while neither the data nor the areas
  // change. Callers must treat the result as read-only.
  final Map<Set<LifeArea>, List<_SkyEntry>> _allEntriesMemo = {};

  List<_SkyEntry> _allEntriesFor(Set<LifeArea> areas) {
    for (final cached in _allEntriesMemo.entries) {
      if (setEquals(cached.key, areas)) return cached.value;
    }
    final projectIds = _areaProjectsFor(areas).map((p) => p.id).toSet();
    final entries = <_SkyEntry>[
      for (final star in _starsCache)
        if (projectIds.contains(star.projectId)) _SkyEntry.fromStar(star),
      for (final habit in _habitsCache)
        if (projectIds.contains(habit.projectId)) _SkyEntry.fromHabit(habit),
    ];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // The key is copied: the live filter set is mutated in place elsewhere.
    _allEntriesMemo[{...areas}] = entries;
    return entries;
  }

  int _compareEntries(_SkyEntry a, _SkyEntry b) {
    if (_sortField == SortField.date) {
      final field = _sortDateField;
      return _compareDates(a.dateFor(field), b.dateFor(field));
    }
    final ascending = switch (_sortField) {
      SortField.date => 0,
      SortField.intensity => a.intensityValue.compareTo(b.intensityValue),
      SortField.name => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    };
    return _directed(ascending);
  }

  List<_SkyEntry> get _filteredEntries =>
      _entriesMatching()..sort(_compareEntries);

  /// The stars the filters leave, unsorted; [areas], [kinds] and [dateRange]
  /// stand in for the live filters (see [_projectsMatching]).
  List<_SkyEntry> _entriesMatching({
    Set<LifeArea>? areas,
    Set<StarKind>? kinds,
    ({DateTimeRange? range, SkyDateField field})? dateRange,
    Set<int>? projects,
  }) {
    final query = _query.trim().toLowerCase();
    final range = dateRange != null ? dateRange.range : _dateRangeFilter;
    final kindFilter = kinds ?? _kindFilter;
    final field = _usableDateField(
      dateRange != null ? dateRange.field : _tab.rangeDateField,
      kinds: kindFilter,
    );
    final projectFilter = projects ?? _projectFilterIds;
    return _allEntriesFor(areas ?? _areaFilter).where((e) {
      if (!_matchesDayContext(e)) return false;
      if (!kindFilter.contains(e.kind)) {
        return false;
      }
      if (projectFilter.isNotEmpty &&
          !projectFilter.contains(e.star?.projectId ?? e.habit!.projectId)) {
        return false;
      }
      if (range != null) {
        final date = e.dateFor(field);
        if (date == null || !_isWithinRange(date, range)) return false;
      }
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          (e.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  bool _matchesDayContext(_SkyEntry entry) {
    final dayContext = _dayContext;
    if (dayContext == null) return true;
    final day = dateOnly(dayContext.day);
    final occursOnDay = entry.star != null
        ? entry.star!.isLit && dateOnly(entry.star!.achievedDate!) == day
        : (_completionsByHabitCache[entry.habit!.id] ?? const []).any(
            (completion) => dateOnly(completion.date) == day,
          );
    if (!occursOnDay) return false;

    final entity = dayContext.entity;
    if (entity == null) return true;
    final projectId = entry.star?.projectId ?? entry.habit!.projectId;
    return switch (entity.kind) {
      InsightEntityKind.area => _projectsCache.any(
        (project) => project.id == projectId && project.area == entity.area,
      ),
      InsightEntityKind.project => projectId == entity.id,
      InsightEntityKind.star => entry.star?.id == entity.id,
      InsightEntityKind.habit => entry.habit?.id == entity.id,
    };
  }

  IconData get _modeIcon => switch (_mode) {
    _SkyMode.supernovas => Icons.flare,
    _SkyMode.constellations => Icons.insights,
    _SkyMode.stars => Icons.auto_awesome,
  };

  /// The current mode's level word for [count] cards (area, constellation or
  /// star, singular or plural).
  String _resultsWord(int count) {
    final strings = context.strings;
    return switch (_mode) {
      _SkyMode.supernovas => strings.resultsAreasWord(count),
      _SkyMode.constellations => strings.resultsConstellationsWord(count),
      _SkyMode.stars => strings.resultsStarsWord(count),
    };
  }

  /// How many cards the current mode shows right now.
  /// How many of the cards this tab shows are turned face down.
  int _flippedCount(AppStrings strings) => switch (_mode) {
    _SkyMode.supernovas => _filteredSupernovaAreas(
      strings,
    ).where((a) => _tab.flipped.contains(InsightEntity.area(a))).length,
    _SkyMode.constellations =>
      _projectsMatching()
          .where((p) => _tab.flipped.contains(InsightEntity.project(p.id)))
          .length,
    _SkyMode.stars =>
      _entriesMatching()
          .where(
            (e) => _tab.flipped.contains(
              e.star != null
                  ? InsightEntity.star(e.star!.id)
                  : InsightEntity.habit(e.habit!.id),
            ),
          )
          .length,
  };

  int _resultCount(AppStrings strings) => switch (_mode) {
    _SkyMode.supernovas => _filteredSupernovaAreas(strings).length,
    _SkyMode.constellations => _projectsMatching().length,
    _SkyMode.stars => _entriesMatching().length,
  };

  /// How many cards the current mode would show with the given pending filter
  /// choices swapped in — what a filter sheet previews above its buttons.
  int _previewCount({
    Set<LifeArea>? areas,
    Set<StarKind>? kinds,
    ({DateTimeRange? range, SkyDateField field})? dateRange,
    Set<int>? projects,
  }) => _mode == _SkyMode.stars
      ? _entriesMatching(
          areas: areas,
          kinds: kinds,
          dateRange: dateRange,
          projects: projects,
        ).length
      : _projectsMatching(areas: areas, dateRange: dateRange).length;

  /// [_filteredEntries] as the star reader's pages, in the same order —
  /// stars and pulsars alike, so prev/next walks exactly what the list shows.
  /// Keyed on which entity is behind the row, not on its kind: a dead row
  /// can be either.
  List<ReaderEntry> _filteredReaderEntries() {
    return [
      for (final e in _filteredEntries)
        if (e.star != null) StarEntry(e.star!) else PulsarEntry(e.habit!),
    ];
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _saveSession();
    _modeAnimation.dispose();
    _queryController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    _insightsController?.removeListener(_refreshAndRebuild);
    _cardMenuController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _dayContext = widget.dayContext;
    final session = _session = widget.session ?? SkyExplorerSession();
    final modeIndex = session.modeIndex < 0
        ? 0
        : session.modeIndex >= _SkyMode.values.length
        ? _SkyMode.values.length - 1
        : session.modeIndex;
    _mode = _dayContext == null ? _SkyMode.values[modeIndex] : _SkyMode.stars;
    _queryController = TextEditingController(text: _query);
    _kindFilter = {...session.kindFilter};
    _areaFilter = {...session.areaFilter};
    _projectFilterIds = {...session.projectFilterIds};
    _refreshDataCache();
    _cardMenuController = SearchCardMenuController(
      initialOpenId: session.openCardMenuId,
    )..addListener(() => session.openCardMenuId = _cardMenuController.openId);
    _scrollControllers = List.generate(_SkyMode.values.length, (index) {
      final controller = ScrollController(
        initialScrollOffset: session.scrollOffsets[index] ?? 0,
      );
      controller.addListener(() {
        session.scrollOffsets[index] = controller.offset;
        _updateBackToTop(index);
      });
      return controller;
    });
    final resume = session.resume;
    session.resume = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateBackToTop(_mode.index);
      if (resume != null) {
        _resume(resume);
        return;
      }
      whenPageSettled(context, () {
        startTourAuto(Tour.read(context), 'search-stars');
      });
    });
  }

  /// Reopens the detail page a previous visit flew away from (see
  /// [SkyExplorerSession.resume]).
  void _resume(SkyResume resume) {
    switch (resume) {
      case ResumeArea(:final area, :final scrollOffset, :final previewOffsets):
        _openArea(
          area,
          scrollOffset: scrollOffset,
          previewOffsets: previewOffsets,
        );
      case ResumeProject(:final projectId, :final transform):
        final project = _projectsCache
            .where((p) => p.id == projectId)
            .firstOrNull;
        if (project != null) _openProject(project, transform: transform);
      case ResumeStar(:final anchorKey):
        _openStarReader(anchorKey);
    }
  }

  /// Whether the grid is showing — always, while the list view is parked
  /// ([kShowSkyListView]); otherwise whatever the person picked.
  bool get _gridView => !kShowSkyListView || widget.settings.skyGridView;

  /// The list/grid choice or the grid's card size changed (from the view-mode
  /// sheet): rebuild with the new view, closing any quick menu that belonged
  /// to the old one.
  void _onSettingsChanged() {
    _cardMenuController.closeAll();
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBackToTop(_mode.index);
    });
  }

  void _updateBackToTop(int modeIndex) {
    if (!mounted || modeIndex != _mode.index) return;
    final controller = _scrollControllers[modeIndex];
    if (!controller.hasClients) return;
    final position = controller.position;
    final show = position.pixels >= _backToTopRevealOffset;
    final avoidsFooter =
        _gridView && position.extentAfter <= _backToTopFooterDistance;
    if (show == _showBackToTop && avoidsFooter == _backToTopAvoidsFooter) {
      return;
    }
    setState(() {
      _showBackToTop = show;
      _backToTopAvoidsFooter = avoidsFooter;
    });
  }

  void _scrollToTop() {
    final controller = _scrollControllers[_mode.index];
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  // -- Grid view ------------------------------------------------------------

  GalleryAreaData _areaGridData(LifeArea area) {
    final projects = _projectsCache.where((p) => p.area == area).toList();
    final starCount = projects.fold<int>(
      0,
      (count, project) =>
          count +
          _starsForProject(project.id).length +
          _habitsCache.where((h) => h.projectId == project.id).length,
    );
    return GalleryAreaData(
      area: area,
      constellationCount: projects.length,
      starCount: starCount,
      badges: _areaBadges(area),
    );
  }

  CardBadges _areaBadges(LifeArea area) {
    final projects = _projectsCache.where((p) => p.area == area).toList();
    return areaCardBadges(
      constellationCount: projects.length,
      stars: [for (final project in projects) ..._starsForProject(project.id)],
      habits: [
        for (final project in projects)
          ..._habitsCache.where((h) => h.projectId == project.id),
      ],
      cycles: HabitCycleScope.maybeOf(context)?.getAll() ?? const [],
      emptySlots: projects.fold<int>(
        0,
        (sum, project) =>
            sum +
            emptySlotsOf(
              _shapesByIdCache[project.starsShapeId]?.points.length ?? 0,
              _starsForProject(project.id),
            ),
      ),
      colors: context.colors,
      strings: context.strings,
    );
  }

  CardBadges _projectBadges(Project project) => projectCardBadges(
    stars: _starsForProject(project.id),
    habits: _habitsCache.where((h) => h.projectId == project.id).toList(),
    cycles: HabitCycleScope.maybeOf(context)?.getAll() ?? const [],
    slotCount: _shapesByIdCache[project.starsShapeId]?.points.length ?? 0,
    colors: context.colors,
    strings: context.strings,
  );

  CardBadges _entryBadges(_SkyEntry entry) {
    final habit = entry.habit;
    return habit == null
        ? starCardBadges(entry.star!, context.colors, context.strings)
        : habitCardBadges(
            habit,
            _countsByDayFor(habit.id),
            context.colors,
            context.strings,
          );
  }

  GalleryProjectData _projectGridData(Project project) {
    final stars = _starsForProject(project.id);
    final shape = _shapesByIdCache[project.starsShapeId];
    // The same builder Cosmo and the constellation page use, so the preview
    // holds the same stars: grown layout, nascent slots, overflow, pulsars.
    final built = buildConstellationRenderStars(
      stars: stars,
      habits: _habitsCache.where((h) => h.projectId == project.id).toList(),
      shape: shape,
      completionsByHabit: _completionsByHabitCache,
    );
    return GalleryProjectData(
      project: project,
      renderStars: built.stars,
      edges: built.edges,
      totalStars: shape?.points.length ?? stars.length,
      litStars: stars.where((s) => s.isLit).length,
      badges: _projectBadges(project),
    );
  }

  GalleryStarData _starGridData(_SkyEntry entry) {
    final habit = entry.habit;
    if (habit == null) {
      return GalleryStarData.fromStar(
        entry.star!,
        _projectsById[entry.star!.projectId],
        badges: _entryBadges(entry),
      );
    }
    final counts = _countsByDayFor(habit.id);
    return GalleryStarData.fromHabit(
      habit,
      _projectsById[habit.projectId],
      badges: _entryBadges(entry),
      pulsarLit: isHabitLit(habit, counts),
    );
  }

  /// Every level's grid body: [items] as miniature pages, as big as the
  /// grid card size setting allows. Tapping one calls [onTap] with its index.
  Widget _gridBody<T>({
    required ScrollController controller,
    required List<T> items,
    required String emptyText,
    required Widget Function(T item, VoidCallback onTap) tile,
    required void Function(int index) onTap,
    bool footer = false,
  }) {
    final colors = context.colors;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            axis: _dayContext == null ? Axis.vertical : Axis.horizontal,
            replayKey: _dayContext?.day,
            reverse: _modeReverse,
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }
    // Capped to the shared content column on wide layouts, like the lists —
    // by padding, not by wrapping: the scroll view itself spans the window.
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = responsiveSideInset(context, constraints.maxWidth);
        return CustomScrollView(
          // The three tabs build this same widget in the same place, so
          // without a key of its own per tab Flutter reuses one scroll view
          // and hands its position from controller to controller: scrolling
          // one tab scrolled them all. Its own key gives each tab its own
          // scroll view, and the storage key remembers where it was left.
          key: PageStorageKey<String>(
            'sky-grid-${_scrollControllers.indexOf(controller)}',
          ),
          controller: controller,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20 + inset, 4, 20 + inset, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: skyGridColumnsFor(
                    widget.settings.skyGridSizeStep,
                    constraints.maxWidth - 2 * inset - 40,
                  ),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: kGalleryTileAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => StaggeredEntrance(
                    index: index % 12,
                    axis: _dayContext == null ? Axis.vertical : Axis.horizontal,
                    replayKey: _dayContext?.day,
                    reverse: _modeReverse,
                    child: tile(items[index], () => onTap(index)),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            // With few tiles the mark sits at the bottom of the page; with
            // many it follows them and shows only once scrolled all the way
            // down — either way it leaves the room under the last tiles.
            SliverFillRemaining(
              hasScrollBody: false,
              child: footer
                  ? const Align(
                      alignment: Alignment.bottomCenter,
                      child: AppFooterMark(),
                    )
                  : const SizedBox(height: 24),
            ),
          ],
        );
      },
    );
  }

  Widget _areasGrid(AppStrings strings) {
    final areas = [
      for (final area in _filteredSupernovaAreas(strings)) _areaGridData(area),
    ];
    return _gridBody<GalleryAreaData>(
      controller: _scrollControllers[0],
      items: areas,
      emptyText: strings.noSearchResultsSupernovas,
      tile: (item, onTap) => _flipTile(
        InsightEntity.area(item.area),
        GalleryAreaTile(data: item, onTap: onTap),
      ),
      onTap: (index) => _openArea(areas[index].area),
      footer: true,
    );
  }

  Widget _constellationsGrid(AppStrings strings) {
    final projects = [
      for (final project in _filteredProjects) _projectGridData(project),
    ];
    return _gridBody<GalleryProjectData>(
      controller: _scrollControllers[1],
      items: projects,
      emptyText: strings.noSearchResultsConstellations,
      tile: (item, onTap) => _flipTile(
        InsightEntity.project(item.project.id),
        GalleryProjectTile(data: item, onTap: onTap),
      ),
      onTap: (index) => _openProject(projects[index].project),
      footer: true,
    );
  }

  Widget _starsGrid(AppStrings strings) {
    final stars = [for (final entry in _filteredEntries) _starGridData(entry)];
    return _gridBody<GalleryStarData>(
      controller: _scrollControllers[2],
      items: stars,
      emptyText: strings.noSearchResultsStars,
      tile: (item, onTap) => _flipTile(
        item.star != null
            ? InsightEntity.star(item.star!.id)
            : InsightEntity.habit(item.habit!.id),
        GalleryStarTile(data: item, onTap: onTap),
      ),
      onTap: (index) => _openStarReader(stars[index].key),
      footer: true,
    );
  }

  Future<LifeArea?> _pushArea(
    LifeArea area, {
    double scrollOffset = 0,
    ValueChanged<double>? onScrollChanged,
    Map<int, double>? previewOffsets,
  }) => Navigator.of(context).push<LifeArea>(
    MaterialPageRoute(
      builder: (_) => AreaDetailScreen(
        area: area,
        initialScrollOffset: scrollOffset,
        onScrollChanged: onScrollChanged,
        previewOffsets: previewOffsets,
        areaVisionRepository: widget.areaVisionRepository,
        reflectionAnswerRepository: widget.reflectionAnswerRepository,
        projectRepository: widget.projectRepository,
        starRepository: widget.starRepository,
      ),
    ),
  );

  Future<Object?> _pushProject(
    Project project, {
    Matrix4? transform,
    ValueChanged<Matrix4>? onTransformChanged,
  }) => Navigator.of(context).push<Object>(
    MaterialPageRoute(
      builder: (_) => ConstellationScreen(
        project: project,
        initialTransform: transform,
        onTransformChanged: onTransformChanged,
        starRepository: widget.starRepository,
        projectRepository: widget.projectRepository,
        habitRepository: widget.habitRepository,
        habitCompletionRepository: widget.habitCompletionRepository,
        starsShapeRepository: widget.starsShapeRepository,
      ),
    ),
  );

  Future<void> _openArea(
    LifeArea area, {
    double scrollOffset = 0,
    Map<int, double> previewOffsets = const {},
  }) async {
    var lastOffset = scrollOffset;
    final previews = {...previewOffsets};
    final result = await _pushArea(
      area,
      scrollOffset: scrollOffset,
      previewOffsets: previews,
      onScrollChanged: (offset) => lastOffset = offset,
    );
    _refreshAndRebuild();
    if (result != null && mounted) {
      _session.resume = ResumeArea(
        result,
        scrollOffset: lastOffset,
        previewOffsets: previews,
      );
      widget.onNavigateTo(SkyAreaTarget(result));
    }
  }

  Future<void> _openAreaVision(LifeArea area) => Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => VisionEditorScreen(
            area: area,
            repository: widget.areaVisionRepository,
          ),
        ),
      )
      .then((_) {
        _refreshAndRebuild();
      });

  Future<void> _openAreaMoodboard(LifeArea area) async {
    try {
      final repository = await MoodboardRepository.create();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MoodboardScreen(area: area, repository: repository),
        ),
      );
      _refreshAndRebuild();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.moodboardSaveError)),
        );
      }
    }
  }

  Future<void> _openNewConstellation(LifeArea area) =>
      _create(constellation: true, constellationOnly: true, area: area);

  /// The one creation page behind the Sky's add button: a constellation or a
  /// star of any kind, chosen at its top. The search-level route deliberately
  /// has no constellation preselected: this is the one place that sees the
  /// whole sky, so the form's picker is the right place to choose where a
  /// new star belongs. [constellation] opens on the constellation tile and
  /// [area] pre-fills the area.
  Future<void> _create({
    bool constellation = false,
    bool constellationOnly = false,
    bool startWithoutSelection = false,
    LifeArea? area,
  }) async {
    final shapes = widget.starsShapeRepository;
    final created = await showCreatePage(
      context,
      projectRepository: widget.projectRepository,
      starsShapeRepository: shapes,
      starRepository: widget.starRepository,
      habitRepository: widget.habitRepository,
      constellation: constellation,
      constellationOnly: constellationOnly,
      startWithoutSelection: startWithoutSelection,
      area: area,
      initialDate: _dayContext?.day,
    );
    if (created == null) return;
    if (created case final Habit habit when _dayContext != null) {
      await widget.habitCompletionRepository.markDone(
        habit.id,
        date: _dayContext!.day,
      );
    }
    _refreshAndRebuild();
    if (!mounted) return;
    switch (created) {
      case final Project project:
        _announceConstellationCreated(project);
      case final Habit habit:
        _announcePulsarCreated(habit);
      case final Star star:
        _announceStarCreated(star);
    }
  }

  void _announceStarCreated(Star star) {
    final project = _projectsById[star.projectId];
    if (project == null) return;
    CreationSuccessDialog.show(
      context,
      icon: star.isLit ? Icons.star : Icons.star_border,
      iconColor: starKindColor(star.kind, context.colors),
      message: star.isLit
          ? context.strings.creationSuccessLitMessage
          : context.strings.creationSuccessUnlitMessage,
      onOpen: () => _openCreatedEntry(project, StarEntry(star).key),
      onTakeMeThere: () =>
          widget.onNavigateTo(SkyStarTarget(project, starId: star.id)),
      onShare: () => showSharePreview(
        context: context,
        content: star.isLit
            ? ShareableLitStarCard(star: star, project: project)
            : ShareableGoalCard(star: star, project: project),
        shareText: star.displayTitle,
        fileName: 'star_${star.id}.png',
      ),
    );
  }

  void _announcePulsarCreated(Habit habit) {
    final project = _projectsById[habit.projectId];
    if (project == null) return;
    CreationSuccessDialog.show(
      context,
      icon: StarKind.pulsar.icon,
      iconColor: starKindColor(StarKind.pulsar, context.colors),
      message: context.strings.creationSuccessPulsarMessage,
      onOpen: () => _openCreatedEntry(project, PulsarEntry(habit).key),
      onTakeMeThere: () =>
          widget.onNavigateTo(SkyStarTarget(project, habitId: habit.id)),
      onShare: () => showSharePreview(
        context: context,
        content: ShareablePulsarCard(habit: habit, project: project),
        shareText: habit.displayTitle,
        fileName: 'pulsar_${habit.id}.png',
      ),
    );
  }

  void _announceConstellationCreated(Project project) {
    final shape = project.starsShapeId == null
        ? null
        : widget.starsShapeRepository.getById(project.starsShapeId!)?.shape;
    CreationSuccessDialog.show(
      context,
      icon: iconForSlug(project.iconSlug),
      iconColor: context.colors.gold,
      message: context.strings.creationSuccessConstellationMessage,
      onOpen: () => _openProject(project),
      onTakeMeThere: () => widget.onNavigateTo(SkyProjectTarget(project)),
      onShare: shape == null
          ? () {}
          : () => showSharePreview(
              context: context,
              content: ShareableConstellationCard(
                project: project,
                shape: shape,
              ),
              shareText: project.displayName,
              fileName: 'constellation_${project.id}.png',
            ),
    );
  }

  /// The same add button in every mode, opening the same creation page; only
  /// the tile it opens on follows the mode.
  ({IconData icon, String tooltip, VoidCallback onPressed})? get _modeAction =>
      (
        icon: Icons.rocket_launch,
        tooltip: context.strings.addExtraAction,
        onPressed: () => _create(startWithoutSelection: true),
      );

  Future<void> _openAreaReflections(LifeArea area) =>
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => AreaReflectionsScreen(
                area: area,
                repository: widget.reflectionAnswerRepository,
              ),
            ),
          )
          .then((_) {
            _refreshAndRebuild();
          });

  Future<void> _addStarToConstellation(Project project) async {
    final shape = project.starsShapeId == null
        ? null
        : widget.starsShapeRepository.getById(project.starsShapeId!)?.shape;
    final occupied = widget.starRepository
        .getAllForProject(project.id)
        .map((star) => star.slotSequence)
        .toSet();
    int? firstFreeSlot;
    for (var slot = 1; slot <= (shape?.points.length ?? 0); slot++) {
      if (!occupied.contains(slot)) {
        firstFreeSlot = slot;
        break;
      }
    }
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          slotSequence: firstFreeSlot,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    if (result.kind == StarKind.pulsar) {
      final habit = await widget.habitRepository.add(
        title: result.title,
        iconSlug: result.iconSlug,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? 3,
        frequency: result.habitFrequency ?? HabitFrequency.daily,
        targetPerPeriod: result.habitTargetPerPeriod ?? 1,
        cycleLength: result.habitCycleLength ?? kDefaultCycleLength,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
      );
      _refreshAndRebuild();
      if (mounted) _announcePulsarCreated(habit);
      return;
    }
    final star = await widget.starRepository.add(
      title: result.title,
      iconSlug: result.iconSlug,
      description: result.description,
      projectId: result.projectId,
      slotSequence: result.slotSequence,
      targetDate: result.targetDate,
      achievedDate: result.achievedDate,
      intensity: result.intensity,
      photoPath: result.photoPath,
      media: result.media,
    );
    _refreshAndRebuild();
    if (mounted) _announceStarCreated(star);
  }

  Future<void> _editConstellation(Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          existingProject: project,
        ),
      ),
    );
    _refreshAndRebuild();
  }

  Future<void> _shareConstellation(Project project) async {
    final shape = project.starsShapeId == null
        ? null
        : widget.starsShapeRepository.getById(project.starsShapeId!)?.shape;
    if (shape == null || !mounted) return;
    await showSharePreview(
      context: context,
      content: ShareableConstellationCard(project: project, shape: shape),
      shareText: project.displayName,
      fileName: 'constellation_${project.id}.png',
    );
  }

  Future<void> _deleteConstellation(Project project) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: strings.deleteProjectConfirmTitle,
      body: strings.deleteProjectConfirmBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.deleteStarAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed) return;
    if (!mounted) return;
    final cycleRepository = HabitCycleScope.read(context);
    final habitIds = await widget.habitRepository.deleteAllForProject(
      project.id,
    );
    for (final habitId in habitIds) {
      await widget.habitCompletionRepository.deleteAllForHabit(habitId);
    }
    await cycleRepository?.deleteAllForHabits(habitIds);
    await widget.starRepository.deleteAllForProject(project.id);
    await widget.projectRepository.delete(project.id);
    final shapeId = project.starsShapeId;
    if (shapeId != null &&
        !widget.projectRepository.getAll().any(
          (p) => p.starsShapeId == shapeId,
        )) {
      await widget.starsShapeRepository.delete(shapeId);
    }
    _refreshAndRebuild();
  }

  Future<void> _openProject(Project project, {Matrix4? transform}) async {
    var lastTransform = transform;
    final result = await _pushProject(
      project,
      transform: transform,
      onTransformChanged: (matrix) => lastTransform = matrix,
    );
    _refreshAndRebuild();
    if (result == null || !mounted) return;
    if (result is SkyStarTarget) {
      _session.resume = ResumeProject(
        result.project.id,
        transform: lastTransform,
      );
      widget.onNavigateTo(result);
    } else if (result is Project) {
      _session.resume = ResumeProject(result.id, transform: lastTransform);
      widget.onNavigateTo(SkyProjectTarget(result));
    }
  }

  Future<void> _openStarReader(String anchorKey) async {
    final entries = _filteredReaderEntries();
    final index = entries.indexWhere((e) => e.key == anchorKey);
    if (index == -1) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialEntries: entries,
          startIndex: index,
          allowEdit: true,
          projectsById: _projectsById,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          // The reader edits stars while it's open: re-read the repositories
          // each time, or it keeps showing what the grid last cached.
          refreshEntries: () {
            _refreshDataCache();
            return _filteredReaderEntries();
          },
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          onNavigateTo: (project, {starId, habitId}) {
            _session.resume = ResumeStar(
              starId != null ? 's$starId' : 'p$habitId',
            );
            widget.onNavigateTo(
              SkyStarTarget(project, starId: starId, habitId: habitId),
            );
          },
        ),
      ),
    );
    _refreshAndRebuild();
  }

  Future<void> _openCreatedEntry(Project project, String anchorKey) async {
    List<ReaderEntry> load() => projectReaderEntries(
      project: project,
      starRepository: widget.starRepository,
      habitRepository: widget.habitRepository,
      starsShapeRepository: widget.starsShapeRepository,
    );
    final entries = load();
    final index = entries.indexWhere((entry) => entry.key == anchorKey);
    if (index == -1) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialEntries: entries,
          startIndex: index,
          allowEdit: true,
          projectsById: {project.id: project},
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshEntries: load,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          onNavigateTo: (project, {starId, habitId}) => widget.onNavigateTo(
            SkyStarTarget(project, starId: starId, habitId: habitId),
          ),
        ),
      ),
    );
    _refreshAndRebuild();
  }

  /// Same two branches and repository calls as
  /// `StarReaderScreen._editOrResurrectCurrent` (a dead star is resurrected
  /// instead of updated, and can't be deleted from its form) — reached from
  /// a card's quick menu rather than from the reader.
  Future<void> _editStar(Star star) async {
    final project = _projectsById[star.projectId];
    if (star.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingStar: star,
            contextProject: project,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      final resurrected = await widget.starRepository.resurrect(
        star.id,
        title: result.title,
        iconSlug: result.iconSlug,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
        media: result.media,
      );
      _refreshAndRebuild();
      if (mounted) _announceStarCreated(resurrected);
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingStar: star,
          contextProject: project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    if (result is StarFormDeleteRequested) {
      await widget.starRepository.delete(star.id);
      _refreshAndRebuild();
      return;
    }

    final edited = result as StarFormResult;
    await widget.starRepository.update(
      id: star.id,
      title: edited.title,
      description: edited.description,
      projectId: edited.projectId,
      targetDate: edited.targetDate,
      achievedDate: edited.achievedDate,
      intensity: edited.intensity,
      photoPath: edited.photoPath,
      media: edited.media,
    );
    _refreshAndRebuild();
  }

  /// Lights a goal from its card: the same sheet the reader uses.
  Future<void> _lightStar(Star star) async {
    final result = await showMarkAchievedSheet(context);
    if (result == null) return;
    await widget.starRepository.markAchieved(
      star.id,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refreshAndRebuild();
  }

  /// A pulsar's "done today" from its card: marks today (or takes it back
  /// off); a daily habit with a target above 1 logs one more instance instead.
  Future<void> _habitTodayAction(Habit habit) async {
    final completions = widget.habitCompletionRepository;
    final counts = _countsByDayFor(habit.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isStepper =
        habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1;
    if (isStepper) {
      await completions.logInstance(habit.id);
    } else if (counts.containsKey(today)) {
      await completions.unmarkDone(habit.id, today);
    } else {
      await completions.markDone(habit.id);
    }
    _refreshAndRebuild();
  }

  /// Edit, or for a dead pulsar bring it back — the same two branches as the
  /// star reader's pulsar page.
  Future<void> _editHabit(Habit habit) async {
    final project = _projectsById[habit.projectId];
    if (habit.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingHabit: habit,
            contextProject: project,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      final resurrected = await widget.habitRepository.resurrect(
        habit.id,
        title: result.title,
        iconSlug: result.iconSlug,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? habit.intensity,
        frequency: result.habitFrequency ?? habit.frequency,
        targetPerPeriod: result.habitTargetPerPeriod ?? habit.targetPerPeriod,
        cycleLength: result.habitCycleLength ?? habit.cycleLength,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
        completionRepository: widget.habitCompletionRepository,
      );
      _refreshAndRebuild();
      if (mounted) _announcePulsarCreated(resurrected);
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingHabit: habit,
          contextProject: project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;
    if (result is StarFormDeleteRequested) {
      await widget.habitRepository.delete(habit.id);
      _refreshAndRebuild();
      return;
    }
    final edited = result as StarFormResult;
    await widget.habitRepository.update(
      id: habit.id,
      title: edited.title,
      description: edited.description,
      projectId: edited.projectId,
      intensity: edited.intensity ?? habit.intensity,
      frequency: edited.habitFrequency ?? habit.frequency,
      targetPerPeriod: edited.habitTargetPerPeriod ?? habit.targetPerPeriod,
      cycleLength: edited.habitCycleLength ?? habit.cycleLength,
      reminderHour: edited.reminderHour,
      reminderMinute: edited.reminderMinute,
    );
    _refreshAndRebuild();
  }

  Future<void> _deleteHabit(Habit habit) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: strings.deletePulsarConfirmTitle,
      body: strings.deletePulsarConfirmBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.archiveAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed) return;
    await widget.habitRepository.delete(habit.id);
    _refreshAndRebuild();
  }

  Future<void> _deleteStar(Star star) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: strings.deleteStarConfirmTitle,
      body: strings.deleteStarConfirmBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.archiveAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed) return;
    await widget.starRepository.delete(star.id);
    _refreshAndRebuild();
  }

  bool _sharingStar = false;

  Future<void> _shareEntry(_SkyEntry entry) async {
    if (entry.kind == StarKind.dead ||
        entry.kind == StarKind.nascent ||
        _sharingStar) {
      return;
    }
    _sharingStar = true;
    try {
      if (!mounted) return;
      final (content, text, fileName) = entry.star != null
          ? (
              entry.star!.isLit
                  ? ShareableLitStarCard(
                      star: entry.star!,
                      project: _projectsById[entry.star!.projectId],
                    )
                  : ShareableGoalCard(
                      star: entry.star!,
                      project: _projectsById[entry.star!.projectId],
                    ),
              entry.star!.title,
              'star_${entry.star!.id}.png',
            )
          : (
              ShareablePulsarCard(
                habit: entry.habit!,
                project: _projectsById[entry.habit!.projectId],
              ),
              entry.habit!.title,
              'pulsar_${entry.habit!.id}.png',
            );
      await showSharePreview(
        context: context,
        content: content,
        shareText: text,
        fileName: fileName,
      );
    } finally {
      _sharingStar = false;
    }
  }

  Future<void> _openAreaFilter() async {
    final result = await showAreaFilterSheet(
      context,
      selectedAreas: _areaFilter,
      preview: FilterPreview<Set<LifeArea>>(
        icon: _modeIcon,
        countFor: (areas) => _previewCount(areas: areas),
        wordFor: _resultsWord,
      ),
    );
    if (result == null) return;
    setState(() {
      _areaFilter = result;
    });
    _saveSession();
  }

  Future<void> _openProjectFilter() async {
    final picked = await pickProjectFilter(
      context,
      widget.projectRepository,
      widget.starsShapeRepository,
      selected: _projectFilterIds,
      preview: FilterPreview<Set<int>>(
        icon: _modeIcon,
        countFor: (ids) => _previewCount(projects: ids),
        wordFor: _resultsWord,
      ),
    );
    if (picked == null) return;
    setState(() {
      _projectFilterIds = picked;
    });
    _saveSession();
  }

  Future<void> _openKindFilter() async {
    final result = await showKindFilterSheet(
      context,
      selectedKinds: _kindFilter,
      preview: FilterPreview<Set<StarKind>>(
        icon: _modeIcon,
        countFor: (kinds) => _previewCount(kinds: kinds),
        wordFor: _resultsWord,
      ),
    );
    if (result == null) return;
    setState(() {
      _kindFilter = result;
    });
    _saveSession();
  }

  Future<void> _openDateRangeFilter() async {
    final result = await showDateRangeFilterSheet(
      context,
      initialRange: _dateRangeFilter,
      initialPreset: _dateRangePreset,
      initialField: _rangeDateField,
      availableFields: _availableDateFields(),
      preview: FilterPreview<({DateTimeRange? range, SkyDateField field})>(
        icon: _modeIcon,
        countFor: (selection) => _previewCount(dateRange: selection),
        wordFor: _resultsWord,
      ),
    );
    if (result == null) return;
    setState(() {
      _dateRangeFilter = result.range;
      _dateRangePreset = result.preset;
      _tab.rangeDateField = result.field;
    });
    _saveSession();
  }

  Future<void> _openSortFilter() async {
    final result = await showSortFilterSheet(
      context,
      initialField: _sortField,
      initialDirection: _sortDirection,
      initialDateField: _sortDateField,
      availableDateFields: _availableDateFields(),
    );
    if (result == null) return;
    setState(() {
      _sortField = result.field;
      _sortDirection = result.direction;
      _tab.sortDateField = result.dateField;
    });
    _saveSession();
  }

  /// Whether the current sort differs from this file's own long-standing
  /// default (newest first, by creation date) — the button only lights up
  /// gold when it does, same "neutral vs. narrowed" reading the other three
  /// filter buttons use even though, unlike them, sorting itself is never
  /// actually "off".
  bool get _isSortNonDefault =>
      _sortField != SortField.date ||
      _sortDirection != SortDirection.descending ||
      _sortDateField != SkyDateField.created;

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
  /// Every area starts selected; any smaller set, including none, is active.
  bool get _isAreaFilterNarrowed =>
      _areaFilter.length != LifeArea.values.length;

  bool get _isProjectFilterActive => _projectFilterIds.isNotEmpty;

  /// The constellation button's own label — the picked constellation's name
  /// when there is one, how many when there are several, or the neutral
  /// "Constellation" while none is picked.
  String _projectFilterButtonLabel(AppStrings strings) {
    if (_projectFilterIds.length > 1) {
      return strings.activeProjectsCount(_projectFilterIds.length);
    }
    for (final project in _projectsCache) {
      if (_projectFilterIds.contains(project.id)) return project.displayName;
    }
    return strings.projectLabel;
  }

  /// Same idea as [_isAreaFilterNarrowed], for [_kindFilter].
  bool get _isKindFilterNarrowed =>
      _kindFilter.length != kListableStarKinds.length;

  /// Whether any of the filters that actually apply to [_mode] right now is
  /// narrowed/non-default — lights up the mobile "Filtri" trigger button
  /// (see [FiltersTriggerButton]) exactly when opening it would reveal at
  /// least one button already lit, same "lit vs dark" rule each of those
  /// buttons already follows on its own.
  bool get _isAnyFilterActive =>
      _isAreaFilterNarrowed ||
      (_mode == _SkyMode.stars &&
          (_isKindFilterNarrowed || _isProjectFilterActive)) ||
      _dateRangeFilter != null ||
      _isSortNonDefault;

  bool get _hasAnyConfiguredFilter =>
      _isAreaFilterNarrowed ||
      _isKindFilterNarrowed ||
      _isProjectFilterActive ||
      _dateRangeFilter != null ||
      _isSortNonDefault;

  void _resetAllFilters() {
    setState(() {
      _areaFilter = {...LifeArea.values};
      _projectFilterIds = {};
      _kindFilter = {...kListableStarKinds};
      _dateRangeFilter = null;
      _dateRangePreset = DateRangePreset.allTime;
      _sortField = SortField.date;
      _sortDirection = SortDirection.descending;
      _tab.rangeDateField = SkyDateField.created;
      _tab.sortDateField = SkyDateField.created;
    });
    _saveSession();
  }

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

  /// Which date the range applies to, shown under the date button — only
  /// while a range is set and the date isn't the default (creation).
  String? _dateRangeButtonCaption(AppStrings strings) =>
      _dateRangeFilter == null || _rangeDateField == SkyDateField.created
      ? null
      : _rangeDateField.label(strings);

  /// Which date "sort by date" uses, shown under the sort button when it
  /// isn't the default.
  String? _sortButtonCaption(AppStrings strings) =>
      _sortField != SortField.date || _sortDateField == SkyDateField.created
      ? null
      : _sortDateField.label(strings);

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
      _saveSession();
    });
  }

  /// Every filter button that applies to [_mode] right now (empty in
  /// Supernovas — no filter applies to its fixed grid of all 8 areas —
  /// otherwise area, + kind in Stars only, + date, + sort, in that order).
  /// Each button reads live state directly (not a value captured at some
  /// earlier build), so calling this again after [onChanged] fires — see
  /// [_openControlsSheet] — always reflects whatever just changed. No
  /// [HintTarget] wrapping here: the two call sites that need the
  /// "search-stars" tour's order-4 step wrap whichever of their own widgets
  /// is the one actually tappable before anything else opens (the area
  /// button itself on a wide layout, the single mobile trigger otherwise),
  /// so exactly one order-4 target is ever mounted at a time.
  List<Widget> _buildFilterButtons(
    AppStrings strings, {
    VoidCallback? onChanged,
    bool horizontal = false,
  }) {
    if (_mode == _SkyMode.supernovas) return const <Widget>[];

    Future<void> wrap(Future<void> Function() action) async {
      await action();
      onChanged?.call();
    }

    return [
      FilterButton(
        icon: Icons.flare,
        active: _isAreaFilterNarrowed,
        label: _areaFilterButtonLabel(strings),
        tooltip: strings.filterAreasAction,
        horizontal: horizontal,
        onTap: () => wrap(_openAreaFilter),
      ),
      if (_mode == _SkyMode.stars)
        FilterButton(
          icon: Icons.insights,
          active: _isProjectFilterActive,
          label: _projectFilterButtonLabel(strings),
          tooltip: strings.selectAProject,
          horizontal: horizontal,
          onTap: () => wrap(_openProjectFilter),
        ),
      if (_mode == _SkyMode.stars)
        FilterButton(
          icon: Icons.auto_awesome,
          active: _isKindFilterNarrowed,
          label: _kindFilterButtonLabel(strings),
          tooltip: strings.filterKindAction,
          horizontal: horizontal,
          onTap: () => wrap(_openKindFilter),
        ),
      if (_dayContext == null)
        FilterButton(
          icon: Icons.calendar_month,
          active: _dateRangeFilter != null,
          label: _dateRangeButtonLabel(strings),
          caption: _dateRangeButtonCaption(strings),
          tooltip: strings.filterDateRangeAction,
          horizontal: horizontal,
          onTap: () => wrap(_openDateRangeFilter),
        ),
      FilterButton(
        icon: Icons.sort,
        active: _isSortNonDefault,
        label: _sortButtonLabel(strings),
        caption: _sortButtonCaption(strings),
        tooltip: strings.sortAction,
        horizontal: horizontal,
        onTap: () => wrap(_openSortFilter),
      ),
    ];
  }

  /// The trigger's destination: the view (list/grid + card size), every
  /// filter that applies to [_mode], and sort, as three sections of one sheet.
  /// A [StatefulBuilder] so coming back from a filter's own sheet refreshes
  /// this one's labels/active state in place, rather than leaving it showing
  /// what was true when it opened. The barrier is light so the list/grid
  /// behind stays easy to judge while the view settings change.
  Future<void> _openControlsSheet(BuildContext context) async {
    final strings = context.strings;
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: kSkyViewSheetBarrier,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Sort is always the last button; the rest are filters.
          final buttons = _buildFilterButtons(
            strings,
            onChanged: () => setSheetState(() {}),
            horizontal: true,
          );
          return _ControlsSheet(
            settings: widget.settings,
            filterButtons: buttons.isEmpty
                ? const <Widget>[]
                : buttons.sublist(0, buttons.length - 1),
            sortButton: buttons.isEmpty ? null : buttons.last,
            canReset: _hasAnyConfiguredFilter,
            resetLabel: strings.clearFilterAction,
            onReset: () {
              _resetAllFilters();
              setSheetState(() {});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    if (_dayContext == null) _syncModeToTour(context);
    final allEntries = _mode == _SkyMode.stars
        ? _allEntries
        : const <_SkyEntry>[];
    final filteredEntries = _mode == _SkyMode.stars
        ? _filteredEntries
        : const <_SkyEntry>[];

    final action = _modeAction;
    return GestureDetector(
      key: _dayContext == null
          ? null
          : const ValueKey('sky-day-swipe-surface'),
      onHorizontalDragEnd: (details) =>
          _swipeMode(details.velocity.pixelsPerSecond.dx),
      child: Stack(
        children: [
          Container(
            color: colors.night,
            child: Column(
              children: [
                // Only the fixed header chrome is width-capped here — the
                // Expanded list below stays full width so its own scrollbar
                // sits at the true page edge on wide viewports rather than
                // hugging a centered column (see ResponsiveContent's doc).
                ResponsiveContent(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                        child: _dayContext != null
                            ? SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    IconButton(
                                      key: const ValueKey('sky-day-previous'),
                                      tooltip: strings.todayLightPrevious,
                                      onPressed: () => _shiftDay(-1),
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Expanded(
                                      child: StaggeredEntrance(
                                        index: 0,
                                        axis: Axis.horizontal,
                                        replayKey: _dayContext!.day,
                                        reverse: _modeReverse,
                                        child: Text(
                                          formatDisplayDate(
                                            _dayContext!.day,
                                            strings,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.text,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey('sky-day-next'),
                                      tooltip: strings.todayLightNext,
                                      onPressed: () => _shiftDay(1),
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : HintTarget(
                                tour: 'search-stars',
                                order: 1,
                                showArrow: true,
                                spotlightPadding: const EdgeInsets.all(8),
                                contentBuilder: appTourStepCard,
                                title: strings.searchTourModeTitle,
                                description: strings.searchTourModeBody,
                                child: StaggeredEntrance(
                                  index: 1,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child:
                                          AnimatedToggleSwitch<
                                            _SkyMode
                                          >.rolling(
                                            height: 40,
                                            current: _mode,
                                            values: _SkyMode.values,
                                            onChanged: _selectMode,
                                            // The package default is 2; every other
                                            // control on this row draws kBorderWidth.
                                            borderWidth: kBorderWidth,
                                            // The package dims inactive icons to
                                            // half on top of their own color; the
                                            // search field's icon isn't dimmed.
                                            iconOpacity: 1.0,
                                            iconBuilder: (value, size) => Icon(
                                              switch (value) {
                                                _SkyMode.supernovas =>
                                                  Icons.flare,
                                                _SkyMode.constellations =>
                                                  Icons.insights,
                                                _SkyMode.stars =>
                                                  Icons.auto_awesome,
                                              },
                                              size: 20,
                                              color: value == _mode
                                                  ? colors.night
                                                  : colors.muted,
                                            ),
                                            style: ToggleStyle(
                                              backgroundColor:
                                                  colors.nightPanel,
                                              indicatorColor: colors.gold,
                                              borderColor: colors.nightBorder,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    kRadiusField,
                                                  ),
                                              indicatorBorderRadius:
                                                  BorderRadius.circular(
                                                    kRadiusField,
                                                  ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      Builder(
                        builder: (context) {
                          final searchField = StaggeredEntrance(
                            index: 2,
                            child: AppSearchField(
                              controller: _queryController,
                              hintText: switch (_mode) {
                                _SkyMode.supernovas => strings.searchAreasHint,
                                _SkyMode.constellations =>
                                  strings.searchProjectsHint,
                                _SkyMode.stars => strings.searchActivitiesHint,
                              },
                              onChanged: (value) {
                                _cardMenuController.closeAll();
                                setState(() {
                                  _query = value;
                                });
                                _saveSession();
                              },
                            ),
                          );

                          // One trigger beside the field, at every width: it opens
                          // the controls sheet (view, filters, sort) rather than
                          // a permanent row of buttons eating space on each visit.
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                            child: Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 10),
                                HintTarget(
                                  tour: 'search-stars',
                                  order: 2,
                                  showArrow: true,
                                  contentBuilder: appTourStepCard,
                                  title: strings.searchTourFilterButtonTitle,
                                  description:
                                      strings.searchTourFilterButtonBody,
                                  child: FiltersTriggerButton(
                                    active: _isAnyFilterActive,
                                    tooltip: strings.filtersAction,
                                    onTap: () => _openControlsSheet(context),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Builder(
                          builder: (_) {
                            final count = _resultCount(strings);
                            final row = ResultsCountRow(
                              icon: _modeIcon,
                              count: count,
                              word: _resultsWord(count),
                            );
                            final day = _dayContext?.day;
                            return day == null
                                ? row
                                : StaggeredEntrance(
                                    index: 1,
                                    axis: Axis.horizontal,
                                    replayKey: day,
                                    reverse: _modeReverse,
                                    child: row,
                                  );
                          },
                        ),
                      ),
                      FlippedCardsRow(
                        count: _flippedCount(strings),
                        onReset: () => setState(_tab.flipped.clear),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _modeAnimation,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: Offset(_modeReverse ? -0.12 : 0.12, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _modeAnimation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
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
                          _SkyMode.supernovas =>
                            _gridView
                                ? _areasGrid(strings)
                                : Builder(
                                    builder: (context) {
                                      final areas = _filteredSupernovaAreas(
                                        strings,
                                      );
                                      if (areas.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                          ),
                                          child: Center(
                                            child: StaggeredEntrance(
                                              index: 0,
                                              child: Text(
                                                strings
                                                    .noSearchResultsSupernovas,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: colors.muted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return ListView.separated(
                                        controller: _scrollControllers[0],
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          4,
                                          0,
                                          16,
                                        ),
                                        itemCount: areas.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final area = areas[index];
                                          return StaggeredEntrance(
                                            index: index,
                                            child: ResponsiveContent(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                    ),
                                                child: _AreaCard(
                                                  area: area,
                                                  badges: _areaBadges(area),
                                                  menuController:
                                                      _cardMenuController,
                                                  onTap: () => _openArea(area),
                                                  onVision: () =>
                                                      _openAreaVision(area),
                                                  onMoodboard: () =>
                                                      _openAreaMoodboard(area),
                                                  onReflections: () =>
                                                      _openAreaReflections(
                                                        area,
                                                      ),
                                                  onNewConstellation: () =>
                                                      _openNewConstellation(
                                                        area,
                                                      ),
                                                  onNavigateTo: () =>
                                                      widget.onNavigateTo(
                                                        SkyAreaTarget(area),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                          _SkyMode.constellations =>
                            _gridView
                                ? _constellationsGrid(strings)
                                : _ConstellationsList(
                                    scrollController: _scrollControllers[1],
                                    hasAnyProjects:
                                        _filteredAreaProjects.isNotEmpty,
                                    filteredProjects: _filteredProjects,
                                    badgesFor: _projectBadges,
                                    shapeForProject: (project) =>
                                        _shapesByIdCache[project.starsShapeId],
                                    menuController: _cardMenuController,
                                    onTap: _openProject,
                                    onNavigateTo: widget.onNavigateTo,
                                    onAddStar: _addStarToConstellation,
                                    onShare: _shareConstellation,
                                    onEdit: _editConstellation,
                                    onDelete: _deleteConstellation,
                                  ),
                          _SkyMode.stars =>
                            _gridView
                                ? _starsGrid(strings)
                                : _FlatList(
                                    scrollController: _scrollControllers[2],
                                    hasAnyEntries: allEntries.isNotEmpty,
                                    entries: filteredEntries,
                                    projectsById: _projectsById,
                                    countsByDayFor: _countsByDayFor,
                                    badgesFor: _entryBadges,
                                    query: _query,
                                    menuController: _cardMenuController,
                                    onOpenStar: (entry) => _openStarReader(
                                      StarEntry(entry.star!).key,
                                    ),
                                    onOpenHabit: (habit) =>
                                        _openStarReader(PulsarEntry(habit).key),
                                    onNavigateTo: widget.onNavigateTo,
                                    onShareEntry: _shareEntry,
                                    onEditStar: _editStar,
                                    onDeleteStar: _deleteStar,
                                    onLightStar: _lightStar,
                                    onHabitToday: _habitTodayAction,
                                    onEditHabit: _editHabit,
                                    onDeleteHabit: _deleteHabit,
                                  ),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Capped to the shared content column on wide layouts, like the
          // list above, so the floating actions sit inside it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: ResponsiveContent(
              shrinkHeight: true,
              child: Padding(
                // Wider inset on wide layouts, so the buttons don't sit
                // flush against the column's edges.
                padding: EdgeInsets.symmetric(
                  horizontal: isWideLayout(context) ? 36 : 20,
                ),
                child: SafeArea(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: action == null
                        ? SizedBox.shrink(
                            key: ValueKey('sky-actions-${_mode.name}'),
                          )
                        : _SkyFloatingActions(
                            key: ValueKey('sky-actions-${_mode.name}'),
                            style: _SkyActionStyle.pill,
                            showBackToTop: _showBackToTop,
                            backToTopAvoidsFooter: _backToTopAvoidsFooter,
                            backTooltip: strings.backToTopAction,
                            onBackToTop: _scrollToTop,
                            primaryIcon: action.icon,
                            primaryLabel: action.tooltip,
                            onPrimary: action.onPressed,
                          ),
                  ),
                ),
              ),
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
    required this.badges,
    required this.menuController,
    required this.onTap,
    required this.onVision,
    required this.onMoodboard,
    required this.onReflections,
    required this.onNewConstellation,
    required this.onNavigateTo,
  });

  final LifeArea area;
  final CardBadges badges;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback onVision;
  final VoidCallback onMoodboard;
  final VoidCallback onReflections;
  final VoidCallback onNewConstellation;
  final VoidCallback onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SearchResultCard(
      preserveMenuOnAction: true,
      menuId: 'area:${area.name}',
      menuController: menuController,
      onTap: onTap,
      baseBodyHeight: SearchResultCard.bodyHeightFor(badges),
      visual: SearchArtworkVisual(
        asset: kAreaHeroArt[area]?.skyAsset,
        fallbackIcon: Icons.flare,
      ),
      content: SearchCardTextContent(
        eyebrow: strings.areaLabel,
        eyebrowColor: context.colors.gold,
        title: area.displayName(strings),
        breadcrumb: strings.galaxyLabel,
        badges: badges,
      ),
      actions: [
        SearchCardAction(
          icon: Icons.insights,
          label: '+ Costellazione',
          onTap: onNewConstellation,
        ),
        SearchCardAction(
          icon: kAreaVisionIcon,
          label: 'Vision',
          onTap: onVision,
          group: 1,
        ),
        SearchCardAction(
          icon: kAreaMoodboardIcon,
          label: 'Moodboard',
          onTap: onMoodboard,
          group: 1,
        ),
        SearchCardAction(
          icon: kAreaReflectionsIcon,
          label: 'Riflessioni',
          onTap: onReflections,
          group: 1,
        ),
        SearchCardAction(
          icon: Icons.navigation,
          label: 'Vola',
          onTap: onNavigateTo,
          group: 2,
        ),
      ],
    );
  }
}

/// [FiltersTriggerButton]'s destination in Sky, in three sections: View
/// ([SkyViewModeSection]), Filters (every [FilterButton] that applies to the
/// current mode, two to a row) and Sort. Aree has no filters or sort, so it
/// shows the view section alone.
class _ControlsSheet extends StatelessWidget {
  const _ControlsSheet({
    required this.settings,
    required this.filterButtons,
    required this.sortButton,
    required this.canReset,
    required this.resetLabel,
    required this.onReset,
  });

  final SettingsController settings;
  final List<Widget> filterButtons;
  final Widget? sortButton;
  final bool canReset;
  final String resetLabel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final hasFilterSections = filterButtons.isNotEmpty || sortButton != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Center(child: AppSheetTitle(strings.skyViewModeTitle)),
            ),
            const SizedBox(height: 14),
            SkyViewModeSection(settings: settings),
            if (filterButtons.isNotEmpty) ...[
              const SizedBox(height: 24),
              AppSheetTitle(strings.filtersAction),
              const SizedBox(height: 14),
              for (var i = 0; i < filterButtons.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StaggeredEntrance(
                        index: 1 + i,
                        axis: Axis.horizontal,
                        child: filterButtons[i],
                      ),
                    ),
                    if (i + 1 < filterButtons.length) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: StaggeredEntrance(
                          index: 2 + i,
                          axis: Axis.horizontal,
                          child: filterButtons[i + 1],
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ],
            ],
            if (sortButton != null) ...[
              const SizedBox(height: 24),
              AppSheetTitle(strings.sortAction),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: sortButton!,
                ),
              ),
            ],
            if (hasFilterSections) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: canReset ? onReset : null,
                  child: AppButtonLabel(resetLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConstellationsList extends StatelessWidget {
  const _ConstellationsList({
    required this.hasAnyProjects,
    required this.filteredProjects,
    required this.badgesFor,
    required this.shapeForProject,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
    required this.onAddStar,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    required this.scrollController,
  });

  final bool hasAnyProjects;
  final List<Project> filteredProjects;
  final CardBadges Function(Project project) badgesFor;
  final ConstellationShape? Function(Project project) shapeForProject;
  final SearchCardMenuController menuController;
  final void Function(Project) onTap;
  final ValueChanged<SkyNavigationTarget> onNavigateTo;
  final ValueChanged<Project> onAddStar;
  final ValueChanged<Project> onShare;
  final ValueChanged<Project> onEdit;
  final ValueChanged<Project> onDelete;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (!hasAnyProjects) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            child: Text(
              strings.skyEmptyConstellations,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }
    if (filteredProjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            child: Text(
              strings.noSearchResultsConstellations,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      // Horizontal margin comes from each item's own Padding below, applied
      // *inside* its ResponsiveContent instead of here — see that widget's
      // comment for why: it's what keeps a card's left edge lined up with
      // the search row above it on wide layouts.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: filteredProjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = filteredProjects[index];
        return StaggeredEntrance(
          index: index,
          child: ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProjectCard(
                project: project,
                badges: badgesFor(project),
                shape: shapeForProject(project),
                menuController: menuController,
                onTap: () => onTap(project),
                onNavigateTo: () => onNavigateTo(SkyProjectTarget(project)),
                onAddStar: () => onAddStar(project),
                onShare: () => onShare(project),
                onEdit: () => onEdit(project),
                onDelete: () => onDelete(project),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkyFloatingActions extends StatelessWidget {
  const _SkyFloatingActions({
    super.key,
    required this.style,
    required this.showBackToTop,
    required this.backToTopAvoidsFooter,
    required this.backTooltip,
    required this.onBackToTop,
    required this.primaryIcon,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final _SkyActionStyle style;
  final bool showBackToTop;
  final bool backToTopAvoidsFooter;
  final String backTooltip;
  final VoidCallback onBackToTop;
  final IconData primaryIcon;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    if (style == _SkyActionStyle.dock) {
      return SizedBox(
        height: 56,
        child: Align(
          alignment: Alignment.centerRight,
          child: _SkyActionDock(
            showBackToTop: showBackToTop,
            backTooltip: backTooltip,
            onBackToTop: onBackToTop,
            primaryIcon: primaryIcon,
            primaryLabel: primaryLabel,
            onPrimary: onPrimary,
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          AnimatedAlign(
            key: const Key('sky-back-to-top-position'),
            alignment: backToTopAvoidsFooter
                ? Alignment.centerLeft
                : Alignment.center,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              key: const Key('sky-back-to-top-hit-region'),
              ignoring: !showBackToTop,
              child: AnimatedOpacity(
                opacity: showBackToTop ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: showBackToTop ? 1 : 0.84,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: _SkyBackToTopButton(
                    style: style,
                    tooltip: backTooltip,
                    onTap: onBackToTop,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _SkyPrimaryAction(
              style: style,
              icon: primaryIcon,
              label: primaryLabel,
              onTap: onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyActionDock extends StatelessWidget {
  const _SkyActionDock({
    required this.showBackToTop,
    required this.backTooltip,
    required this.onBackToTop,
    required this.primaryIcon,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final bool showBackToTop;
  final String backTooltip;
  final VoidCallback onBackToTop;
  final IconData primaryIcon;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.nightPanel,
      shape: StadiumBorder(
        side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: showBackToTop ? 44 : 0,
              child: ClipRect(
                child: IgnorePointer(
                  key: const Key('sky-back-to-top-hit-region'),
                  ignoring: !showBackToTop,
                  child: Tooltip(
                    message: backTooltip,
                    child: InkWell(
                      key: const Key('sky-back-to-top-button'),
                      onTap: onBackToTop,
                      child: SizedBox(
                        width: 44,
                        height: 48,
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          color: colors.muted,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showBackToTop)
            Container(
              width: kBorderWidth,
              height: 22,
              color: colors.nightBorder,
            ),
          Tooltip(
            message: primaryLabel,
            child: InkWell(
              key: const Key('sky-primary-action'),
              onTap: onPrimary,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(primaryIcon, color: colors.gold, size: 18),
                      const SizedBox(width: 8),
                      AppButtonLabel(primaryLabel, color: colors.text),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyPrimaryAction extends StatelessWidget {
  const _SkyPrimaryAction({
    required this.style,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final _SkyActionStyle style;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, shape, padding) = switch (style) {
      _SkyActionStyle.pill => (
        colors.gold,
        colors.onGold,
        const StadiumBorder(),
        const EdgeInsets.symmetric(horizontal: 18),
      ),
      _SkyActionStyle.edge => (
        colors.nightPanel,
        colors.gold,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusField),
          side: BorderSide(color: colors.gold, width: kBorderWidth),
        ),
        const EdgeInsets.symmetric(horizontal: 15),
      ),
      _SkyActionStyle.minimal => (
        Colors.transparent,
        colors.gold,
        const StadiumBorder(),
        const EdgeInsets.symmetric(horizontal: 8),
      ),
      _SkyActionStyle.dock => throw StateError('Dock has its own action'),
    };
    return DecoratedBox(
      key: const Key('sky-primary-action-shadow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusPill),
        boxShadow: _skyFabNavyShadow(colors),
      ),
      child: Tooltip(
        message: label,
        child: Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('sky-primary-action'),
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: SizedBox(
                height: style == _SkyActionStyle.minimal ? 42 : 48,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: foreground, size: 18),
                    const SizedBox(width: 8),
                    AppButtonLabel(label, color: foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyBackToTopButton extends StatelessWidget {
  const _SkyBackToTopButton({
    required this.style,
    required this.tooltip,
    required this.onTap,
  });

  final _SkyActionStyle style;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (style == _SkyActionStyle.pill) {
      const shape = CircleBorder();
      return DecoratedBox(
        key: const Key('sky-back-to-top-shadow'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _skyFabNavyShadow(colors),
        ),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: colors.gold,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('sky-back-to-top-button'),
              onTap: onTap,
              customBorder: shape,
              child: SizedBox.square(
                dimension: 32,
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: colors.onGold,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final minimal = style == _SkyActionStyle.minimal;
    final edge = style == _SkyActionStyle.edge;
    final shape = edge
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
          )
        : CircleBorder(
            side: minimal
                ? BorderSide.none
                : BorderSide(color: colors.nightBorder, width: kBorderWidth),
          );
    return Tooltip(
      message: tooltip,
      child: Material(
        color: minimal ? Colors.transparent : colors.nightPanel,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('sky-back-to-top-button'),
          onTap: onTap,
          customBorder: shape,
          child: SizedBox.square(
            dimension: minimal ? 40 : 44,
            child: Icon(
              Icons.keyboard_arrow_up,
              color: minimal ? colors.muted : colors.gold,
              size: 22,
            ),
          ),
        ),
      ),
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
    required this.badgesFor,
    required this.query,
    required this.menuController,
    required this.onOpenStar,
    required this.onOpenHabit,
    required this.onNavigateTo,
    required this.onShareEntry,
    required this.onEditStar,
    required this.onDeleteStar,
    required this.onLightStar,
    required this.onHabitToday,
    required this.onEditHabit,
    required this.onDeleteHabit,
    required this.scrollController,
  });

  final bool hasAnyEntries;
  final List<_SkyEntry> entries;
  final Map<int, Project> projectsById;
  final Map<DateTime, int> Function(int habitId) countsByDayFor;
  final CardBadges Function(_SkyEntry entry) badgesFor;
  final String query;
  final SearchCardMenuController menuController;
  final void Function(_SkyEntry entry) onOpenStar;
  final void Function(Habit habit) onOpenHabit;
  final ValueChanged<SkyNavigationTarget> onNavigateTo;
  final ValueChanged<_SkyEntry> onShareEntry;
  final ValueChanged<Star> onEditStar;
  final ValueChanged<Star> onDeleteStar;
  final ValueChanged<Star> onLightStar;
  final ValueChanged<Habit> onHabitToday;
  final ValueChanged<Habit> onEditHabit;
  final ValueChanged<Habit> onDeleteHabit;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (!hasAnyEntries) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            child: Text(
              strings.skyEmptyStars,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            child: Text(
              strings.noSearchResultsStars,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
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
          badges: badgesFor(entry),
          pulsarLit: entry.habit == null
              ? true
              : isHabitLit(entry.habit!, habitCounts),
          menuController: menuController,
          onTap: open,
          onNavigateTo: navigateTo,
          kindAction: _kindAction(context, entry, habitCounts),
          onShare: entry.kind != StarKind.dead && entry.kind != StarKind.nascent
              ? () => onShareEntry(entry)
              : null,
          onEdit: entry.kind == StarKind.dead
              ? null
              : entry.star != null
              ? () => onEditStar(entry.star!)
              : () => onEditHabit(entry.habit!),
          onDelete: entry.kind == StarKind.dead
              ? null
              : entry.star != null
              ? () => onDeleteStar(entry.star!)
              : () => onDeleteHabit(entry.habit!),
        );
        return StaggeredEntrance(
          index: index,
          child: ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: card,
            ),
          ),
        );
      },
    );
  }
}

extension on _FlatList {
  /// The action particular to this kind of star, mirroring the star reader's
  /// bottom bar: light a goal, mark a habit done today, or bring a dead star
  /// back.
  SearchCardAction? _kindAction(
    BuildContext context,
    _SkyEntry entry,
    Map<DateTime, int> habitCounts,
  ) {
    final strings = context.strings;
    if (entry.kind == StarKind.dead) {
      return SearchCardAction(
        icon: Icons.model_training,
        label: strings.actionReignite,
        onTap: () => entry.star != null
            ? onEditStar(entry.star!)
            : onEditHabit(entry.habit!),
      );
    }
    if (entry.star != null && !entry.star!.isLit) {
      return SearchCardAction(
        icon: Icons.power_settings_new_rounded,
        label: strings.completeActivityAction,
        onTap: () => onLightStar(entry.star!),
      );
    }
    final habit = entry.habit;
    if (habit != null) {
      final now = DateTime.now();
      final done = habitCounts.containsKey(
        DateTime(now.year, now.month, now.day),
      );
      final isStepper =
          habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1;
      return SearchCardAction(
        icon: isStepper
            ? Icons.add_circle_outline_rounded
            : Icons.local_fire_department_rounded,
        label: isStepper
            ? strings.habitProgressToday(
                habitDailyProgress(habit, habitCounts),
                habit.targetPerPeriod,
              )
            : (done
                  ? strings.undoCompletionAction
                  : strings.completeActivityAction),
        onTap: () => onHabitToday(habit),
      );
    }
    return null;
  }
}

class _SearchStarCard extends StatelessWidget {
  const _SearchStarCard({
    required this.entry,
    required this.project,
    required this.query,
    required this.badges,
    required this.pulsarLit,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
    this.kindAction,
    this.onShare,
    this.onEdit,
    this.onDelete,
  });

  /// The action particular to this kind of star, right after "open".
  final SearchCardAction? kindAction;

  final _SkyEntry entry;
  final Project? project;
  final String query;
  final CardBadges badges;
  final bool pulsarLit;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback? onNavigateTo;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final kind = entry.kind;
    final description = entry.description;
    final normalizedQuery = query.trim().toLowerCase();
    final descriptionMatched =
        normalizedQuery.isNotEmpty &&
        (description?.toLowerCase().contains(normalizedQuery) ?? false);
    final eyebrow = kind.label(strings);
    final actions = <SearchCardAction>[
      ?kindAction,
      if (onShare != null)
        SearchCardAction(
          icon: Icons.share_outlined,
          label: strings.starQuickLookShareAction,
          onTap: onShare!,
          group: 1,
        ),
      if (onNavigateTo != null)
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: strings.actionFly,
          onTap: onNavigateTo!,
          group: 2,
        ),
      if (onEdit != null)
        SearchCardAction(
          icon: Icons.edit_rounded,
          label: strings.starQuickLookEditAction,
          onTap: onEdit!,
          group: 2,
        ),
      if (onDelete != null)
        SearchCardAction(
          icon: Icons.delete_outline_rounded,
          label: strings.archiveAction,
          onTap: onDelete!,
          group: 2,
        ),
    ];
    return SearchResultCard(
      preserveMenuOnAction: true,
      menuId: entry.star == null
          ? 'habit:${entry.habit!.id}'
          : 'star:${entry.star!.id}',
      menuController: menuController,
      onTap: onTap,
      baseBodyHeight: SearchResultCard.bodyHeightFor(badges),
      visual: SearchStarVisual(kind: kind, pulsarLit: pulsarLit),
      content: SearchCardTextContent(
        eyebrow: eyebrow,
        archivedOriginalKind: kind == StarKind.dead
            ? entry.star?.originalKind ?? StarKind.pulsar
            : null,
        eyebrowColor: starKindColor(kind, context.colors, lit: pulsarLit),
        title: entry.title,
        breadcrumb: project == null
            ? null
            : '${project!.area.displayName(strings)} → ${project!.name}',
        description: descriptionMatched ? description : null,
        descriptionMatched: descriptionMatched,
        badges: badges,
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
    required this.badges,
    required this.shape,
    required this.menuController,
    required this.onTap,
    required this.onNavigateTo,
    required this.onAddStar,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final Project project;
  final CardBadges badges;
  final ConstellationShape? shape;
  final SearchCardMenuController menuController;
  final VoidCallback onTap;
  final VoidCallback onNavigateTo;
  final VoidCallback onAddStar;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SearchResultCard(
      preserveMenuOnAction: true,
      menuId: 'project:${project.id}',
      menuController: menuController,
      onTap: onTap,
      baseBodyHeight: SearchResultCard.bodyHeightFor(badges),
      visual: SearchConstellationVisual(shape: shape),
      content: SearchCardTextContent(
        eyebrow: strings.projectLabel,
        eyebrowColor: context.colors.gold,
        title: project.displayName,
        breadcrumb: project.area.displayName(strings),
        badges: badges,
      ),
      actions: [
        SearchCardAction(
          icon: Icons.auto_awesome,
          label: '+ Stella',
          onTap: onAddStar,
        ),
        SearchCardAction(
          icon: Icons.share_outlined,
          label: 'Condividi',
          onTap: onShare,
          group: 1,
        ),
        SearchCardAction(
          icon: Icons.navigation,
          label: 'Vola',
          onTap: onNavigateTo,
          group: 2,
        ),
        SearchCardAction(
          icon: Icons.edit_outlined,
          label: 'Modifica',
          onTap: onEdit,
          group: 2,
        ),
        SearchCardAction(
          icon: Icons.delete_outline,
          label: 'Elimina',
          onTap: onDelete,
          group: 2,
        ),
      ],
    );
  }
}
