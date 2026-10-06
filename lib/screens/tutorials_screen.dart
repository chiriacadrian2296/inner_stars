import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../tutorials/tutorial_catalog.dart';
import '../tutorials/tutorial_management.dart' show kAllTourNames;
import '../tutorials/tutorial_replay.dart';
import '../utils/app_modals.dart';
import '../widgets/responsive_content.dart';
import '../widgets/sky_explorer_view.dart' show SkyExplorerSession;
import '../widgets/sky_menu_drawer.dart';
import '../widgets/staggered_entrance.dart';
import 'constellation_editor_screen.dart';
import 'new_project_screen.dart';
import 'sky_search_screen.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';
import 'visions_screen.dart';

/// Every guided tour in one place: tap a row, confirm, and the app takes you
/// to the right screen and replays that tour live, then brings you back here.
/// For anyone who forgot how something works, or wants to show a friend.
///
/// [reopen] rebuilds this screen (and the Settings page beneath it) on the
/// root navigator — the Cosmo tour can only run on the Cosmo itself, so that
/// replay has to pop everything and push it all back afterwards.
class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({
    super.key,
    required this.settings,
    required this.projectRepository,
    required this.starRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.reopen,
  });

  final SettingsController settings;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  final void Function(NavigatorState navigator) reopen;

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  bool _replaying = false;

  Future<void> _resetAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.strings.replayToursResult;
    final storage = Tour.read(context).storage;
    for (final name in kAllTourNames) {
      await storage.reset(name);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _replay(TutorialEntry entry) async {
    if (_replaying) return;
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: strings.tutorialReplayConfirmTitle,
      body: strings.tutorialReplayConfirmBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.tutorialReplayConfirmAction,
    );
    if (!confirmed || !mounted) return;

    _replaying = true;
    final tour = Tour.read(context);
    final navigator = Navigator.of(context);
    final home = ModalRoute.of(context)!;
    try {
      await tour.storage.reset(entry.name);
      switch (entry.name) {
        case 'sky-navigation':
          await _replayOnCosmo(tour, navigator);
        case 'light-your-sky':
          await _replayLightYourSky(tour, navigator, home);
        case 'star-form':
          await _replayOnTop(
            entry.name,
            StarFormScreen(
              projectRepository: widget.projectRepository,
              starsShapeRepository: widget.starsShapeRepository,
            ),
            tour,
            navigator,
            home,
          );
        case 'constellation-form':
          await _replayOnTop(
            entry.name,
            NewProjectScreen(
              projectRepository: widget.projectRepository,
              starsShapeRepository: widget.starsShapeRepository,
            ),
            tour,
            navigator,
            home,
          );
        case 'shape-editor':
          final route = MaterialPageRoute<void>(
            builder: (_) => StarsShapeEditorScreen(
              starsShapeRepository: widget.starsShapeRepository,
              replayHelp: true,
            ),
          );
          await navigator.push(route);
        case 'search-stars':
          await _replayOnTop(
            entry.name,
            SkySearchScreen(
              projectRepository: widget.projectRepository,
              starRepository: widget.starRepository,
              habitRepository: widget.habitRepository,
              habitCompletionRepository: widget.habitCompletionRepository,
              starsShapeRepository: widget.starsShapeRepository,
              areaVisionRepository: widget.areaVisionRepository,
              reflectionAnswerRepository: widget.reflectionAnswerRepository,
              settings: widget.settings,
              session: SkyExplorerSession(),
            ),
            tour,
            navigator,
            home,
          );
        case 'supernova-vision':
          await _replayOnTop(
            entry.name,
            VisionsScreen(
              areaVisionRepository: widget.areaVisionRepository,
              reflectionAnswerRepository: widget.reflectionAnswerRepository,
              projectRepository: widget.projectRepository,
              starRepository: widget.starRepository,
            ),
            tour,
            navigator,
            home,
          );
        case 'star-reader':
          await _replayOnTop(entry.name, _starReader(), tour, navigator, home);
      }
    } finally {
      TourReplay.clear(entry.name);
      _replaying = false;
    }
  }

  /// Pushes [screen] over this one, waits for [name]'s tour to end, then
  /// closes everything the tour opened and lands back here.
  Future<void> _replayOnTop(
    String name,
    Widget screen,
    TourController tour,
    NavigatorState navigator,
    Route<dynamic> home,
  ) async {
    TourReplay.request(name);
    final route = MaterialPageRoute<void>(builder: (_) => screen);
    unawaited(navigator.push(route));
    await Future.any([waitForTourEnd(tour, name), route.popped]);
    if (tour.activeTour == name) tour.cancel();
    if (home.isActive) navigator.popUntil((r) => r == home);
  }

  Future<void> _replayLightYourSky(
    TourController tour,
    NavigatorState navigator,
    Route<dynamic> home,
  ) async {
    TourReplay.request('light-your-sky');
    unawaited(
      SkyMenuContent.showChooser(
        context,
        onVisions: () {},
        onNewConstellation: () {},
        onLightAStar: () {},
      ),
    );
    await waitForTourEnd(tour, 'light-your-sky');
    if (home.isActive) navigator.popUntil((r) => r == home);
  }

  /// The Cosmo only exists as the root route, so this leaves every page
  /// above it, plays the tour there, then rebuilds Settings → Tutorials.
  Future<void> _replayOnCosmo(
    TourController tour,
    NavigatorState navigator,
  ) async {
    final reopen = widget.reopen;
    navigator.popUntil((r) => r.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await tour.start('sky-navigation', force: true);
    await waitForTourEnd(tour, 'sky-navigation');
    if (tour.activeTour == 'sky-navigation') tour.cancel();
    reopen(navigator);
  }

  /// The reader needs a star to show: the user's own lit ones when they
  /// have any, otherwise a made-up one so the tour never has nothing to
  /// point at.
  Widget _starReader() {
    List<Star> lit() => [
      for (final s in widget.starRepository.getAll())
        if (!s.dead && s.achievedDate != null) s,
    ];
    final real = lit();
    final Map<int, Project> projects;
    final List<Star> stars;
    final List<Star> Function() refresh;
    if (real.isNotEmpty) {
      projects = {for (final p in widget.projectRepository.getAll()) p.id: p};
      stars = real;
      refresh = lit;
    } else {
      final strings = context.strings;
      final now = DateTime.now();
      final project = Project(
        id: -1,
        name: strings.tutorialDemoProjectName,
        area: LifeArea.physical,
        iconSlug: 'park',
        createdAt: now,
      );
      projects = {project.id: project};
      stars = [
        Star(
          id: -1,
          projectId: project.id,
          slotSequence: 0,
          number: 1,
          title: strings.tutorialDemoStarTitle,
          description: strings.tutorialDemoStarDescription,
          createdAt: now,
          achievedDate: now,
          intensity: 3,
        ),
      ];
      refresh = () => stars;
    }
    return StarReaderScreen(
      repository: widget.starRepository,
      initialStars: stars,
      startIndex: 0,
      allowEdit: true,
      projectsById: projects,
      projectRepository: widget.projectRepository,
      starsShapeRepository: widget.starsShapeRepository,
      refreshStars: refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              StaggeredEntrance(
                index: 0,
                child: Text(
                  strings.tutorialsManagementTitle,
                  style: context.typography.utilityPageTitle,
                ),
              ),
              const SizedBox(height: 8),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  strings.tutorialsScreenIntro,
                  style: TextStyle(color: colors.muted, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < kTutorialCatalog.length; i++)
                StaggeredEntrance(
                  index: i + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: panelDecoration(colors),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(kRadiusCard),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(
                            kTutorialCatalog[i].icon,
                            color: colors.gold,
                          ),
                          title: Text(
                            kTutorialCatalog[i].title(strings),
                            style: TextStyle(color: colors.text, fontSize: 15),
                          ),
                          subtitle: Text(
                            kTutorialCatalog[i].body(strings),
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          trailing: Icon(
                            Icons.play_circle_outline,
                            color: colors.muted,
                          ),
                          onTap: () => _replay(kTutorialCatalog[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _resetAll,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: AppButtonLabel(strings.resetToursAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
