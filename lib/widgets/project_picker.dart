import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../screens/new_project_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'area_tag.dart';
import 'project_tag.dart';
import 'staggered_entrance.dart';

class _CreateNewProject {
  const _CreateNewProject();
}

/// Picks an existing constellation, or creates a new one inline via
/// [NewProjectScreen].
///
/// - [area] already chosen (see [StarFormScreen]'s own supernova field,
///   picked separately via [pickArea]): skips straight to that area's own
///   constellations — no area step, and no way to change it from inside
///   this picker any more. Choosing the supernova is that other field's
///   job now, not this one's.
/// - [area] not given: lists every constellation across every area in one
///   flat, searchable list instead of forcing an area choice first. Only
///   asks which area to use (via [pickArea]) if "create new" is actually
///   picked, since [NewProjectScreen] needs one either way. Either path's
///   result carries its own [Project.area], which is exactly what lets the
///   caller fill its own supernova field in from a constellation picked
///   this way.
Future<Project?> pickProject(
  BuildContext context,
  ProjectRepository repository,
  StarsShapeRepository starsShapeRepository, {
  LifeArea? area,
}) async {
  final Object? result;
  if (area != null) {
    result = await _pickProjectInArea(context, repository, area);
  } else {
    result = await _pickProjectFlat(context, repository);
  }
  if (!context.mounted) return null;
  if (result is Project) return result;
  if (result is _CreateNewProject) {
    final resolvedArea = area ?? await pickArea(context);
    if (resolvedArea == null || !context.mounted) return null;
    return Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: repository,
          starsShapeRepository: starsShapeRepository,
          presetArea: resolvedArea,
        ),
      ),
    );
  }
  return null;
}

/// Prompts for just a life area (a "supernova") — [StarFormScreen]'s own
/// supernova field uses this directly, and [pickProject] falls back to it
/// internally when "create new" is picked without one already chosen.
Future<LifeArea?> pickArea(BuildContext context) {
  final strings = context.strings;

  return showAppSheet<LifeArea>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSheetTitle(strings.areaLabel),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: LifeArea.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index + 1,
                    child: AppSheetAction(
                      icon: LifeArea.values[index].icon,
                      label: LifeArea.values[index].displayName(strings),
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(LifeArea.values[index]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(strings.cancel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<Object?> _pickProjectInArea(
  BuildContext context,
  ProjectRepository repository,
  LifeArea area,
) {
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showFixedAppSheet<Object>(
    context: context,
    builder: (sheetContext) {
      return _ProjectPickerSheet(
        area: area,
        projects: repository.getProjectsForArea(area),
        sheetHeight: sheetHeight,
      );
    },
  );
}

/// [pickProject]'s area-scoped path — search plus a prominent create-new
/// action, scoped to whichever [area] the caller already resolved (the
/// star form's own supernova field, picked separately via [pickArea]).
/// No way back to an area choice from in here any more; see [_pickProjectFlat]
/// for the picker shown when no area was resolved yet.
class _ProjectPickerSheet extends StatefulWidget {
  const _ProjectPickerSheet({
    required this.area,
    required this.projects,
    required this.sheetHeight,
  });

  final LifeArea area;
  final List<Project> projects;
  final double sheetHeight;

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  String _query = '';

  List<Project> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.projects;
    return widget.projects
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
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
            const SizedBox(height: 8),
            AreaTag(area: widget.area, iconSize: 16, fontSize: 14),
            const SizedBox(height: 20),
            StaggeredEntrance(
              index: 1,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: colors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  prefixIcon: Icon(Icons.search, color: colors.muted, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? StaggeredEntrance(
                      index: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            _query.isEmpty
                                ? strings.areaEmptyProjects(
                                    widget.area.displayName(strings),
                                  )
                                : strings.noSearchResults,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.muted, fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: false,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return StaggeredEntrance(
                          index: index + 3,
                          child: Ink(
                            decoration: selectableDecoration(
                              colors,
                              selected: false,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              title: ProjectTag(
                                project: project,
                                fontSize: 15,
                                textColor: colors.text,
                              ),
                              onTap: () => Navigator.of(context).pop(project),
                            ),
                          ),
                        );
                      },
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
                    child: Text(strings.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _CreateNewProject()),
                    child: Text(strings.newAction),
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

Future<Object?> _pickProjectFlat(
  BuildContext context,
  ProjectRepository repository,
) {
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showFixedAppSheet<Object>(
    context: context,
    builder: (sheetContext) {
      return _FlatProjectPickerSheet(
        projects: repository.getAll(),
        sheetHeight: sheetHeight,
      );
    },
  );
}

/// [pickProject]'s no-area-yet path — every constellation across every
/// area in one searchable list, each tagged with its own area since
/// nothing here groups them by one any more (see [_ProjectPickerSheet] for
/// that). Picking one, same as creating one, still resolves an area in the
/// end — [Project.area] — which is what lets the star form fill its own
/// supernova field in afterward.
class _FlatProjectPickerSheet extends StatefulWidget {
  const _FlatProjectPickerSheet({
    required this.projects,
    required this.sheetHeight,
  });

  final List<Project> projects;
  final double sheetHeight;

  @override
  State<_FlatProjectPickerSheet> createState() =>
      _FlatProjectPickerSheetState();
}

class _FlatProjectPickerSheetState extends State<_FlatProjectPickerSheet> {
  String _query = '';

  List<Project> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.projects;
    return widget.projects
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
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
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: colors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  prefixIcon: Icon(Icons.search, color: colors.muted, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
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
                            style: TextStyle(color: colors.muted, fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: false,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return StaggeredEntrance(
                          index: index + 3,
                          child: Ink(
                            decoration: selectableDecoration(
                              colors,
                              selected: false,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              title: ProjectTag(
                                project: project,
                                fontSize: 15,
                                textColor: colors.text,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: AreaTag(
                                  area: project.area,
                                  iconSize: 12,
                                  fontSize: 12,
                                  textColor: colors.muted,
                                  iconColor: colors.muted,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(project),
                            ),
                          ),
                        );
                      },
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
                    child: Text(strings.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _CreateNewProject()),
                    child: Text(strings.newAction),
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
