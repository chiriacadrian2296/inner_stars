import '../widgets/position_counter.dart';
import '../widgets/sky_star_tooltip.dart';
import '../widgets/sky_pulsar_tooltip.dart';
import '../widgets/sky_nascent_star_tooltip.dart';
import '../widgets/habit_stepper_dialog.dart';
import '../widgets/shareable_lit_star_card.dart';
import '../widgets/shareable_goal_card.dart';
import '../widgets/shareable_pulsar_card.dart';
import '../utils/habit_stats.dart';
import '../utils/entity_insights.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/grouped_action_layout.dart';
import 'light_screen.dart' show openEntityStatistics;

import '../widgets/icon_with_new_badge.dart';
import '../models/display_text.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constellation_layout.dart';
import '../data/constellation_shape.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reader_entries.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../widgets/habit_cycle_scope.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/constellation_map/constellation_map_view.dart';
import '../widgets/constellation_map/pulsar_spacing.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/logo_watermark.dart';
import '../utils/responsive.dart';
import '../widgets/balanced_title.dart';
import '../widgets/responsive_content.dart';
import '../widgets/sky_navigation_target.dart';
import '../widgets/shareable_constellation_card.dart';
import '../widgets/staggered_entrance.dart';
import 'share_preview_screen.dart';
import 'new_project_screen.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';

/// A single constellation up close: a pannable/zoomable map shaped like the
/// project's own hand-drawn [Project.starsShapeId] shape, every star a round
/// button with its title beside it (see [ConstellationMapView]).
/// Every slot on that shape holds a star — lit, unlit, dead, or still
/// nascent — ordered by [Star.slotSequence]; pulsars are separate, smaller
/// stars scattered around/inside/outside the shape (see
/// [seededPulsarPosition]), never part of that graph.
///
/// Tapping a star opens [StarReaderScreen], or — for a
/// nascent one — the [StarFormScreen] that configures that exact slot,
/// which is the one way this screen creates anything.
class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({
    super.key,
    required this.project,
    required this.starRepository,
    required this.projectRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    this.initialTransform,
    this.onTransformChanged,
  });

  /// The map's zoom/pan to open with instead of the farthest-zoom framing,
  /// and a report of every change, so Sky can bring the map back as it was
  /// left after a "Vola".
  final Matrix4? initialTransform;
  final ValueChanged<Matrix4>? onTransformChanged;

  final Project project;
  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  static const _canvasSize = Size(1000, 1000);

  // Every project is expected to carry a starsShapeId — either set
  // directly at creation (NewProjectScreen requires it) or backfilled by
  // backfillMissingConstellations for anything older. Falling back to null
  // (rather than looking a shape up from the project's icon, the way this
  // screen used to) is purely a defensive guard for that in-between moment,
  // not a live feature — it reuses the "shape missing" empty state below.
  late Project _project;
  ConstellationShape? get _shape => _project.starsShapeId != null
      ? widget.starsShapeRepository.getById(_project.starsShapeId!)?.shape
      : null;
  Rect get _shapeBounds =>
      _shape == null ? Rect.zero : boundingBoxOf(_shape!.points);

  late List<Star> _stars;
  late List<Habit> _habits;
  late List<ConstellationStar> _renderStars;
  late List<(int, int)> _edges;
  final _transformationController = TransformationController();
  bool _framed = false;
  late Matrix4? _restoredTransform = widget.initialTransform;

  /// The centered, farthest-zoom framing — what a double tap returns to, even
  /// when the map opened from a restored camera.
  Matrix4? _homeTransform;
  double? _fitScale;
  bool _contentReverse = false;
  bool _hasNavigatedConstellations = false;
  int _watermarkPulse = 0;
  double _watermarkPulseDirection = -1;
  final _shareKey = GlobalKey();

  /// How far apart, on screen at the fit zoom, two scattered stars' buttons
  /// must sit — a biggest button (with its rings) fits inside.
  static const _kButtonSeparation = 60.0;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadData();
    _transformationController.addListener(() {
      if (_framed) {
        widget.onTransformChanged?.call(
          _transformationController.value.clone(),
        );
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _loadData() {
    _stars = widget.starRepository.getAllForProject(_project.id);
    _habits = widget.habitRepository.getAllForProject(_project.id);
    _renderStars = _buildRenderStars();
  }

  List<ConstellationStar> _buildRenderStars() {
    final completionsByHabit = <int, List<HabitCompletion>>{};
    for (final completion in widget.habitCompletionRepository.getAll()) {
      completionsByHabit
          .putIfAbsent(completion.habitId, () => [])
          .add(completion);
    }

    final built = buildConstellationRenderStars(
      stars: _stars,
      habits: _habits,
      shape: _shape,
      completionsByHabit: completionsByHabit,
    );
    _edges = built.edges;
    // Before the first layout there is no viewport, so no fit scale to tell
    // how far apart two buttons must sit; [_frameShape] spreads them then.
    final fitScale = _fitScale;
    if (fitScale == null) return built.stars;
    return spreadScatteredStars(
      built.stars,
      canvasSize: _canvasSize,
      minSeparation: _kButtonSeparation / fitScale,
    );
  }

  Rect _boundsPixels() {
    return Rect.fromLTRB(
      _shapeBounds.left * _canvasSize.width,
      _shapeBounds.top * _canvasSize.height,
      _shapeBounds.right * _canvasSize.width,
      _shapeBounds.bottom * _canvasSize.height,
    );
  }

  double _fitScaleFor(Size viewportSize) {
    if (viewportSize.isEmpty) return 0.1;
    final boundsPixels = _boundsPixels();
    final shapeWidth = boundsPixels.width == 0 ? 1.0 : boundsPixels.width;
    final shapeHeight = boundsPixels.height == 0 ? 1.0 : boundsPixels.height;
    final scale =
        math.min(
          viewportSize.width / shapeWidth,
          viewportSize.height / shapeHeight,
        ) *
        // Leaves room around the shape for the labels, which sit outside it.
        0.6;
    return scale <= 0 ? 0.1 : scale;
  }

  void _frameShape(Size viewportSize) {
    if (_framed || viewportSize.isEmpty) return;
    _framed = true;
    final fitScale = _fitScaleFor(viewportSize);
    _fitScale = fitScale;
    // A constellation now opens at the map's fixed farthest zoom: its star
    // cards and leaders are laid out compactly there, giving the user the
    // whole constellation before they zoom into one star.
    final scale = fitScale * ConstellationMapView.initialZoomFactor;
    final center = _boundsPixels().center;
    final matrix = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    setState(() {
      // Only the first framing restores; swiping to another constellation
      // reframes from scratch.
      _transformationController.value = _restoredTransform ?? matrix;
      _restoredTransform = null;
      _homeTransform = matrix;
      _renderStars = _buildRenderStars();
    });
  }

  void _refresh() {
    if (mounted) setState(_loadData);
  }

  /// The constellation's watermark follows the light currently visible on
  /// its map. Pulsars already carry their live completion state in
  /// [_renderStars], so a habit counts as lit only when it is burning today.
  StarKind get _watermarkKind => _watermarkKindForStars(_renderStars);

  StarKind _watermarkKindForStars(Iterable<ConstellationStar> stars) {
    final values = stars.toList();
    if (values.isNotEmpty && values.every((star) => star.lit)) {
      return StarKind.lit;
    }
    if (values.any((star) => star.lit)) return StarKind.unlit;
    return StarKind.nascent;
  }

  /// Opens the star reader on the tapped star — whatever kind it is, an
  /// empty slot and a pulsar included — with every other member of the
  /// constellation one swipe away.
  Future<void> _openStar(ConstellationStar star) async {
    // Sitting on a slot is what makes a star part of the shape — a pulsar
    // (alive or dead) scatters around it instead and has none, which is the
    // reliable test for which repository this star came from.
    final anchorKey = switch (star.slotSequence) {
      null => 'p${star.entityId}',
      final slot when star.kind == StarKind.nascent => NascentEntry(
        projectId: _project.id,
        slot: slot,
      ).key,
      _ => 's${star.entityId}',
    };
    List<ReaderEntry> load() => projectReaderEntries(
      project: _project,
      starRepository: widget.starRepository,
      habitRepository: widget.habitRepository,
      starsShapeRepository: widget.starsShapeRepository,
    );
    final entries = load();
    final index = entries.indexWhere((e) => e.key == anchorKey);
    if (index == -1) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialEntries: entries,
          startIndex: index,
          allowEdit: true,
          projectsById: {_project.id: _project},
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshEntries: load,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          // The reader has already closed itself by now; this closes the
          // constellation too and hands the star back to whoever opened it.
          onNavigateTo: (project, {starId, habitId}) => Navigator.of(context)
              .pop(SkyStarTarget(project, starId: starId, habitId: habitId)),
        ),
      ),
    );
    _refresh();
  }

  Widget _buildMapCard(BuildContext context, ConstellationStar entry) {
    if (entry.kind == StarKind.nascent) {
      return SkyNascentStarTooltip(
        project: _project,
        onClose: () {},
        onView: () => _openStar(entry),
        onConfigure: () => _configureNascent(
          NascentEntry(projectId: _project.id, slot: entry.slotSequence!),
        ),
      );
    }
    if (entry.slotSequence == null) {
      final habit = _habits
          .where((value) => value.id == entry.entityId)
          .firstOrNull;
      if (habit == null) return const SizedBox.shrink();
      final counts = habitCompletionCountsByDay(
        widget.habitCompletionRepository.getAllForHabit(habit.id),
      );
      final now = DateTime.now();
      final doneToday = counts.containsKey(
        DateTime(now.year, now.month, now.day),
      );
      final stepper =
          habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1;
      return SkyPulsarTooltip(
        habit: habit,
        project: _project,
        countsByDay: counts,
        isLit: !habit.dead && isHabitLit(habit, counts),
        onClose: () {},
        onView: () => _openStar(entry),
        onToday: () => _toggleHabitToday(habit),
        todayActionIcon: stepper
            ? Icons.import_export
            : Icons.local_fire_department_rounded,
        todayActionLabel: stepper
            ? context.strings.habitProgressToday(
                habitDailyProgress(habit, counts),
                habit.targetPerPeriod,
              )
            : doneToday
            ? context.strings.actionTurnOff
            : context.strings.actionLight,
        onEdit: () => _editOrResurrectPulsar(habit),
        onDelete: habit.dead ? null : () => _archiveActivity(habit: habit),
        onShare: habit.dead ? null : () => _shareActivity(habit: habit),
      );
    }
    final star = _stars
        .where((value) => value.id == entry.entityId)
        .firstOrNull;
    if (star == null) return const SizedBox.shrink();
    return SkyStarTooltip(
      star: star,
      project: _project,
      onClose: () {},
      onView: () => _openStar(entry),
      onEdit: () => _editOrResurrectStar(star),
      onLight: star.isUnlit ? () => _lightStar(star) : null,
      onDelete: star.dead ? null : () => _archiveActivity(star: star),
      onShare: star.dead ? null : () => _shareActivity(star: star),
    );
  }

  Future<void> _lightStar(Star star) async {
    final result = await showMarkAchievedSheet(context);
    if (result == null) return;
    await widget.starRepository.markAchieved(
      star.id,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refresh();
  }

  Future<void> _toggleHabitToday(Habit habit) async {
    final repository = widget.habitCompletionRepository;
    if (habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1) {
      await showHabitStepperDialog(
        context: context,
        habit: habit,
        repository: repository,
        onChanged: _refresh,
      );
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = habitCompletionCountsByDay(
      repository.getAllForHabit(habit.id),
    );
    if (counts.containsKey(today)) {
      await repository.unmarkDone(habit.id, today);
    } else {
      await repository.markDone(habit.id);
    }
    _refresh();
  }

  Future<void> _archiveActivity({Star? star, Habit? habit}) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: habit != null
          ? strings.deletePulsarConfirmTitle
          : strings.deleteStarConfirmTitle,
      body: habit != null
          ? strings.deletePulsarConfirmBody
          : strings.deleteStarConfirmBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.archiveAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed) return;
    if (habit != null) {
      await widget.habitRepository.delete(habit.id);
    } else {
      await widget.starRepository.delete(star!.id);
    }
    _refresh();
  }

  Future<void> _shareActivity({Star? star, Habit? habit}) async {
    await showSharePreview(
      context: context,
      content: habit != null
          ? ShareablePulsarCard(habit: habit, project: _project)
          : star!.isLit
          ? ShareableLitStarCard(star: star, project: _project)
          : ShareableGoalCard(star: star, project: _project),
      shareText: habit?.displayTitle ?? star!.displayTitle,
      fileName: habit != null
          ? 'pulsar_${habit.id}.png'
          : 'star_${star!.id}.png',
    );
  }

  Future<void> _configureNascent(NascentEntry entry) async {
    final project = _project;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: project,
          slotSequence: entry.slot,
          allowPulsar: false,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    await widget.starRepository.add(
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
    _refresh();
  }

  Future<void> _editOrResurrectPulsar(Habit habit) async {
    final habits = widget.habitRepository;
    final completions = widget.habitCompletionRepository;

    if (habit.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingHabit: habit,
            contextProject: _project,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await habits.resurrect(
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
        completionRepository: completions,
      );
      _refresh();
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingHabit: habit,
          contextProject: _project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;
    if (result is StarFormDeleteRequested) {
      await habits.delete(habit.id);
      _refresh();
      return;
    }
    final formResult = result as StarFormResult;
    await habits.update(
      id: habit.id,
      title: formResult.title,
      iconSlug: formResult.iconSlug,
      description: formResult.description,
      projectId: formResult.projectId,
      intensity: formResult.intensity ?? habit.intensity,
      frequency: formResult.habitFrequency ?? habit.frequency,
      targetPerPeriod: formResult.habitTargetPerPeriod ?? habit.targetPerPeriod,
      cycleLength: formResult.habitCycleLength ?? habit.cycleLength,
      reminderHour: formResult.reminderHour,
      reminderMinute: formResult.reminderMinute,
    );
    _refresh();
  }

  Future<void> _editOrResurrectStar(Star current) async {
    if (current.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingStar: current,
            contextProject: _project,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await widget.starRepository.resurrect(
        current.id,
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
      _refresh();
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingStar: current,
          contextProject: _project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    if (result is StarFormDeleteRequested) {
      await widget.starRepository.delete(current.id);
      _refresh();
      return;
    }

    final addResult = result as StarFormResult;
    await widget.starRepository.update(
      id: current.id,
      title: addResult.title,
      iconSlug: addResult.iconSlug,
      description: addResult.description,
      projectId: addResult.projectId,
      targetDate: addResult.targetDate,
      achievedDate: addResult.achievedDate,
      intensity: addResult.intensity,
      photoPath: addResult.photoPath,
      media: addResult.media,
    );
    _refresh();
  }

  void _moveBy(int direction) {
    final projects = widget.projectRepository.getAll();
    final current = projects.indexWhere((project) => project.id == _project.id);
    if (current == -1 || projects.length < 2) return;
    final next = (current + direction) % projects.length;
    final nextProject = projects[next < 0 ? next + projects.length : next];
    setState(() {
      // The watermark and the swipe hint acknowledge every constellation
      // change together, even if this project's light state also changes.
      _watermarkPulse++;
      _watermarkPulseDirection = direction < 0 ? 1 : -1;
      _project = nextProject;
      _framed = false;
      _fitScale = null;
      _contentReverse = direction < 0;
      _hasNavigatedConstellations = true;
      _loadData();
    });
  }

  Future<void> _editProject() async {
    final updated = await Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          existingProject: _project,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _project = updated;
        _loadData();
      });
    }
  }

  Future<void> _deleteProject() async {
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
    final id = _project.id;
    final shapeId = _project.starsShapeId;
    if (!mounted) return;
    final cycleRepository = HabitCycleScope.read(context);
    final habitIds = await widget.habitRepository.deleteAllForProject(id);
    for (final habitId in habitIds) {
      await widget.habitCompletionRepository.deleteAllForHabit(habitId);
    }
    await cycleRepository?.deleteAllForHabits(habitIds);
    await widget.starRepository.deleteAllForProject(id);
    await widget.projectRepository.delete(id);
    if (shapeId != null &&
        !widget.projectRepository.getAll().any(
          (p) => p.starsShapeId == shapeId,
        )) {
      await widget.starsShapeRepository.delete(shapeId);
    }
    if (!mounted) return;
    final remaining = widget.projectRepository.getAll();
    if (remaining.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _project = remaining.first;
        _framed = false;
        _fitScale = null;
        _loadData();
      });
    }
  }

  Future<void> _share() async {
    final shape = _shape;
    if (shape == null) return;
    await showSharePreview(
      context: context,
      content: ShareableConstellationCard(project: _project, shape: shape),
      shareText: _project.displayName,
      fileName: 'constellation_${_project.id}.png',
    );
  }

  Future<void> _addStar() async {
    final capacity = _shape?.points.length ?? 0;
    final occupied = _stars.map((star) => star.slotSequence).toSet();
    int? firstFreeSlot;
    for (var slot = 1; slot <= capacity; slot++) {
      if (!occupied.contains(slot)) {
        firstFreeSlot = slot;
        break;
      }
    }
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: _project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          slotSequence: firstFreeSlot,
        ),
      ),
    );
    if (result is StarFormResult) {
      if (result.kind == StarKind.pulsar) {
        await widget.habitRepository.add(
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
      } else {
        await widget.starRepository.add(
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
      }
      _refresh();
    }
  }

  /// This constellation's place among all of them (1-based), as the
  /// previous/next arrows walk them.
  ({int index, int total}) get _projectPosition {
    final projects = widget.projectRepository.getAll();
    final current = projects.indexWhere((project) => project.id == _project.id);
    return (index: current + 1, total: projects.length);
  }

  @override
  Widget build(BuildContext context) {
    final shape = _shape;
    final colors = context.colors;
    final strings = context.strings;
    final projectPosition = _projectPosition;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        // Edge-to-edge lets the night sky continue behind the status icons.
        backgroundColor: Colors.black,
        body: DecoratedBox(
          // Lighter tones distinguish the dark tooltips, while the radial
          // gradient keeps the same shape and continues behind the dock.
          decoration: BoxDecoration(gradient: colors.nightlightGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Padding(
                    // Same insets as the Star Reader's header, so the arrows
                    // and title sit in the same place in every "Vedi".
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: ResponsiveContent(
                      maxWidth:
                          readerFrameWidth(context) ??
                          kResponsiveContentMaxWidth,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => _moveBy(-1),
                              icon: Icon(
                                Icons.chevron_left,
                                color: colors.text,
                              ),
                            ),
                            Expanded(
                              child: StaggeredEntrance(
                                key: ValueKey(
                                  'constellation-title-${_project.id}',
                                ),
                                index: 0,
                                axis: Axis.horizontal,
                                reverse: _contentReverse,
                                child: BalancedTitle(
                                  key: ValueKey(
                                    'constellation-title-${_project.id}',
                                  ),
                                  title: _project.displayName,
                                  style: TextStyle(
                                    fontFamily: kFontStarTitle,
                                    fontSize: 24,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _moveBy(1),
                              icon: Icon(
                                Icons.chevron_right,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LogoWatermark(
                          pulse: _watermarkPulse,
                          pulseDirection: _watermarkPulseDirection,
                          scale: logoWatermarkScale(_watermarkKind),
                          color: logoWatermarkColor(colors, _watermarkKind),
                        ),
                      ),
                      Positioned.fill(
                        child: shape == null
                            ? StaggeredEntrance(
                                key: ValueKey(
                                  'constellation-empty-${_project.id}',
                                ),
                                index: 2,
                                axis: Axis.horizontal,
                                reverse: _contentReverse,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      strings.constellationShapeMissing,
                                      style: TextStyle(color: colors.muted),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final viewportSize = constraints.biggest;
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _frameShape(viewportSize),
                                  );
                                  // Not built until the shape has been framed, so its
                                  // first frame never shows the unzoomed identity view.
                                  if (!_framed) return const SizedBox.shrink();

                                  // The header arrows and the dedicated swipe bar
                                  // are the only ways to swap a constellation.
                                  // Start its entrance only after
                                  // the camera is framed, so the map never flashes
                                  // at identity zoom before it settles in.
                                  return StaggeredEntrance(
                                    key: ValueKey(
                                      'constellation-map-${_project.id}',
                                    ),
                                    index: 1,
                                    axis: Axis.horizontal,
                                    reverse: _contentReverse,
                                    child: ConstellationMapView(
                                      stars: _renderStars,
                                      edges: _edges,
                                      transformation: _transformationController,
                                      homeTransform: _homeTransform,
                                      canvasSize: _canvasSize,
                                      fitScale: _fitScaleFor(viewportSize),
                                      onStarTap: _openStar,
                                      cardBuilder: _buildMapCard,
                                      structureColor: Colors.white,
                                      tooltipFrameColor: colors.night,
                                      luminousStructure: true,
                                      selectionEnabled: true,
                                      autoFrame:
                                          widget.initialTransform == null ||
                                          _hasNavigatedConstellations,
                                    ),
                                  );
                                },
                              ),
                      ),
                      // The swipe affordance floats above the map rather than
                      // occupying a separate page strip, so its transparency
                      // reveals the constellation beneath it.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 20,
                        child: _ConstellationSwipeBar(
                          onPrevious: () => _moveBy(-1),
                          onNext: () => _moveBy(1),
                          pulse: _watermarkPulse,
                          pulseDirection: _watermarkPulseDirection,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    16,
                    12,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (projectPosition.total > 1) ...[
                        PositionCounter(
                          index: projectPosition.index,
                          total: projectPosition.total,
                          icon: Icons.insights,
                        ),
                        const SizedBox(height: PositionCounter.gapBelow),
                      ],
                      GroupedActionLayout(
                        separatorBuilder: (dot) => StaggeredEntrance(
                          index: 4,
                          enabled: !_hasNavigatedConstellations,
                          drift: 0,
                          extraDelay: kActionGroupDotDelay,
                          child: dot,
                        ),
                        groups: [
                          0,
                          1,
                          if (EntityInsightsScope.maybeOf(context) != null) 2,
                          2,
                          2,
                          3,
                        ],
                        children: [
                          StaggeredEntrance(
                            index: 0,
                            enabled: !_hasNavigatedConstellations,
                            drift: 0.7,
                            child: _ConstellationDockAction(
                              icon: Icons.auto_awesome,
                              label: 'Nuova stella',
                              onTap: _addStar,
                              isNew: true,
                            ),
                          ),

                          StaggeredEntrance(
                            index: 1,
                            enabled: !_hasNavigatedConstellations,
                            drift: 0.7,
                            child: _ConstellationDockAction(
                              icon: Icons.share_outlined,
                              label: 'Condividi',
                              onTap: _share,
                            ),
                          ),

                          if (EntityInsightsScope.maybeOf(context) != null)
                            StaggeredEntrance(
                              index: 2,
                              enabled: !_hasNavigatedConstellations,
                              drift: 0.7,
                              child: _ConstellationDockAction(
                                icon: Icons.bar_chart,
                                label: strings.statsTitle,
                                onTap: () => openEntityStatistics(
                                  context,
                                  InsightEntity.project(_project.id),
                                ),
                              ),
                            ),

                          StaggeredEntrance(
                            index: 3,
                            enabled: !_hasNavigatedConstellations,
                            drift: 0.7,
                            child: _ConstellationDockAction(
                              icon: Icons.edit_outlined,
                              label: 'Modifica',
                              onTap: _editProject,
                            ),
                          ),

                          StaggeredEntrance(
                            index: 4,
                            enabled: !_hasNavigatedConstellations,
                            drift: 0.7,
                            child: _ConstellationDockAction(
                              icon: Icons.delete_outline,
                              label: 'Elimina',
                              onTap: _deleteProject,
                            ),
                          ),
                          StaggeredEntrance(
                            index: 5,
                            enabled: !_hasNavigatedConstellations,
                            drift: 0.7,
                            child: _ConstellationDockAction(
                              icon: Icons.navigation,
                              label: strings.actionFly,
                              onTap: () => Navigator.of(context).pop(_project),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 0,
                  height: 0,
                  // The sharing card has to stay in the render tree so its
                  // RepaintBoundary can be captured. On web, however, an
                  // OverflowBox is allowed to paint beyond this zero-sized
                  // placeholder; the translated card could therefore leak into
                  // the top-left of the constellation screen. Clip it from the
                  // page while preserving the boundary for [_share].
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: 400,
                      maxHeight: 600,
                      alignment: Alignment.topLeft,
                      child: Transform.translate(
                        offset: const Offset(-1000, -1000),
                        child: RepaintBoundary(
                          key: _shareKey,
                          child: SizedBox(
                            width: 400,
                            height: 600,
                            child: ShareableConstellationCard(
                              project: _project,
                              shape:
                                  shape ??
                                  const ConstellationShape(
                                    points: [],
                                    edges: [],
                                  ),
                            ),
                          ),
                        ),
                      ),
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

/// A deliberate, visible navigation zone: map gestures stay with the map,
/// while only a horizontal swipe here changes which constellation is open.
class _ConstellationSwipeBar extends StatefulWidget {
  const _ConstellationSwipeBar({
    required this.onPrevious,
    required this.onNext,
    required this.pulse,
    required this.pulseDirection,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final int pulse;
  final double pulseDirection;

  @override
  State<_ConstellationSwipeBar> createState() => _ConstellationSwipeBarState();
}

class _ConstellationSwipeBarState extends State<_ConstellationSwipeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didUpdateWidget(_ConstellationSwipeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) _glide.forward(from: 0);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -150) {
          widget.onNext();
        } else if (velocity >= 150) {
          widget.onPrevious();
        }
      },
      child: SizedBox(
        height: 52,
        child: AnimatedBuilder(
          animation: _glide,
          builder: (context, child) {
            final amount =
                Curves.easeInOut.transform(_glide.value) * 3.141592653589793;
            return Transform.translate(
              offset: Offset(widget.pulseDirection * 7 * math.sin(amount), 0),
              child: child,
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OutlinedSwipeIcon(Icons.swipe, size: 20),
              SizedBox(width: 8),
              _OutlinedSwipeText(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedSwipeIcon extends StatelessWidget {
  const _OutlinedSwipeIcon(this.icon, {this.size = 24});

  // Matches half of [_OutlinedSwipeText]'s 3 px stroke: every glyph gets a
  // true 1.5 px outline, rather than the uneven edge left by scaling up a
  // second icon behind it.
  static const _outlineThickness = 1.5;

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    const outlineOffsets = [
      Offset(-_outlineThickness, -_outlineThickness),
      Offset(0, -_outlineThickness),
      Offset(_outlineThickness, -_outlineThickness),
      Offset(-_outlineThickness, 0),
      Offset(_outlineThickness, 0),
      Offset(-_outlineThickness, _outlineThickness),
      Offset(0, _outlineThickness),
      Offset(_outlineThickness, _outlineThickness),
    ];
    return SizedBox(
      width: size + _outlineThickness * 2,
      height: size + _outlineThickness * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final offset in outlineOffsets)
            Transform.translate(
              offset: offset,
              child: Icon(icon, color: Colors.black, size: size),
            ),
          Icon(icon, color: Colors.white, size: size),
        ],
      ),
    );
  }
}

class _OutlinedSwipeText extends StatelessWidget {
  const _OutlinedSwipeText();

  static const _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(1.5),
    child: Stack(
      children: [
        Text(
          'SWIPE',
          style: _style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.black,
          ),
        ),
        Text('SWIPE', style: _style.copyWith(color: Colors.white)),
      ],
    ),
  );
}

/// The constellation dock sits on a transparent background, so each action
/// carries its own white disc.
class _ConstellationDockAction extends StatelessWidget {
  const _ConstellationDockAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isNew = false,
  });

  /// Adds the small "new" glyph under the icon (see [IconWithNewBadge]).
  final bool isNew;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: isNew
                ? IconWithNewBadge(
                    icon: icon,
                    size: 16,
                    color: context.colors.night,
                    lift: 2,
                  )
                : Icon(icon, size: 18, color: context.colors.night),
          ),
        ),
      ),
    ),
  );
}
