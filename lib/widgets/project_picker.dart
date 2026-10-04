import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../screens/new_project_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../utils/date_format.dart';
import '../utils/icon_for_slug.dart';
import 'area_filter_sheet.dart';
import 'date_range_filter_sheet.dart';
import 'sort_filter_sheet.dart';
import 'staggered_entrance.dart';

class _CreateNewProject {
  const _CreateNewProject();
}

/// Picks an existing constellation, or creates a new one inline via
/// [NewProjectScreen].
///
/// Always lists every constellation across every area. [area] is only an
/// optional initial value for the complete editor opened by "New"; it never
/// narrows this picker, otherwise returning here after one choice can trap
/// the user inside that constellation's area.
Future<Project?> pickProject(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository, {
  LifeArea? area,
}) async {
  final result = await _pickProjectFlat(
    context,
    repository,
    starsShapeRepository,
  );
  if (!context.mounted) return null;
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

Future<Object?> _pickProjectFlat(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository,
) {
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showFixedAppSheet<Object>(
    context: context,
    builder: (sheetContext) {
      return _FlatProjectPickerSheet(
        projects: repository.getAll(),
        starsShapeRepository: starsShapeRepository,
        sheetHeight: sheetHeight,
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
    required this.sheetHeight,
  });

  final List<Project> projects;
  final StarsShapeRepository starsShapeRepository;
  final double sheetHeight;

  @override
  State<_FlatProjectPickerSheet> createState() =>
      _FlatProjectPickerSheetState();
}

class _FlatProjectPickerSheetState extends State<_FlatProjectPickerSheet> {
  String _query = '';
  Set<LifeArea> _areaFilter = {...LifeArea.values};
  DateTimeRange? _dateRangeFilter;
  DateRangePreset _dateRangePreset = DateRangePreset.allTime;
  SortField _sortField = SortField.date;
  SortDirection _sortDirection = SortDirection.descending;

  List<Project> get _filtered {
    final query = _query.trim().toLowerCase();
    var projects = widget.projects
        .where((project) => _areaFilter.contains(project.area))
        .where((project) {
          final range = _dateRangeFilter;
          return range == null || _isWithinRange(project.createdAt, range);
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
      _sortDirection != SortDirection.descending;
  bool get _hasFilters =>
      _isAreaFilterNarrowed || _dateRangeFilter != null || _isSortNonDefault;

  int _compareProjects(Project a, Project b) {
    final ascending = switch (_sortField) {
      SortField.date => a.createdAt.compareTo(b.createdAt),
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
    );
    if (result == null || !mounted) return;
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
    if (result == null || !mounted) return;
    setState(() {
      _sortField = result.field;
      _sortDirection = result.direction;
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
  });

  Future<void> _openFilters() async {
    final strings = context.strings;
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, refresh) => _ProjectFiltersSheet(
          buttons: [
            _ProjectFilterButton(
              icon: Icons.tune,
              active: _isAreaFilterNarrowed,
              label: _isAreaFilterNarrowed
                  ? strings.activeAreasCount(_areaFilter.length)
                  : strings.areaFilterDefaultLabel,
              onTap: () async {
                await _openAreaFilter();
                refresh(() {});
              },
            ),
            _ProjectFilterButton(
              icon: Icons.calendar_month,
              active: _dateRangeFilter != null,
              label: _dateLabel(strings),
              onTap: () async {
                await _openDateRangeFilter();
                refresh(() {});
              },
            ),
            _ProjectFilterButton(
              icon: Icons.sort,
              active: _isSortNonDefault,
              label: _sortLabel(strings),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final filtered = _filtered;
    return SafeArea(
      child: SizedBox(
        height: widget.sheetHeight,
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
                      child: TextField(
                        onChanged: (value) => setState(() => _query = value),
                        style: TextStyle(color: colors.text, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: strings.searchHint,
                          prefixIcon: Icon(
                            Icons.search,
                            color: colors.muted,
                            size: 20,
                          ),
                        ),
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
              const SizedBox(height: 12),
              Expanded(
                child: ClipRect(
                  child: filtered.isEmpty
                      ? StaggeredEntrance(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
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
                      : ListView.separated(
                          shrinkWrap: false,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final project = filtered[index];
                            return StaggeredEntrance(
                              index: index + 3,
                              child: AppSheetAction(
                                icon: iconForSlug(project.iconSlug),
                                label: project.name,
                                onPressed: () =>
                                    Navigator.of(context).pop(project),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: AppButtonLabel(strings.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const _CreateNewProject()),
                      child: AppButtonLabel(strings.newAction),
                    ),
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

class _ProjectFilterButton extends StatelessWidget {
  const _ProjectFilterButton({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: selectableDecoration(colors, selected: active),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? colors.gold : colors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: AppButtonLabel(
                  label,
                  color: active ? colors.text : colors.muted,
                  fontSize: 11,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
