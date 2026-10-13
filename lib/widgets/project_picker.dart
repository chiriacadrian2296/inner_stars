import '../models/display_text.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/sky_date_field.dart';
import '../screens/new_project_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../utils/date_format.dart';
import '../utils/icon_for_slug.dart';
import 'app_choice_chip.dart';
import 'app_field.dart' show AppSearchField;
import 'area_filter_sheet.dart';
import 'date_range_filter_sheet.dart';
import 'filter_button.dart';
import 'results_count_row.dart';
import 'sort_filter_sheet.dart';
import 'staggered_entrance.dart';

class _CreateNewProject {
  const _CreateNewProject();
}

class _ClearSelection {
  const _ClearSelection();
}

/// Picks an existing constellation, or creates a new one inline via
/// [NewProjectScreen]. With [allowCreate] off it only lists what exists: no
/// "New" button.
///
/// Always lists every constellation across every area. [area] is only an
/// optional initial value for the complete editor opened by "New"; it never
/// narrows this picker, otherwise returning here after one choice can trap
/// the user inside that constellation's area.
///
/// One tap on a row picks it and closes the sheet, and a Reset button (when
/// [onCleared] is given) clears the current choice. [selected] is shown as
/// already chosen. (The Sky's constellation filter, which takes several, is
/// [pickProjectFilter].)
Future<Project?> pickProject(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository, {
  LifeArea? area,
  bool allowCreate = true,
  Project? selected,
  VoidCallback? onCleared,
}) async {
  final result = await _pickProjectFlat(
    context,
    repository,
    starsShapeRepository,
    allowCreate: allowCreate,
    initialId: selected?.id,
    allowClear: onCleared != null,
  );
  if (!context.mounted) return null;
  if (result is _ClearSelection) {
    onCleared?.call();
    return null;
  }
  if (result is Project) return result;
  if (result is _CreateNewProject) {
    return Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: repository,
          starsShapeRepository: starsShapeRepository,
          presetArea: area,
        ),
      ),
    );
  }
  return null;
}

/// The Sky's constellation filter: a two-column chip list where any number of
/// constellations can be chosen, then applied. Nothing chosen means no
/// filter (every constellation shows). Returns the chosen ids (empty for no
/// filter), or null if dismissed without applying.
Future<Set<int>?> pickProjectFilter(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository, {
  required Set<int> selected,
  FilterPreview<Set<int>>? preview,
}) async {
  final result = await _pickProjectFlat(
    context,
    repository,
    starsShapeRepository,
    allowCreate: false,
    initialId: null,
    allowClear: false,
    filterIds: selected,
    preview: preview,
  );
  return result is _ProjectIdsChosen ? result.ids : null;
}

class _ProjectIdsChosen {
  const _ProjectIdsChosen(this.ids);

  final Set<int> ids;
}

Future<Object?> _pickProjectFlat(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository, {
  required bool allowCreate,
  required int? initialId,
  required bool allowClear,
  Set<int>? filterIds,
  FilterPreview<Set<int>>? preview,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showFixedAppSheet<Object>(
    context: context,
    builder: (sheetContext) {
      return _FlatProjectPickerSheet(
        projects: repository.getAll(),
        starsShapeRepository: starsShapeRepository,
        maxHeight: maxHeight,
        allowCreate: allowCreate,
        initialId: initialId,
        allowClear: allowClear,
        filterIds: filterIds,
        preview: preview,
      );
    },
  );
}

/// Every constellation across every area in one searchable list, each
/// tagged with its area. Picking one, same as creating one, resolves the
/// star form's supernova from [Project.area].
class _FlatProjectPickerSheet extends StatefulWidget {
  const _FlatProjectPickerSheet({
    required this.projects,
    required this.starsShapeRepository,
    required this.maxHeight,
    required this.allowCreate,
    required this.initialId,
    required this.allowClear,
    this.filterIds,
    this.preview,
  });

  /// Filter mode (the Sky's constellation filter) when set: the constellations
  /// chosen so far; the sheet is then a multi-select chip list with Apply.
  /// Unset, it is the one-tap picker.
  final Set<int>? filterIds;

  /// Filter mode only: previews the cards the pending choice would leave.
  final FilterPreview<Set<int>>? preview;
  final List<Project> projects;
  final StarsShapeRepository starsShapeRepository;
  final double maxHeight;
  final bool allowCreate;
  final int? initialId;
  final bool allowClear;

  @override
  State<_FlatProjectPickerSheet> createState() =>
      _FlatProjectPickerSheetState();
}

class _FlatProjectPickerSheetState extends State<_FlatProjectPickerSheet> {
  final _queryController = TextEditingController();

  // Read from the controller, not mirrored into state: typing then rebuilds
  // only the list (see [build]) instead of the whole sheet on every key.
  String get _query => _queryController.text;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  late Set<int> _selectedIds = {...?widget.filterIds};
  Set<LifeArea> _areaFilter = {...LifeArea.values};
  DateTimeRange? _dateRangeFilter;
  DateRangePreset _dateRangePreset = DateRangePreset.allTime;
  SortField _sortField = SortField.date;
  SortDirection _sortDirection = SortDirection.descending;
  SkyDateField _rangeDateField = SkyDateField.created;
  SkyDateField _sortDateField = SkyDateField.created;

  /// Projects have no "occurred" date, so only these two apply here.
  static const _dateFields = [SkyDateField.created, SkyDateField.modified];

  DateTime _dateOf(Project project, SkyDateField field) =>
      field == SkyDateField.modified ? project.lastModified : project.createdAt;

  List<Project> get _filtered {
    final query = _query.trim().toLowerCase();
    var projects = widget.projects
        .where((project) => _areaFilter.contains(project.area))
        .where((project) {
          final range = _dateRangeFilter;
          return range == null ||
              _isWithinRange(_dateOf(project, _rangeDateField), range);
        })
        .where(
          (project) =>
              query.isEmpty || project.name.toLowerCase().contains(query),
        )
        .toList();
    projects.sort(_compareProjects);
    return projects;
  }

  bool get _isAreaFilterNarrowed =>
      _areaFilter.length != LifeArea.values.length;
  bool get _isSortNonDefault =>
      _sortField != SortField.date ||
      _sortDirection != SortDirection.descending ||
      _sortDateField != SkyDateField.created;
  bool get _hasFilters =>
      _isAreaFilterNarrowed || _dateRangeFilter != null || _isSortNonDefault;

  int _compareProjects(Project a, Project b) {
    final ascending = switch (_sortField) {
      SortField.date => _dateOf(
        a,
        _sortDateField,
      ).compareTo(_dateOf(b, _sortDateField)),
      SortField.intensity => _shapePointCount(a).compareTo(_shapePointCount(b)),
      SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return _sortDirection == SortDirection.ascending ? ascending : -ascending;
  }

  int _shapePointCount(Project project) {
    final shapeId = project.starsShapeId;
    if (shapeId == null) return 0;
    return widget.starsShapeRepository.getById(shapeId)?.shape.points.length ??
        0;
  }

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

  Future<void> _openAreaFilter() async {
    final result = await showAreaFilterSheet(
      context,
      selectedAreas: _areaFilter,
    );
    if (result != null && mounted) setState(() => _areaFilter = result);
  }

  Future<void> _openDateRangeFilter() async {
    final result = await showDateRangeFilterSheet(
      context,
      initialRange: _dateRangeFilter,
      initialPreset: _dateRangePreset,
      initialField: _rangeDateField,
      availableFields: _dateFields,
    );
    if (result == null || !mounted) return;
    setState(() {
      _dateRangeFilter = result.range;
      _dateRangePreset = result.preset;
      _rangeDateField = result.field;
    });
  }

  Future<void> _openSortFilter() async {
    final result = await showSortFilterSheet(
      context,
      initialField: _sortField,
      initialDirection: _sortDirection,
      initialDateField: _sortDateField,
      availableDateFields: _dateFields,
    );
    if (result == null || !mounted) return;
    setState(() {
      _sortField = result.field;
      _sortDirection = result.direction;
      _sortDateField = result.dateField;
    });
  }

  String _dateLabel(AppStrings strings) {
    final range = _dateRangeFilter;
    if (range == null) return strings.dateRangeFilterSectionTitle;
    final needsYear =
        range.start.year != DateTime.now().year ||
        range.end.year != DateTime.now().year;
    final format = needsYear ? formatShortDateWithYear : formatShortDate;
    return '${format(range.start)} - ${format(range.end)}';
  }

  /// Which date the range applies to, under the button — only while a range
  /// is set and it isn't the default (creation).
  String? _dateCaption(AppStrings strings) =>
      _dateRangeFilter == null || _rangeDateField == SkyDateField.created
      ? null
      : _rangeDateField.label(strings);

  /// Which date "sort by date" uses, under the button, when not the default.
  String? _sortCaption(AppStrings strings) =>
      _sortField != SortField.date || _sortDateField == SkyDateField.created
      ? null
      : _sortDateField.label(strings);

  String _sortLabel(AppStrings strings) {
    if (!_isSortNonDefault) return strings.sortButtonDefaultLabel;
    final field = switch (_sortField) {
      SortField.date => strings.sortFieldDate,
      SortField.intensity => strings.sortFieldIntensity,
      SortField.name => strings.sortFieldName,
    };
    return '$field ${_sortDirection == SortDirection.ascending ? '↑' : '↓'}';
  }

  void _resetFilters() => setState(() {
    _areaFilter = {...LifeArea.values};
    _dateRangeFilter = null;
    _dateRangePreset = DateRangePreset.allTime;
    _sortField = SortField.date;
    _sortDirection = SortDirection.descending;
    _rangeDateField = SkyDateField.created;
    _sortDateField = SkyDateField.created;
  });

  Future<void> _openFilters() async {
    final strings = context.strings;
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, refresh) => _ProjectFiltersSheet(
          buttons: [
            FilterButton(
              icon: Icons.flare,
              horizontal: true,
              tooltip: strings.filterAreasAction,
              active: _isAreaFilterNarrowed,
              label: _isAreaFilterNarrowed
                  ? strings.activeAreasCount(_areaFilter.length)
                  : strings.areaFilterDefaultLabel,
              onTap: () async {
                await _openAreaFilter();
                refresh(() {});
              },
            ),
            FilterButton(
              icon: Icons.calendar_month,
              horizontal: true,
              tooltip: strings.filterDateRangeAction,
              active: _dateRangeFilter != null,
              label: _dateLabel(strings),
              caption: _dateCaption(strings),
              onTap: () async {
                await _openDateRangeFilter();
                refresh(() {});
              },
            ),
            FilterButton(
              icon: Icons.sort,
              horizontal: true,
              tooltip: strings.sortAction,
              active: _isSortNonDefault,
              label: _sortLabel(strings),
              caption: _sortCaption(strings),
              onTap: () async {
                await _openSortFilter();
                refresh(() {});
              },
            ),
          ],
          canReset: _hasFilters,
          onReset: () {
            _resetFilters();
            refresh(() {});
          },
        ),
      ),
    );
  }

  /// Sized for every constellation, not just the filtered ones, so the sheet
  /// doesn't jump while typing: the chrome (title, search, buttons, padding)
  /// plus one row per constellation, capped at [_FlatProjectPickerSheet.maxHeight].
  double _sheetHeight(BuildContext context) {
    final chrome = _showPreview ? 284.0 : 248.0;
    const rowHeight = 48.0;
    const gap = 10.0;
    const emptyList = 72.0;
    final rows = _instantPick
        ? widget.projects.length
        : (widget.projects.length + 1) ~/ 2;
    final list = rows == 0 ? emptyList : rows * rowHeight + (rows - 1) * gap;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return (chrome + list + bottomInset).clamp(0.0, widget.maxHeight);
  }

  bool get _instantPick => widget.filterIds == null;

  bool get _showPreview => !_instantPick && widget.preview != null;

  bool get _canApply => !setEquals(_selectedIds, widget.filterIds);

  // The preview counts the whole sky, which is far too much work to repeat on
  // every keystroke of the search box — and typing never changes it, only the
  // selection does. So it is recomputed only when the selection differs from
  // the one it was last computed for.
  Set<int>? _previewSelection;
  Widget? _previewRow;

  Widget _previewRowFor(FilterPreview<Set<int>> preview) {
    final cached = _previewRow;
    if (cached != null && setEquals(_previewSelection, _selectedIds)) {
      return cached;
    }
    _previewSelection = {..._selectedIds};
    return _previewRow = preview.rowFor(_selectedIds);
  }

  void _apply() => Navigator.of(context).pop(_ProjectIdsChosen(_selectedIds));

  /// The filter's chip: tapping toggles it; Apply commits.
  Widget _projectChip(Project project) => AppChoiceChip(
    icon: iconForSlug(project.iconSlug),
    label: project.displayName,
    selected: _selectedIds.contains(project.id),
    onPressed: () => setState(() {
      if (!_selectedIds.remove(project.id)) _selectedIds.add(project.id);
    }),
    expand: true,
  );

  /// One tap chooses it and closes the sheet, same as the area picker.
  Widget _projectRow(Project project) => AppSheetAction(
    icon: iconForSlug(project.iconSlug),
    label: project.displayName,
    uppercase: false,
    selected: project.id == widget.initialId,
    onPressed: () => Navigator.of(context).pop(project),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return SafeArea(
      child: SizedBox(
        height: _sheetHeight(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggeredEntrance(
                index: 0,
                child: AppSheetTitle(strings.projectLabel),
              ),
              const SizedBox(height: 20),
              StaggeredEntrance(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: AppSearchField(
                        controller: _queryController,
                        hintText: strings.searchProjectsHint,
                        onChanged: (_) {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ProjectFiltersTrigger(
                      active: _hasFilters,
                      tooltip: strings.filtersAction,
                      onTap: _openFilters,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRect(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _queryController,
                    builder: (context, _, _) {
                      final filtered = _filtered;
                      return filtered.isEmpty
                          ? StaggeredEntrance(
                              index: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    _query.isEmpty
                                        ? strings.noProjectsYet
                                        : strings.noSearchResults,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : _instantPick
                          ? ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  StaggeredEntrance(
                                    index: index + 3,
                                    child: _projectRow(filtered[index]),
                                  ),
                            )
                          : ListView.separated(
                              itemCount: (filtered.length + 1) ~/ 2,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, row) => Row(
                                children: [
                                  for (var col = 0; col < 2; col++) ...[
                                    if (col > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: row * 2 + col < filtered.length
                                          ? StaggeredEntrance(
                                              index: row + col + 3,
                                              axis: Axis.horizontal,
                                              child: _projectChip(
                                                filtered[row * 2 + col],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                    },
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _queryController,
                builder: (context, _, _) {
                  // A search with no matches hides the count: it describes
                  // the whole sky, not what is being searched for here.
                  final noMatches =
                      _query.trim().isNotEmpty && _filtered.isEmpty;
                  if (_showPreview && !noMatches) {
                    return Column(
                      children: [
                        const SizedBox(height: 20),
                        Align(child: _previewRowFor(widget.preview!)),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox(height: 24);
                },
              ),
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!_instantPick) ...[
                      TextButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => setState(() => _selectedIds = {}),
                        child: AppButtonLabel(strings.clearFilterAction),
                      ),
                      if (widget.allowCreate)
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pop(const _CreateNewProject()),
                          child: AppButtonLabel(strings.newAction),
                        ),
                      ElevatedButton(
                        onPressed: _canApply ? _apply : null,
                        child: AppButtonLabel(strings.applyFilterAction),
                      ),
                    ] else ...[
                      if (widget.allowCreate)
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pop(const _CreateNewProject()),
                          child: AppButtonLabel(strings.newAction),
                        ),
                      if (widget.allowClear)
                        ElevatedButton(
                          onPressed: widget.initialId == null
                              ? null
                              : () =>
                                    Navigator.of(context)
                                        .pop(const _ClearSelection()),
                          child: AppButtonLabel(strings.clearFilterAction),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectFiltersTrigger extends StatelessWidget {
  const _ProjectFiltersTrigger({
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

class _ProjectFiltersSheet extends StatelessWidget {
  const _ProjectFiltersSheet({
    required this.buttons,
    required this.canReset,
    required this.onReset,
  });

  final List<Widget> buttons;
  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSheetTitle(strings.filtersAction),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 10),
                Expanded(child: buttons[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: buttons[2]),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              child: ElevatedButton(
                onPressed: canReset ? onReset : null,
                child: AppButtonLabel(strings.clearFilterAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
