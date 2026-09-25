import 'dart:math' as math;

import 'package:flutter/material.dart';

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
import '../widgets/constellation_map/constellation_map_view.dart';
import '../widgets/constellation_map/pulsar_spacing.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/staggered_entrance.dart';
import 'pulsar_reader_screen.dart';
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
  final _transformationController = TransformationController();
  bool _framed = false;
  double? _fitScale;

  /// How far apart, on screen at the fit zoom, two scattered stars' buttons
  /// must sit — a biggest button (with its rings) fits inside.
  static const _kButtonSeparation = 60.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
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
    final scale = _fitScaleFor(viewportSize);
    _fitScale = scale;
    final center = _boundsPixels().center;
    final matrix = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    setState(() {
      _transformationController.value = matrix;
      _renderStars = _buildRenderStars();
    });
  }

  void _refresh() {
    setState(_loadData);
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
      final slot when star.kind == StarKind.nascent =>
        NascentEntry(projectId: widget.project.id, slot: slot).key,
      _ => 's${star.entityId}',
    };
    List<ReaderEntry> load() => projectReaderEntries(
      project: widget.project,
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
          projectsById: {widget.project.id: widget.project},
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshEntries: load,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
        ),
      ),
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
                        // Not built until the shape has been framed, so its
                        // first frame never shows the unzoomed identity view.
                        if (!_framed) return const SizedBox.shrink();

                        return ConstellationMapView(
                          stars: _renderStars,
                          edges: _edges,
                          transformation: _transformationController,
                          canvasSize: _canvasSize,
                          fitScale: _fitScaleFor(viewportSize),
                          onStarTap: _openStar,
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
