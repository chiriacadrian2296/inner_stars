import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/constellation_layout.dart';
import '../data/constellation_shape.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/staggered_entrance.dart';
import 'pulsar_reader_screen.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';

/// A single constellation up close: a pannable/zoomable star field shaped
/// like the project's own hand-drawn [Project.starsShapeId] shape.
/// Every slot on that shape holds a star — lit, unlit, dead, or still
/// nascent — ordered by [Star.slotSequence]; pulsars are separate, smaller
/// stars scattered around/inside/outside the shape (see
/// [seededPulsarPosition]), never part of that graph.
///
/// Tapping a star opens [StarReaderScreen]/[PulsarReaderScreen], or — for a
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
  });

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
  late final ConstellationShape? _shape =
      widget.project.starsShapeId != null
      ? widget.starsShapeRepository
            .getById(widget.project.starsShapeId!)
            ?.shape
      : null;
  late final Rect _shapeBounds = _shape == null
      ? Rect.zero
      : boundingBoxOf(_shape.points);

  late List<Star> _stars;
  late List<Habit> _habits;
  late List<ConstellationStar> _renderStars;
  late List<(int, int)> _edges;
  int _revision = 0;
  ui.FragmentProgram? _flareProgram;
  final _transformationController = TransformationController();
  bool _framed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFlareProgram();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadFlareProgram() async {
    final program = await buildConstellationFlareProgram();
    if (!mounted) return;
    setState(() {
      _flareProgram = program;
      _revision++;
    });
  }

  void _loadData() {
    _stars = widget.starRepository.getAllForProject(widget.project.id);
    _habits = widget.habitRepository.getAllForProject(widget.project.id);
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
    return built.stars;
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
        0.8;
    return scale <= 0 ? 0.1 : scale;
  }

  void _frameShape(Size viewportSize) {
    if (_framed || viewportSize.isEmpty) return;
    _framed = true;
    final scale = _fitScaleFor(viewportSize);
    final center = _boundsPixels().center;
    final matrix = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    setState(() => _transformationController.value = matrix);
  }

  void _refresh() {
    setState(() {
      _loadData();
      _revision++;
    });
  }

  Future<void> _openStar(ConstellationStar star) async {
    // An empty slot on the shape: tapping it is how it gets a meaning.
    if (star.kind == StarKind.nascent) {
      await _configureNascentStar(star);
      return;
    }
    // Sitting on a slot is what makes a star part of the shape — a pulsar
    // (alive or dead) scatters around it instead and has none, which is the
    // reliable test for which repository this star came from.
    if (star.slotSequence == null) {
      final habit = _habits.firstWhere((h) => h.id == star.entityId);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PulsarReaderScreen(
            habit: habit,
            project: widget.project,
            habitRepository: widget.habitRepository,
            habitCompletionRepository: widget.habitCompletionRepository,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
          ),
        ),
      );
      _refresh();
      return;
    }

    final index = _stars.indexWhere((s) => s.id == star.entityId);
    if (index == -1) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialStars: _stars,
          startIndex: index,
          allowEdit: true,
          projectsById: {widget.project.id: widget.project},
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshStars: () =>
              widget.starRepository.getAllForProject(widget.project.id),
        ),
      ),
    );
    _refresh();
  }

  /// Fills the exact slot the tapped nascent star occupies. The pulsar
  /// option is off — this slot belongs to the shape, and a pulsar never
  /// sits on the shape.
  Future<void> _configureNascentStar(ConstellationStar star) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: widget.project,
          slotSequence: star.slotSequence,
          allowPulsar: false,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    await widget.starRepository.add(
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      slotSequence: result.slotSequence,
      targetDate: result.targetDate,
      achievedDate: result.achievedDate,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final shape = _shape;
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                StaggeredEntrance(
                  index: 0,
                  axis: Axis.horizontal,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: colors.muted),
                  ),
                ),
                Expanded(
                  child: StaggeredEntrance(
                    index: 1,
                    axis: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.project.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: colors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.project.description case final description?
                            when description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: shape == null
                  ? StaggeredEntrance(
                      index: 2,
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
                        final minScale = _fitScaleFor(viewportSize);

                        return InteractiveViewer(
                          transformationController: _transformationController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(200),
                          minScale: minScale,
                          maxScale: minScale * 6,
                          trackpadScrollCausesScale: true,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                final star = hitTestStar(
                                  details.localPosition,
                                  _canvasSize,
                                  _renderStars,
                                );
                                if (star != null) _openStar(star);
                              },
                              child: _TickingConstellationCanvas(
                                canvasSize: _canvasSize,
                                stars: _renderStars,
                                flareProgram: _flareProgram,
                                revision: _revision,
                                palette: StarPalette(
                                  lit: colors.gold,
                                  core: colors.text,
                                  nascent: colors.starNascent,
                                  unlit: colors.starUnlit,
                                  dead: colors.starDead,
                                ),
                                edges: _edges,
                              ),
                            ),
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

/// A self-ticking wrapper around [ConstellationPainter] — owns its own
/// [Ticker] (same pattern as `AnimatedConstellationField`'s in the Galaxy
/// tab) so the flare rays' flicker on lit stars actually animates, without
/// making the whole surrounding screen (toolbar, `InteractiveViewer`, etc.)
/// rebuild every frame just to feed this one painter a clock.
class _TickingConstellationCanvas extends StatefulWidget {
  const _TickingConstellationCanvas({
    required this.canvasSize,
    required this.stars,
    required this.flareProgram,
    required this.revision,
    required this.palette,
    required this.edges,
  });

  final Size canvasSize;
  final List<ConstellationStar> stars;
  final ui.FragmentProgram? flareProgram;
  final int revision;
  final StarPalette palette;
  final List<(int, int)> edges;

  @override
  State<_TickingConstellationCanvas> createState() =>
      _TickingConstellationCanvasState();
}

class _TickingConstellationCanvasState
    extends State<_TickingConstellationCanvas>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widget.canvasSize,
      painter: ConstellationPainter(
        stars: widget.stars,
        flareProgram: widget.flareProgram,
        revision: widget.revision,
        palette: widget.palette,
        edges: widget.edges,
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      ),
    );
  }
}
