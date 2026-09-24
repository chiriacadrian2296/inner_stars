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
  final colors = context.colors;
  final strings = context.strings;

  return showAppSheet<LifeArea>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  strings.areaLabel,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < LifeArea.values.length; i++)
              StaggeredEntrance(
                index: i + 1,
                child: ListTile(
                  title: AreaTag(
                    area: LifeArea.values[i],
                    iconSize: 20,
                    fontSize: 16,
                  ),
                  trailing: Icon(Icons.chevron_right, color: colors.muted),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(LifeArea.values[i]),
                ),
              ),
          ],
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
  return showAppSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ProjectPickerSheet(
        area: area,
        projects: repository.getProjectsForArea(area),
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
  const _ProjectPickerSheet({required this.area, required this.projects});

  final LifeArea area;
  final List<Project> projects;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: AreaTag(area: widget.area, iconSize: 18, fontSize: 16),
            ),
            const SizedBox(height: 12),
            StaggeredEntrance(
              index: 1,
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
            const SizedBox(height: 14),
            StaggeredEntrance(
              index: 2,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(const _CreateNewProject()),
                borderRadius: BorderRadius.circular(kRadiusField),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: selectableDecoration(colors, selected: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: colors.gold),
                      const SizedBox(width: 8),
                      Text(
                        strings.newProject,
                        style: TextStyle(
                          color: colors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
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
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: colors.nightBorder, height: 1),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return StaggeredEntrance(
                          index: index + 3,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: ProjectTag(
                              project: project,
                              fontSize: 15,
                              textColor: colors.text,
                            ),
                            onTap: () => Navigator.of(context).pop(project),
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

Future<Object?> _pickProjectFlat(
  BuildContext context,
  ProjectRepository repository,
) {
  return showAppSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _FlatProjectPickerSheet(projects: repository.getAll());
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
  const _FlatProjectPickerSheet({required this.projects});

  final List<Project> projects;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Text(
                strings.projectLabel,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StaggeredEntrance(
              index: 1,
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
            const SizedBox(height: 14),
            StaggeredEntrance(
              index: 2,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(const _CreateNewProject()),
                borderRadius: BorderRadius.circular(kRadiusField),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: selectableDecoration(colors, selected: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: colors.gold),
                      const SizedBox(width: 8),
                      Text(
                        strings.newProject,
                        style: TextStyle(
                          color: colors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
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
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: colors.nightBorder, height: 1),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return StaggeredEntrance(
                          index: index + 3,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: ProjectTag(
                              project: project,
                              fontSize: 15,
                              textColor: colors.text,
                            ),
                            // Small and muted, under the project's own name —
                            // supporting context here rather than the
                            // headline fact [_ProjectPickerSheet]'s header
                            // makes it, since this list mixes every area.
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
