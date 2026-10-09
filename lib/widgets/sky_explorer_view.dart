import 'package:animated_toggle_switch/animated_toggle_switch.dart';
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
import '../models/star.dart';
import '../models/star_kind.dart';
import '../settings/settings_controller.dart';
import '../settings/sky_grid_size.dart';
import '../screens/area_detail_screen.dart';
import '../screens/constellation_screen.dart';
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
import '../utils/habit_stats.dart';
import '../utils/icon_for_slug.dart';
import '../utils/page_settled.dart';
import '../utils/project_card_info.dart';
import '../utils/star_card_info.dart';
import 'app_action_disc.dart';
import 'app_field.dart';
import 'filter_button.dart';
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
import 'sky_navigation_target.dart';
import 'sky_view_mode_button.dart';
import 'sort_filter_sheet.dart';
import 'staggered_entrance.dart';
import 'star_glyph.dart';

enum _SkyMode { supernovas, constellations, stars }

/// In-memory navigation state for Sky. Owned by Cosmo so opening a result,
/// flying to it, and later returning to Sky restores the exact working
/// context instead of constructing a fresh browser every time.
class SkyExplorerSession {
  int modeIndex = 0;
  String query = '';
  Set<StarKind> kindFilter = {...kListableStarKinds};
  Set<LifeArea> areaFilter = {...LifeArea.values};

  /// Stars only: the one constellation to show stars from (null = all).
  int? projectFilterId;
  DateTimeRange? dateRangeFilter;
  DateRangePreset dateRangePreset = DateRangePreset.allTime;
  SortField sortField = SortField.date;
  SortDirection sortDirection = SortDirection.descending;
  final scrollOffsets = <int, double>{};
  Object? openCardMenuId;

  /// The detail page (area, constellation or star) its "take me there" was
  /// tapped on: Sky reopens it on top of the browser next time, so flying to
  /// something from its page and coming back lands on that page again.
  SkyResume? resume;
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
/// mode gets the same search field, but each has its own set of filters
/// beside it: none in Supernovas (search runs alone — see
/// [_filteredSupernovaAreas]), area + date + sort in Constellations, area +
/// kind + date + sort in Stars. On a wide layout each filter is its own
/// button/sheet beside the search field; on a narrow one they're all
/// collected behind a single trigger instead (see [_ControlsTriggerButton]/
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

  /// See [SkyNavigationTarget] — called when a card's "take me there" button
  /// is tapped.
  final ValueChanged<SkyNavigationTarget> onNavigateTo;

  @override
  State<SkyExplorerView> createState() => _SkyExplorerViewState();
}

class _SkyExplorerViewState extends State<SkyExplorerView>
    with SingleTickerProviderStateMixin {
  late _SkyMode _mode;
  bool _modeReverse = false;
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
    });
    _saveSession();
    _modeAnimation.forward(from: 0);
  }

  /// Moves only one step in the same sequence as the segmented switch:
  /// Areas ↔ Constellations ↔ Stars.
  void _swipeMode(double horizontalVelocity) {
    const minimumVelocity = 180.0;
    if (horizontalVelocity.abs() < minimumVelocity) return;
    final direction = horizontalVelocity.isNegative ? 1 : -1;
    final rawIndex = _mode.index + direction;
    if (rawIndex < 0 || rawIndex >= _SkyMode.values.length) return;
    final nextIndex = rawIndex;
    _selectMode(_SkyMode.values[nextIndex]);
  }

  late final SearchCardMenuController _cardMenuController;
  late final List<ScrollController> _scrollControllers;
  late final SkyExplorerSession _session;

  /// Whether [_syncModeToTour] has already forced Supernovas out once.
  ///
  /// Guards it from doing so a second time — see its own doc comment for
  /// why a single correction is all it should ever make.
  bool _autoSwitchedModeForTour = false;
  late final TextEditingController _queryController;
  late String _query;
  // Filters model exactly what their sheets show: everything starts on,
  // and an empty set really means that nothing matches.
  late Set<StarKind> _kindFilter;
  late Set<LifeArea> _areaFilter;
  int? _projectFilterId;
  DateTimeRange? _dateRangeFilter;

  /// Which chip (if any) produced [_dateRangeFilter] — kept alongside it
  /// purely so a reopened sheet can still show the right chip highlighted
  /// instead of just "Custom". (The filter button itself always shows the
  /// actual span — see [_dateRangeButtonLabel] — rather than the preset's
  /// name, precisely so seeing it doesn't require opening the sheet.) See
  /// [DateRangePreset]'s own doc for why this can't just be recomputed from
  /// the range on demand.
  late DateRangePreset _dateRangePreset;

  /// Unlike the three filters above, sorting has no "off" state to default
  /// to empty — results are always in *some* order — so these two start at
  /// whatever this file's lists always used to be sorted by (newest first)
  /// rather than at a neutral placeholder.
  late SortField _sortField;
  late SortDirection _sortDirection;
  late List<Project> _projectsCache;
  late List<Star> _starsCache;
  late List<Habit> _habitsCache;
  late Map<int, List<Star>> _starsByProjectCache;
  late Map<int, Map<DateTime, int>> _completionCountsCache;

  late Map<int, List<HabitCompletion>> _completionsByHabitCache;
  late Map<int, ConstellationShape> _shapesByIdCache;

  void _refreshDataCache() {
    _projectsCache = widget.projectRepository.getAll();
    // A constellation deleted since the filter was set can't match anything.
    if (_projectFilterId != null &&
        !_projectsCache.any((p) => p.id == _projectFilterId)) {
      _projectFilterId = null;
    }
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
      ..query = _query
      ..kindFilter = {..._kindFilter}
      ..areaFilter = {..._areaFilter}
      ..projectFilterId = _projectFilterId
      ..dateRangeFilter = _dateRangeFilter
      ..dateRangePreset = _dateRangePreset
      ..sortField = _sortField
      ..sortDirection = _sortDirection
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

  List<Project> get _filteredAreaProjects =>
      _projectsCache.where((p) => _areaFilter.contains(p.area)).toList();

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
      for (final star in _starsCache)
        if (projectIds.contains(star.projectId)) _SkyEntry.fromStar(star),
      for (final habit in _habitsCache)
        if (projectIds.contains(habit.projectId)) _SkyEntry.fromHabit(habit),
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
      if (!_kindFilter.contains(e.kind)) {
        return false;
      }
      if (_projectFilterId != null &&
          (e.star?.projectId ?? e.habit!.projectId) != _projectFilterId) {
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
    _cardMenuController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    final session = _session = widget.session ?? SkyExplorerSession();
    final modeIndex = session.modeIndex < 0
        ? 0
        : session.modeIndex >= _SkyMode.values.length
        ? _SkyMode.values.length - 1
        : session.modeIndex;
    _mode = _SkyMode.values[modeIndex];
    _query = session.query;
    _queryController = TextEditingController(text: _query);
    _kindFilter = {...session.kindFilter};
    _areaFilter = {...session.areaFilter};
    _projectFilterId = session.projectFilterId;
    _dateRangeFilter = session.dateRangeFilter;
    _dateRangePreset = session.dateRangePreset;
    _sortField = session.sortField;
    _sortDirection = session.sortDirection;
    _refreshDataCache();
    _cardMenuController = SearchCardMenuController(
      initialOpenId: session.openCardMenuId,
    )..addListener(() => session.openCardMenuId = _cardMenuController.openId);
    _scrollControllers = List.generate(_SkyMode.values.length, (index) {
      final controller = ScrollController(
        initialScrollOffset: session.scrollOffsets[index] ?? 0,
      );
      controller.addListener(
        () => session.scrollOffsets[index] = controller.offset,
      );
      return controller;
    });
    final resume = session.resume;
    session.resume = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    if (mounted) setState(() {});
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
      streak: habitCurrentStreak(habit, counts),
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
  }) {
    final colors = context.colors;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: StaggeredEntrance(
            index: 0,
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      );
    }
    // Capped to the shared content column on wide layouts, like the lists.
    return ResponsiveContent(
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: skyGridColumnsFor(
              widget.settings.skyGridSizeStep,
              constraints.maxWidth - 40,
            ),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: kGalleryTileAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => StaggeredEntrance(
            index: index % 12,
            child: tile(items[index], () => onTap(index)),
          ),
        ),
      ),
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
      tile: (item, onTap) => GalleryAreaTile(data: item, onTap: onTap),
      onTap: (index) => _openArea(areas[index].area),
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
      tile: (item, onTap) => GalleryProjectTile(data: item, onTap: onTap),
      onTap: (index) => _openProject(projects[index].project),
    );
  }

  Widget _starsGrid(AppStrings strings) {
    final stars = [for (final entry in _filteredEntries) _starGridData(entry)];
    return _gridBody<GalleryStarData>(
      controller: _scrollControllers[2],
      items: stars,
      emptyText: strings.noSearchResultsStars,
      tile: (item, onTap) => GalleryStarTile(data: item, onTap: onTap),
      onTap: (index) => _openStarReader(stars[index].key),
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

  Future<void> _openNewConstellation(LifeArea area) async {
    final shapes = await StarsShapeRepository.create();
    if (!mounted) return;
    final project = await Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: shapes,
          presetArea: area,
        ),
      ),
    );
    _refreshAndRebuild();
    if (project != null && mounted) _announceConstellationCreated(project);
  }

  /// The search-level creation route deliberately has no area or
  /// constellation preselected: this is the one place that sees the whole
  /// sky, so the form's picker is the right place to choose where the new
  /// star belongs.
  Future<void> _createStar() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result is! StarFormResult) return;

    if (result.kind == StarKind.pulsar) {
      final habit = await widget.habitRepository.add(
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? 3,
        frequency: result.habitFrequency ?? HabitFrequency.daily,
        targetPerPeriod: result.habitTargetPerPeriod ?? 1,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
      );
      _refreshAndRebuild();
      if (mounted) _announcePulsarCreated(habit);
    } else {
      final star = await widget.starRepository.add(
        title: result.title,
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
  }

  Future<void> _createConstellation() async {
    final shapes = await StarsShapeRepository.create();
    if (!mounted) return;
    final project = await Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: shapes,
        ),
      ),
    );
    _refreshAndRebuild();
    if (project != null && mounted) _announceConstellationCreated(project);
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
        shareText: star.title,
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
        shareText: habit.title,
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
              shareText: project.name,
              fileName: 'constellation_${project.id}.png',
            ),
    );
  }

  ({IconData icon, String tooltip, VoidCallback onPressed})? get _modeAction =>
      switch (_mode) {
        _SkyMode.stars => (
          icon: Icons.add,
          tooltip: 'Aggiungi stella',
          onPressed: _createStar,
        ),
        _SkyMode.constellations => (
          icon: Icons.add,
          tooltip: 'Aggiungi costellazione',
          onPressed: _createConstellation,
        ),
        _SkyMode.supernovas => null,
      };

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
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? 3,
        frequency: result.habitFrequency ?? HabitFrequency.daily,
        targetPerPeriod: result.habitTargetPerPeriod ?? 1,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
      );
      _refreshAndRebuild();
      if (mounted) _announcePulsarCreated(habit);
      return;
    }
    final star = await widget.starRepository.add(
      title: result.title,
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
      shareText: project.name,
      fileName: 'constellation_${project.id}.png',
    );
  }

  Future<void> _deleteConstellation(Project project) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: 'Eliminare questa costellazione?',
      body: 'Verranno eliminati definitivamente stelle, pulsar, completamenti e foto. Questa azione non può essere annullata.',
      cancelLabel: strings.cancel,
      confirmLabel: strings.deleteStarAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed) return;
    final habitIds = await widget.habitRepository.deleteAllForProject(
      project.id,
    );
    for (final habitId in habitIds) {
      await widget.habitCompletionRepository.deleteAllForHabit(habitId);
    }
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
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? habit.intensity,
        frequency: result.habitFrequency ?? habit.frequency,
        targetPerPeriod: result.habitTargetPerPeriod ?? habit.targetPerPeriod,
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
      confirmLabel: strings.deleteStarAction,
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
      confirmLabel: strings.deleteStarAction,
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
    );
    if (result == null) return;
    setState(() => _areaFilter = result);
    _saveSession();
  }

  Future<void> _openProjectFilter() async {
    final picked = await pickProject(
      context,
      widget.projectRepository,
      widget.starsShapeRepository,
      allowCreate: false,
      selected: _projectsCache
          .where((p) => p.id == _projectFilterId)
          .firstOrNull,
      onCleared: () {
        setState(() => _projectFilterId = null);
        _saveSession();
      },
    );
    if (picked == null) return;
    setState(() => _projectFilterId = picked.id);
    _saveSession();
  }

  Future<void> _openKindFilter() async {
    final result = await showKindFilterSheet(
      context,
      selectedKinds: _kindFilter,
    );
    if (result == null) return;
    setState(() => _kindFilter = result);
    _saveSession();
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
    _saveSession();
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
    _saveSession();
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
  /// Every area starts selected; any smaller set, including none, is active.
  bool get _isAreaFilterNarrowed =>
      _areaFilter.length != LifeArea.values.length;

  bool get _isProjectFilterActive => _projectFilterId != null;

  /// The constellation button's own label — the picked constellation's name,
  /// or the neutral "Constellation" while none is picked.
  String _projectFilterButtonLabel(AppStrings strings) {
    final id = _projectFilterId;
    if (id == null) return strings.projectLabel;
    for (final project in _projectsCache) {
      if (project.id == id) return project.name;
    }
    return strings.projectLabel;
  }

  /// Same idea as [_isAreaFilterNarrowed], for [_kindFilter].
  bool get _isKindFilterNarrowed =>
      _kindFilter.length != kListableStarKinds.length;

  /// Whether any of the filters that actually apply to [_mode] right now is
  /// narrowed/non-default — lights up the mobile "Filtri" trigger button
  /// (see [_ControlsTriggerButton]) exactly when opening it would reveal at
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
      _projectFilterId = null;
      _kindFilter = {...kListableStarKinds};
      _dateRangeFilter = null;
      _dateRangePreset = DateRangePreset.allTime;
      _sortField = SortField.date;
      _sortDirection = SortDirection.descending;
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
      FilterButton(
        icon: Icons.calendar_month,
        active: _dateRangeFilter != null,
        label: _dateRangeButtonLabel(strings),
        tooltip: strings.filterDateRangeAction,
        horizontal: horizontal,
        onTap: () => wrap(_openDateRangeFilter),
      ),
      FilterButton(
        icon: Icons.sort,
        active: _isSortNonDefault,
        label: _sortButtonLabel(strings),
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
    _syncModeToTour(context);
    final allEntries = _mode == _SkyMode.stars
        ? _allEntries
        : const <_SkyEntry>[];
    final filteredEntries = _mode == _SkyMode.stars
        ? _filteredEntries
        : const <_SkyEntry>[];

    final action = _modeAction;
    return GestureDetector(
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
                        child: HintTarget(
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
                                child: AnimatedToggleSwitch<_SkyMode>.rolling(
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
                                      _SkyMode.supernovas => Icons.flare,
                                      _SkyMode.constellations => Icons.insights,
                                      _SkyMode.stars => Icons.star,
                                    },
                                    size: 20,
                                    color: value == _mode
                                        ? colors.night
                                        : colors.muted,
                                  ),
                                  style: ToggleStyle(
                                    backgroundColor: colors.nightPanel,
                                    indicatorColor: colors.gold,
                                    borderColor: colors.nightBorder,
                                    borderRadius: BorderRadius.circular(
                                      kRadiusField,
                                    ),
                                    indicatorBorderRadius:
                                        BorderRadius.circular(kRadiusField),
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
                            child: AppTextField(
                              controller: _queryController,
                              hintText: strings.searchHint,
                              onChanged: (value) {
                                _cardMenuController.closeAll();
                                setState(() => _query = value);
                                _saveSession();
                              },
                              prefixIcon: Icon(
                                Icons.search,
                                color: colors.muted,
                                size: 20,
                              ),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: strings.clearSearchTooltip,
                                      onPressed: () {
                                        _queryController.clear();
                                        _cardMenuController.closeAll();
                                        setState(() => _query = '');
                                        _saveSession();
                                      },
                                      icon: Icon(
                                        Icons.close,
                                        color: colors.muted,
                                        size: 20,
                                      ),
                                    ),
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
                                  child: _ControlsTriggerButton(
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
          Positioned(
            right: 20,
            bottom: 20,
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: RotationTransition(
                    turns: Tween<double>(
                      begin: _modeReverse ? 0.12 : -0.12,
                      end: 0,
                    ).animate(animation),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.84,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                ),
                child: action == null
                    ? SizedBox.shrink(key: ValueKey('sky-fab-${_mode.name}'))
                    : TweenAnimationBuilder<double>(
                        key: ValueKey('sky-fab-${_mode.name}'),
                        tween: Tween(begin: 1, end: 0),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, glow, child) => DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: goldGlow(
                              colors,
                              strength: 0.55 * glow,
                              size: 64,
                            ),
                          ),
                          child: child,
                        ),
                        child: AppActionDisc(
                          icon: action.icon,
                          boldPlus: true,
                          onPressed: action.onPressed,
                          heroTag: 'sky-search-${_mode.name}-action',
                          tooltip: action.tooltip,
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
          icon: Icons.edit_outlined,
          label: 'Vision',
          onTap: onVision,
        ),
        SearchCardAction(
          icon: Icons.photo_library_outlined,
          label: 'Moodboard',
          onTap: onMoodboard,
        ),
        SearchCardAction(
          icon: Icons.auto_stories_outlined,
          label: 'Riflessioni',
          onTap: onReflections,
        ),
        SearchCardAction(
          icon: Icons.insights,
          label: '+ Costellazione',
          onTap: onNewConstellation,
        ),
        SearchCardAction(
          icon: Icons.navigation,
          label: 'Vola',
          onTap: onNavigateTo,
        ),
      ],
    );
  }
}

/// The one icon button beside the search field. It opens [_ControlsSheet],
/// and lights up (gold ring, same "lit vs dark" rule as every other filter
/// button via [selectableDecoration]) whenever a real filter is applied or the
/// sort differs from its default. The list/grid choice never lights it: that
/// is a way of looking, not a narrowing of what's shown.
class _ControlsTriggerButton extends StatelessWidget {
  const _ControlsTriggerButton({
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
            alignment: Alignment.center,
            decoration: selectableDecoration(colors, selected: active),
            child: Icon(
              Icons.filter_list,
              size: 20,
              color: active ? colors.gold : colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// [_ControlsTriggerButton]'s own destination, in three sections: View
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
              child: AppSheetTitle(strings.skyViewModeTitle),
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
              Row(
                children: [
                  Expanded(child: sortButton!),
                  const Spacer(),
                ],
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
        label: strings.actionLight,
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
            : (done ? strings.actionTurnOff : strings.actionLight),
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
    final eyebrow = kind == StarKind.dead && entry.habit != null
        ? '${kind.label(strings)} · ${strings.formerPulsarLabel}'
        : kind.label(strings);
    final actions = <SearchCardAction>[
      ?kindAction,
      if (onShare != null)
        SearchCardAction(
          icon: Icons.share_outlined,
          label: strings.starQuickLookShareAction,
          onTap: onShare!,
        ),
      if (onNavigateTo != null)
        SearchCardAction(
          icon: Icons.navigation_rounded,
          label: strings.actionFly,
          onTap: onNavigateTo!,
        ),
      if (onEdit != null)
        SearchCardAction(
          icon: Icons.edit_rounded,
          label: strings.starQuickLookEditAction,
          onTap: onEdit!,
        ),
      if (onDelete != null)
        SearchCardAction(
          icon: Icons.delete_outline_rounded,
          label: strings.deleteStarAction,
          onTap: onDelete!,
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
        title: project.name,
        breadcrumb: project.area.displayName(strings),
        badges: badges,
      ),
      actions: [
        SearchCardAction(icon: Icons.star, label: '+ Stella', onTap: onAddStar),
        SearchCardAction(
          icon: Icons.share_outlined,
          label: 'Condividi',
          onTap: onShare,
        ),
        SearchCardAction(
          icon: Icons.navigation,
          label: 'Vola',
          onTap: onNavigateTo,
        ),
        SearchCardAction(
          icon: Icons.edit_outlined,
          label: 'Modifica',
          onTap: onEdit,
        ),
        SearchCardAction(
          icon: Icons.delete_outline,
          label: 'Elimina',
          onTap: onDelete,
        ),
      ],
    );
  }
}
