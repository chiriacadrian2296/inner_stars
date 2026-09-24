import 'dart:async';

import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../theme/nightlight_style.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/nightlight_zone_measurer.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import 'star_reader_screen.dart';

/// The last screen of the Nightlight flow (see `nightlight_gate_screen.dart`)
/// — reflecting on saved victories. Asks which life areas to draw from every
/// time (defaulting to all), then shows a shuffled, editable browse of every
/// achieved star in that selection via [StarReaderScreen]. Goals and dead
/// stars aren't part of this reflection pool — there's nothing to admire in
/// something not yet reached or no longer standing.
class AdmireStarsScreen extends StatefulWidget {
  const AdmireStarsScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<AdmireStarsScreen> createState() => _AdmireStarsScreenState();
}

class _AdmireStarsScreenState extends State<AdmireStarsScreen>
    with NightlightZoneMeasuring {
  Set<LifeArea> _selected = {};

  final _headerKey = GlobalKey();
  final _allToggleKey = GlobalKey();
  final _gridKey = GlobalKey();
  final _quoteKey = GlobalKey();
  final _poolSizeKey = GlobalKey();
  final _actionButtonKey = GlobalKey();

  bool get _allSelected => _selected.length == LifeArea.values.length;

  void _toggleAll() {
    setState(() => _selected = _allSelected ? {} : {...LifeArea.values});
  }

  void _toggleArea(LifeArea area) {
    setState(() {
      if (!_selected.remove(area)) _selected.add(area);
    });
  }

  Widget _areaChip(BuildContext context, LifeArea area) {
    final strings = context.strings;
    return _AreaChip(
      label: area.displayName(strings),
      icon: area.icon,
      selected: _selected.contains(area),
      onTap: () => _toggleArea(area),
    );
  }

  Map<int, Project> _projectsById() {
    return {
      for (final project in widget.projectRepository.getAll())
        project.id: project,
    };
  }

  List<Star> _poolForSelection() {
    final projectsById = _projectsById();
    return widget.starRepository.getAll().where((s) {
      if (!s.isLit) return false;
      final project = projectsById[s.projectId];
      return project != null && _selected.contains(project.area);
    }).toList();
  }

  Future<void> _start() async {
    final pool = _poolForSelection();
    if (pool.isEmpty) return;

    final shuffled = [...pool]..shuffle();
    final shuffledIds = shuffled.map((s) => s.id).toList();
    final selectionSnapshot = Set<LifeArea>.from(_selected);

    List<Star> currentInShuffledOrder() {
      final projectsById = _projectsById();
      final byId = {for (final s in widget.starRepository.getAll()) s.id: s};
      return shuffledIds.map((id) => byId[id]).whereType<Star>().where((s) {
        if (!s.isLit) return false;
        final project = projectsById[s.projectId];
        return project != null && selectionSnapshot.contains(project.area);
      }).toList();
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialStars: shuffled,
          startIndex: 0,
          allowEdit: true,
          projectsById: _projectsById(),
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshStars: currentInShuffledOrder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final poolSize = _poolForSelection().length;
    // Establishes a dependency on the current screen size, so a resize (a
    // browser window, an orientation change) rebuilds this and, in turn,
    // re-measures the zones below against the new layout.
    MediaQuery.sizeOf(context);
    scheduleZoneMeasurement([
      _headerKey,
      _allToggleKey,
      _gridKey,
      _quoteKey,
      _poolSizeKey,
      _actionButtonKey,
    ]);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
          key: stackKey,
          children: [
            // Kept clear of the header phrase, the area toggles, the area
            // grid, the quote carousel, the pool-size line, and the bottom
            // action button — see [NightlightZoneMeasuring] — measured off
            // their own actual, current position rather than a fixed guess,
            // so this stays correct across screen sizes.
            Positioned.fill(
              child: NightlightStarfield(exclusionZones: nightlightZones),
            ),
            SafeArea(
              child: Column(
                children: [
                  ResponsiveContent(
                    child: Row(
                      children: [
                        StaggeredEntrance(
                          index: 0,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: ResponsiveContent(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // No `SizedBox(width: double.infinity)`
                                    // around this — that forced the [Text]
                                    // itself to the full column width, which
                                    // also inflated its own measured exclusion
                                    // zone (see [NightlightZoneMeasuring]) to
                                    // that same full width. The [Column]'s own
                                    // `crossAxisAlignment.center` above already
                                    // centers it either way.
                                    StaggeredEntrance(
                                      index: 1,
                                      child: Text(
                                        strings.chooseSupernovasToInclude,
                                        key: _headerKey,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    StaggeredEntrance(
                                      index: 2,
                                      child: _AllToggleChip(
                                        contentKey: _allToggleKey,
                                        label: strings.admireAllAreasLabel,
                                        value: _allSelected,
                                        onChanged: (_) => _toggleAll(),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Column(
                                      key: _gridKey,
                                      children: [
                                        for (
                                          var row = 0;
                                          row * 2 < LifeArea.values.length;
                                          row++
                                        ) ...[
                                          if (row > 0)
                                            const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              for (
                                                var col = 0;
                                                col < 2;
                                                col++
                                              ) ...[
                                                if (col > 0)
                                                  const SizedBox(width: 12),
                                                // Rows cascade down, and the
                                                // two chips of a row slide in
                                                // left to right.
                                                Expanded(
                                                  child: StaggeredEntrance(
                                                    index: 3 + row + col,
                                                    axis: Axis.horizontal,
                                                    child: _areaChip(
                                                      context,
                                                      LifeArea.values[row * 2 +
                                                          col],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    StaggeredEntrance(
                                      index: 8,
                                      child: _UpliftingQuoteCarousel(
                                        contentKey: _quoteKey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ResponsiveContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                      child: Column(
                        children: [
                          StaggeredEntrance(
                            index: 9,
                            child: Text(
                              poolSize == 0
                                  ? strings.pickAtLeastOneArea
                                  : strings.starsCount(poolSize),
                              key: _poolSizeKey,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.nightlightMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // No forced `width: double.infinity` — sized to
                          // its own label/icon instead, like every other
                          // button in this section.
                          StaggeredEntrance(
                            index: 10,
                            child: ElevatedButton.icon(
                              key: _actionButtonKey,
                              onPressed: poolSize == 0 ? null : _start,
                              icon: const Icon(Icons.auto_awesome, size: 17),
                              label: Text(strings.viewYourStars),
                              // Same white-on-navy look as the rest of the
                              // Nightlight flow, with its own disabled fill
                              // layered on top since [nightlightButtonStyle]
                              // doesn't define one.
                              style: nightlightButtonStyle(colors).copyWith(
                                backgroundColor: WidgetStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return colors.nightlightMuted.withValues(
                                      alpha: 0.15,
                                    );
                                  }
                                  return colors.nightBorder;
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return colors.nightlightMuted;
                                  }
                                  return Colors.white;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This screen's own "white on navy" selected-surface look, in place of the
/// app's usual gold [selectableDecoration] — it sits on the Nightlight
/// gradient rather than the night panel, and gold reads as a stray accent
/// from the app's default theme here (see `nightlight_style.dart`'s own
/// doc comment for why this section keeps a deliberately different look).
BoxDecoration _nightlightChipDecoration(
  AppColors colors, {
  required bool selected,
  double radius = kRadiusPill,
}) {
  if (!selected) {
    return BoxDecoration(
      color: colors.nightPanel,
      border: Border.all(color: colors.nightBorder, width: kBorderWidth),
      borderRadius: BorderRadius.circular(radius),
    );
  }
  return BoxDecoration(
    color: colors.nightBorder,
    border: Border.all(color: Colors.white, width: kBorderWidthActive),
    borderRadius: BorderRadius.circular(radius),
  );
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: _nightlightChipDecoration(colors, selected: selected),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : (icon ?? Icons.circle_outlined),
              size: 16,
              color: selected ? Colors.white : colors.nightlightMuted,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.nightlightMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "All" toggle above the area grid — [AppToggleChip] restyled in this
/// screen's own white-on-navy look (see [_nightlightChipDecoration]) rather
/// than reused directly: that widget's pill and its wrapped [Switch] are
/// both wired to the app's gold theme, and neither exposes a color to
/// override.
class _AllToggleChip extends StatelessWidget {
  const _AllToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
    this.contentKey,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Attached to the actual pill [Container] below rather than passed as
  /// this widget's own `key` — this widget's root is a [Center], which
  /// (given a bounded incoming width) expands to fill it regardless of the
  /// pill's own size, so measuring *that* for
  /// [NightlightZoneMeasuring] would report the whole available width
  /// rather than just the pill.
  final Key? contentKey;

  static const _pillRadius = kRadiusPill;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Container(
          key: contentKey,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: _nightlightChipDecoration(
            colors,
            selected: value,
            radius: _pillRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.nightlightMuted,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 6),
              Transform.scale(
                scale: 0.8,
                child: SwitchTheme(
                  data: SwitchThemeData(
                    thumbColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.night
                          : colors.nightlightMuted,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.transparent,
                    ),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : colors.nightlightMuted,
                    ),
                    trackOutlineWidth: const WidgetStatePropertyAll(
                      kBorderWidth,
                    ),
                  ),
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cycles through [AppStrings.upliftingQuotes] on its own, one every 5
/// seconds.
class _UpliftingQuoteCarousel extends StatefulWidget {
  const _UpliftingQuoteCarousel({this.contentKey});

  /// Attached to the actual [AnimatedSwitcher] below rather than passed as
  /// this widget's own `key` — see [_AllToggleChip.contentKey]'s own doc
  /// comment for why: this widget's build also roots in a [Center].
  final Key? contentKey;

  @override
  State<_UpliftingQuoteCarousel> createState() =>
      _UpliftingQuoteCarouselState();
}

class _UpliftingQuoteCarouselState extends State<_UpliftingQuoteCarousel> {
  List<String>? _quotes;
  int _index = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _quotes ??= [...context.strings.upliftingQuotes]..shuffle();
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % quotes.length);
    });

    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: Center(
        child: AnimatedSwitcher(
          key: widget.contentKey,
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final scale = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: Text(
            quotes[_index],
            key: ValueKey(_index),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontStarTitle,
              fontSize: 20,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: colors.nightlightMuted,
            ),
          ),
        ),
      ),
    );
  }
}
