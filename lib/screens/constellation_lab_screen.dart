import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/constellation_layout.dart';
import '../data/constellation_shape.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/app_modals.dart';
import '../utils/habit_stats.dart';
import '../widgets/constellation_map/constellation_map_view.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/sky_nascent_star_tooltip.dart';
import '../widgets/sky_pulsar_tooltip.dart';
import '../widgets/sky_star_tooltip.dart';
import 'constellation_focus_lab.dart';

/// Read-only visual comparison, using a snapshot of the house project when
/// available and a standalone house fixture otherwise. Never writes data.
class ConstellationLabScreen extends StatefulWidget {
  const ConstellationLabScreen({
    super.key,
    this.project,
    this.stars,
    this.shape,
    this.habits = const [],
    this.completions = const [],
  });

  final Project? project;
  final List<Star>? stars;
  final ConstellationShape? shape;
  final List<Habit> habits;
  final List<HabitCompletion> completions;

  @override
  State<ConstellationLabScreen> createState() => _ConstellationLabScreenState();
}

class _ConstellationLabScreenState extends State<ConstellationLabScreen> {
  static const _canvas = Size(1000, 1000);
  static const _house = ConstellationShape(
    points: [
      Offset(0.5, 0.2),
      Offset(0.2, 0.4),
      Offset(0.2, 0.8),
      Offset(0.425, 0.8),
      Offset(0.425, 0.6),
      Offset(0.575, 0.6),
      Offset(0.575, 0.8),
      Offset(0.8, 0.8),
      Offset(0.8, 0.4),
    ],
    edges: [
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 6),
      (6, 7),
      (7, 8),
      (8, 0),
      (1, 8),
    ],
  );
  late final _project =
      widget.project ??
      Project(
        id: -100,
        name: 'Save for a house',
        area: LifeArea.financial,
        iconSlug: 'home',
        createdAt: DateTime(2026, 1, 1),
      );
  late final _shape = widget.shape?.points.isNotEmpty == true
      ? widget.shape!
      : _house;
  late final _stars = widget.stars ?? _demoStars();
  late final _render = buildConstellationRenderStars(
    stars: _stars,
    habits: widget.habits,
    shape: _shape,
    completionsByHabit: {
      for (final habit in widget.habits)
        habit.id: widget.completions
            .where((c) => c.habitId == habit.id)
            .toList(),
    },
  );
  final _camera = TransformationController();
  Size? _framedSize;
  int _variant = 0;
  int _reset = 0;
  int? _focused;

  List<Star> _demoStars() {
    const titles = [
      "Hit a savings milestone I'd been working toward",
      'Skipped an impulse purchase and put the money aside instead',
      'Said no to a night out to protect my savings',
      'Reach the down payment goal',
      "Cut a subscription I wasn't using",
      'Made it through the month under budget',
      'Had an honest look at my spending',
      'Made a little more room in my savings',
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        Star(
          id: -200 - i,
          projectId: _project.id,
          slotSequence: i + 1,
          title: titles[i],
          createdAt: DateTime(2026, 1, i + 1),
          achievedDate: i == 3 ? null : DateTime(2026, 2, i + 1),
          intensity: i == 3 ? null : (i % 5) + 1,
          targetDate: i == 3 ? DateTime(2027, 1, 1) : null,
        ),
    ];
  }

  @override
  void dispose() {
    _camera.dispose();

    super.dispose();
  }

  void _inspect(String title) => showAppDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(title),
      content: const Text(
        'Anteprima visiva: questa pagina non modifica le attività.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Chiudi', style: TextStyle(color: context.colors.muted)),
        ),
      ],
    ),
  );

  void _viewCard(ConstellationStar entry, String title) {
    if (_variant == 3) {
      setState(() => _focused = _render.stars.indexOf(entry));
    } else {
      _inspect(title);
    }
  }

  Widget _card(BuildContext context, ConstellationStar entry) {
    if (entry.kind == StarKind.nascent) {
      return SkyNascentStarTooltip(
        project: _project,
        onClose: () {},
        onView: () => _viewCard(entry, 'Opportunità'),
        onConfigure: () => _inspect('Configura'),
      );
    }
    if (entry.slotSequence == null) {
      final habit = widget.habits.firstWhere((h) => h.id == entry.entityId);
      final counts = habitCompletionCountsByDay(
        widget.completions.where((c) => c.habitId == habit.id).toList(),
      );
      return SkyPulsarTooltip(
        habit: habit,
        project: _project,
        countsByDay: counts,
        isLit: entry.lit,
        onClose: () {},
        onView: () => _viewCard(entry, habit.displayTitle),
        onToday: () => _inspect(habit.displayTitle),
        todayActionIcon: Icons.local_fire_department_rounded,
        todayActionLabel: 'Oggi',
        onEdit: () => _inspect('Modifica'),
        onShare: () => _inspect('Condividi'),
        onDelete: () => _inspect('Archivia'),
      );
    }
    final star = _stars.firstWhere((s) => s.id == entry.entityId);
    return SkyStarTooltip(
      star: star,
      project: _project,
      onClose: () {},
      onView: () => _viewCard(entry, star.displayTitle),
      onEdit: () => _inspect('Modifica'),
      onLight: star.isUnlit ? () => _inspect('Accendi') : null,
      onShare: star.dead ? null : () => _inspect('Condividi'),
      onDelete: star.dead ? null : () => _inspect('Archivia'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: DecoratedBox(
        key: const Key('constellation-lab-background'),
        decoration: BoxDecoration(
          gradient: _variant != 0
              ? colors.nightlightGradient
              : colors.constellationGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Indietro',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        'Constellation lab',
                        style: TextStyle(
                          fontFamily: kFontStarTitle,
                          fontSize: 24,
                          color: colors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('constellation-lab-reset'),
                      tooltip: 'Reimposta vista',
                      icon: const Icon(Icons.center_focus_strong),
                      onPressed: () => setState(() {
                        _framedSize = null;
                        _reset++;
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                _project.displayName,
                style: TextStyle(
                  fontFamily: kFontStarTitle,
                  fontSize: 21,
                  color: colors.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  key: const Key('constellation-lab-variant'),
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (value, label) in const [
                      (0, 'Originale'),
                      (1, 'Bianco · notte'),
                      (2, 'Cornici navy'),
                      (3, 'Leggera'),
                      (4, 'Atlante'),
                      (5, 'Punti luce'),
                      (6, 'Fili'),
                      (7, 'Card complete'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _variant == value,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _variant = value;
                          _focused = null;
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 48 * MediaQuery.textScalerOf(context).scale(1),
                  child: Center(
                    child: Text(
                      switch (_variant) {
                        1 =>
                          'Struttura e cornici bianche, sfondo di Vedi stella.',
                        2 => 'Glow esterno bianco, anelli e cornici navy su sfondo notte.',
                        3 => 'Struttura sottile, nodi compatti e cornici leggere. Tocca una stella o una scheda per darle risalto.',
                        4 => 'La forma respira: esplora i punti, con una sola scheda condivisa in primo piano.',
                        5 => 'Piccoli punti bianchi con un accento del tipo stella. Tutte le schede restano sulla mappa.',
                        6 => 'Icone libere, senza anelli: la forma è un filo sottile tra le schede.',
                        7 => 'Cornici navy e card complete come in Galaxy. Nei cerchi restano solo icone più grandi.',
                        _ => 'Prima versione: struttura navy, sfondo blu più chiaro.',
                      },
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _variant == 4
                    ? ConstellationFocusLab(
                        stars: _render.stars,
                        edges: _render.edges,
                        cardBuilder: _card,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final viewport = constraints.biggest;
                          final xs = _shape.points.map((p) => p.dx).toList();
                          final ys = _shape.points.map((p) => p.dy).toList();
                          final bounds = Rect.fromLTRB(
                            xs.reduce(math.min) * 1000,
                            ys.reduce(math.min) * 1000,
                            xs.reduce(math.max) * 1000,
                            ys.reduce(math.max) * 1000,
                          );
                          final fit =
                              math.min(
                                viewport.width / math.max(1, bounds.width),
                                viewport.height / math.max(1, bounds.height),
                              ) *
                              0.6;
                          if (_framedSize != viewport) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || _framedSize == viewport) return;
                              final zoom =
                                  fit * ConstellationMapView.initialZoomFactor;
                              setState(() {
                                _framedSize = viewport;
                                _camera.value = Matrix4.identity()
                                  ..translateByDouble(
                                    viewport.width / 2,
                                    viewport.height / 2,
                                    0,
                                    1,
                                  )
                                  ..scaleByDouble(zoom, zoom, 1, 1)
                                  ..translateByDouble(
                                    -bounds.center.dx,
                                    -bounds.center.dy,
                                    0,
                                    1,
                                  );
                              });
                            });
                            return const SizedBox.shrink();
                          }
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: LogoWatermark(
                                  scale: logoWatermarkScale(StarKind.unlit),
                                  color: logoWatermarkColor(
                                    colors,
                                    StarKind.unlit,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: ConstellationMapView(
                                  key: ValueKey((viewport, _reset)),
                                  stars: _render.stars,
                                  edges: _render.edges,
                                  transformation: _camera,
                                  canvasSize: _canvas,
                                  fitScale: fit,
                                  autoFrame: true,
                                  structureColor: _variant != 0
                                      ? Colors.white
                                      : null,
                                  luminousStructure:
                                      _variant == 2 ||
                                      _variant == 3 ||
                                      _variant == 7,
                                  refinedPresentation:
                                      _variant == 3 ||
                                      _variant == 5 ||
                                      _variant == 6,
                                  showCardVisual: _variant == 7,
                                  simplifiedNodes: _variant == 7,
                                  uniformNodeSize: _variant == 7,
                                  matchTooltipFrameToNode: _variant == 7,
                                  selectionEnabled: _variant >= 5,
                                  fadeStructureOnFocus: true,
                                  nodeStyle: switch (_variant) {
                                    5 => ConstellationNodeStyle.beacon,
                                    6 => ConstellationNodeStyle.glyph,
                                    _ => ConstellationNodeStyle.disc,
                                  },
                                  focusedStarIndex: _variant == 3
                                      ? _focused
                                      : null,
                                  tooltipFrameColor: _variant >= 2
                                      ? colors.night
                                      : null,
                                  onStarTap: (star) {
                                    if (_variant == 3) {
                                      setState(
                                        () => _focused =
                                            _focused ==
                                                _render.stars.indexOf(star)
                                            ? null
                                            : _render.stars.indexOf(star),
                                      );
                                    } else {
                                      _inspect(
                                        star.label.isEmpty
                                            ? 'Opportunità'
                                            : star.label,
                                      );
                                    }
                                  },
                                  cardBuilder: (context, star) => Listener(
                                    onPointerDown: _variant == 3
                                        ? (_) => setState(
                                            () => _focused = _render.stars
                                                .indexOf(star),
                                          )
                                        : null,
                                    child: _card(context, star),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Text(
                  _variant == 4
                      ? 'Tocca i punti o usa le frecce · le card sono quelle di Galaxy'
                      : 'Trascina e zooma · doppio tocco per tornare alla vista intera',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
