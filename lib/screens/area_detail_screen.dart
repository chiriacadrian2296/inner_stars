import '../utils/area_section_icons.dart';
import '../utils/entity_insights.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/grouped_action_layout.dart';
import 'light_screen.dart' show openEntityStatistics;
import 'today_habits_screen.dart' show openTodayHabits;

import '../widgets/icon_with_new_badge.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../data/reflection_repository.dart';
import '../data/moodboard_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../models/star_kind.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/area_hero_art.dart';
import '../utils/area_hero_art_tone.dart';
import '../widgets/balanced_title.dart';
import '../widgets/moodboard_grid.dart';
import '../widgets/logo_watermark.dart';
import 'area_reflections_screen.dart';
export 'area_reflections_screen.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/vision_markdown.dart';
import 'vision_editor_screen.dart';
import 'moodboard_screen.dart';
import 'create_flow.dart';

/// How wide the area's artwork is drawn on wide layouts (web/desktop).
const double _kWideArtWidth = 460;

/// An area's artwork followed by compact Vision, Moodboard and Reflections
/// sections. Each section opens its own full-screen editor.
class AreaDetailScreen extends StatefulWidget {
  const AreaDetailScreen({
    super.key,
    required this.area,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.projectRepository,
    required this.starRepository,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
    this.previewOffsets,
  });
  final LifeArea area;

  /// Each section preview's own scroll offset, keyed by the section's
  /// entrance index. Read to restore previews, and written as they scroll.
  final Map<int, double>? previewOffsets;

  /// Where the page starts scrolled, and a report of where it is scrolled to,
  /// so Sky can bring the page back as it was left after a "Vola".
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollChanged;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionRepository reflectionAnswerRepository;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  late LifeArea _area;
  bool _contentReverse = false;
  bool _hasNavigatedAreas = false;
  late final Future<MoodboardRepository> _moodboard =
      MoodboardRepository.create();
  late final Future<StarsShapeRepository> _starsShapes =
      StarsShapeRepository.create();

  /// The page's own scroll, so a preview scrolled to its end can hand the
  /// drag over to it (see [_ChainedPreviewScroll]).
  late final _pageScroll = ScrollController(
    initialScrollOffset: widget.initialScrollOffset,
  );

  @override
  void initState() {
    super.initState();
    _area = widget.area;
    _pageScroll.addListener(
      () => widget.onScrollChanged?.call(_pageScroll.offset),
    );
  }

  @override
  void dispose() {
    _pageScroll.dispose();
    super.dispose();
  }

  void _moveBy(int direction) {
    final areas = LifeArea.values;
    final next = (_area.index + direction) % areas.length;
    setState(() {
      _area = areas[next < 0 ? next + areas.length : next];
      _contentReverse = direction < 0;
      _hasNavigatedAreas = true;
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _openMoodboard() async {
    try {
      final repository = await _moodboard;
      if (mounted) {
        await _open(MoodboardScreen(area: _area, repository: repository));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.moodboardSaveError)),
        );
      }
    }
  }

  Future<void> _openNewConstellation() =>
      _create(constellation: true, constellationOnly: true);

  /// The same creation page as every other add button, with this area
  /// pre-filled.
  Future<void> _create({
    bool constellation = false,
    bool constellationOnly = false,
  }) async {
    final starsShapeRepository = await _starsShapes;
    if (!mounted) return;
    final habitRepository =
        EntityInsightsScope.maybeOf(context)?.habits ??
        await HabitRepository.create();
    if (!mounted) return;
    await showCreatePage(
      context,
      projectRepository: widget.projectRepository,
      starsShapeRepository: starsShapeRepository,
      starRepository: widget.starRepository,
      habitRepository: habitRepository,
      constellation: constellation,
      constellationOnly: constellationOnly,
      area: _area,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final area = _area;
    final vision = widget.areaVisionRepository.getVision(area);
    final answers = widget.reflectionAnswerRepository.getForArea(area);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.colors.night,
        body: SafeArea(
          bottom: false,
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.colors.night),
            // The scroll view spans the full window width (so its
            // scrollbar sits at the true page edge and the wheel works
            // anywhere); only its content and the dock are capped/centered.
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() > 180) _moveBy(velocity < 0 ? 1 : -1);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          _AreaNavigationBar(
                            title: area.displayName(strings),
                            replayKey: area,
                            reverse: _contentReverse,
                            animate: _hasNavigatedAreas,
                            onPrevious: () => _moveBy(-1),
                            onNext: () => _moveBy(1),
                          ),
                          Expanded(
                            child: CustomScrollView(
                              controller: _pageScroll,
                              slivers: [
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 16),
                                ),
                                SliverToBoxAdapter(
                                  child: StaggeredEntrance(
                                    key: ValueKey('area-art-${area.name}'),
                                    index: 0,
                                    axis: Axis.horizontal,
                                    reverse: _contentReverse,
                                    // Phones: the art spans the screen. Wide
                                    // layouts: a smaller one, centered —
                                    // the full column is too big.
                                    child: Center(
                                      child: tonedAreaHeroArt(
                                        child: Image.asset(
                                          kAreaHeroArt[area]!.skyAsset,
                                          width: isWideLayout(context)
                                              ? math.min(
                                                  constraints.maxWidth,
                                                  _kWideArtWidth,
                                                )
                                              : constraints.maxWidth,
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: ResponsiveContent(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        28,
                                        36,
                                        28,
                                        80 +
                                            MediaQuery.paddingOf(context)
                                                .bottom,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _AreaSection(
                                            pageScroll: _pageScroll,
                                            previewOffsets:
                                                widget.previewOffsets,
                                            index: 0,
                                            replayKey: area,
                                            reverse: _contentReverse,
                                            title: strings.areaCoverVisionTitle,
                                            icon: kAreaVisionIcon,
                                            preview: VisionMarkdown(
                                              data: vision.trim().isEmpty
                                                  ? area.visionPlaceholder(
                                                      strings,
                                                    )
                                                  : vision,
                                              color: context.colors.text,
                                            ),
                                            action: HintTarget(
                                              tour: 'supernova-vision',
                                              order: 2,
                                              showArrow: true,
                                              contentBuilder: appTourStepCard,
                                              title: strings
                                                  .supernovaTourEditTitle,
                                              description:
                                                  strings.supernovaTourEditBody,
                                              child: _SectionButton(
                                                index: 2,
                                                replayKey: area,
                                                reverse: _contentReverse,
                                                label: strings.areaSectionOpen,
                                                onPressed: () => _open(
                                                  VisionEditorScreen(
                                                    area: area,
                                                    repository: widget
                                                        .areaVisionRepository,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _AreaSection(
                                            pageScroll: _pageScroll,
                                            previewOffsets:
                                                widget.previewOffsets,
                                            index: 2,
                                            replayKey: area,
                                            reverse: _contentReverse,
                                            staggerPreview: false,
                                            showWatermark: false,
                                            title: strings.moodboardTitle,
                                            icon: kAreaMoodboardIcon,
                                            preview:
                                                FutureBuilder<
                                                  MoodboardRepository
                                                >(
                                                  future: _moodboard,
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasError) {
                                                      return Text(
                                                        strings
                                                            .moodboardSaveError,
                                                      );
                                                    }
                                                    if (!snapshot.hasData) {
                                                      return Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color: context
                                                                  .colors
                                                                  .gold,
                                                            ),
                                                      );
                                                    }
                                                    return MoodboardGrid(
                                                      placeholders: true,
                                                      placeholderReplayKey:
                                                          area,
                                                      items: snapshot.data!
                                                          .getItems(area)
                                                          .take(6)
                                                          .toList(),
                                                    );
                                                  },
                                                ),
                                            action: _SectionButton(
                                              index: 4,
                                              replayKey: area,
                                              reverse: _contentReverse,
                                              label: strings.areaSectionOpen,
                                              onPressed: _openMoodboard,
                                            ),
                                          ),
                                          _AreaSection(
                                            pageScroll: _pageScroll,
                                            previewOffsets:
                                                widget.previewOffsets,
                                            index: 4,
                                            replayKey: area,
                                            reverse: _contentReverse,
                                            title: strings.areaReflectionsTitle,
                                            icon: kAreaReflectionsIcon,
                                            preview: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  strings.reflectionCount(
                                                    answers.length,
                                                  ),
                                                  style: TextStyle(
                                                    color: context.colors.muted,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                if (answers.isEmpty)
                                                  Text(
                                                    strings.reflectionEmpty,
                                                    style: TextStyle(
                                                      color:
                                                          context.colors.muted,
                                                    ),
                                                  ),
                                                for (final reflection
                                                    in answers.take(3)) ...[
                                                  Text(
                                                    reflection.title,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          kFontStarTitle,
                                                      fontSize: 18,
                                                      height: 1.4,
                                                      color:
                                                          context.colors.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    reflection.body,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          context.colors.muted,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 18),
                                                ],
                                              ],
                                            ),
                                            action: HintTarget(
                                              tour: 'supernova-vision',
                                              order: 3,
                                              showArrow: true,
                                              contentBuilder: appTourStepCard,
                                              title: strings
                                                  .supernovaTourReflectionTitle,
                                              description: strings
                                                  .supernovaTourReflectionBody,
                                              child: _SectionButton(
                                                index: 6,
                                                replayKey: area,
                                                reverse: _contentReverse,
                                                label: strings.areaSectionOpen,
                                                onPressed: () => _open(
                                                  AreaReflectionsScreen(
                                                    area: area,
                                                    repository: widget
                                                        .reflectionAnswerRepository,
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
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ResponsiveContent(
                    shrinkHeight: true,
                    child: _AreaDock(
                      onManage: EntityInsightsScope.maybeOf(context) == null
                          ? null
                          : () => openTodayHabits(
                              context,
                              InsightEntity.area(area),
                            ),
                      onStatistics: EntityInsightsScope.maybeOf(context) == null
                          ? null
                          : () => openEntityStatistics(
                              context,
                              InsightEntity.area(area),
                            ),
                      animate: !_hasNavigatedAreas,
                      onVision: () => _open(
                        VisionEditorScreen(
                          area: area,
                          repository: widget.areaVisionRepository,
                        ),
                      ),
                      onMoodboard: _openMoodboard,
                      onFly: () => Navigator.of(context).pop(area),
                      onReflections: () => _open(
                        AreaReflectionsScreen(
                          area: area,
                          repository: widget.reflectionAnswerRepository,
                        ),
                      ),
                      onNewConstellation: _openNewConstellation,
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

class _AreaNavigationBar extends StatelessWidget {
  const _AreaNavigationBar({
    required this.title,
    required this.replayKey,
    required this.reverse,
    required this.animate,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final Object replayKey;
  final bool reverse;
  final bool animate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    // A plain navy shadow like the dock's: Material elevation would darken
    // the navy into a black halo over the previews.
    decoration: BoxDecoration(
      color: context.colors.night,
      boxShadow: [
        BoxShadow(
          color: context.colors.night.withValues(alpha: 0.9),
          blurRadius: 32,
          spreadRadius: 6,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Padding(
        // Same insets as the Star Reader's header, so the arrows and title sit
        // in the same place in every "Vedi".
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: ResponsiveContent(
          maxWidth: readerFrameWidth(context) ?? kResponsiveContentMaxWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              children: [
                StaggeredEntrance(
                  replayKey: replayKey,
                  index: 0,
                  axis: Axis.horizontal,
                  reverse: reverse,
                  enabled: animate,
                  child: IconButton(
                    onPressed: onPrevious,
                    icon: Icon(Icons.chevron_left, color: context.colors.text),
                  ),
                ),
                Expanded(
                  child: StaggeredEntrance(
                    replayKey: replayKey,
                    index: 1,
                    axis: Axis.horizontal,
                    reverse: reverse,
                    enabled: animate,
                    child: BalancedTitle(
                      title: title,
                      style: TextStyle(
                        fontFamily: kFontStarTitle,
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: context.colors.text,
                      ),
                    ),
                  ),
                ),
                StaggeredEntrance(
                  replayKey: replayKey,
                  index: 2,
                  axis: Axis.horizontal,
                  reverse: reverse,
                  enabled: animate,
                  child: IconButton(
                    onPressed: onNext,
                    icon: Icon(Icons.chevron_right, color: context.colors.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AreaDock extends StatelessWidget {
  const _AreaDock({
    required this.animate,
    required this.onVision,
    required this.onMoodboard,
    required this.onNewConstellation,
    required this.onReflections,
    required this.onFly,
    this.onStatistics,
    this.onManage,
  });
  final bool animate;
  final VoidCallback? onManage;
  final VoidCallback onVision;
  final VoidCallback onMoodboard;
  final VoidCallback onNewConstellation;
  final VoidCallback onReflections;
  final VoidCallback onFly;
  final VoidCallback? onStatistics;
  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _AreaDockAction(
        icon: Icons.insights,
        label: context.strings.areaQuickLookNewConstellationAction,
        onTap: onNewConstellation,
        isNew: true,
      ),
      if (onManage != null)
        _AreaDockAction(
          icon: Icons.checklist_rounded,
          label: context.strings.manageActivities,
          onTap: onManage!,
        ),
      _AreaDockAction(
        icon: kAreaVisionIcon,
        label: context.strings.visionPageTitle,
        onTap: onVision,
      ),
      _AreaDockAction(
        icon: kAreaMoodboardIcon,
        label: context.strings.moodboardTitle,
        onTap: onMoodboard,
      ),
      _AreaDockAction(
        icon: kAreaReflectionsIcon,
        label: context.strings.areaQuickLookReflectionsAction,
        onTap: onReflections,
      ),
      if (onStatistics != null)
        _AreaDockAction(
          icon: Icons.bar_chart,
          label: context.strings.statsTitle,
          onTap: onStatistics!,
        ),
      _AreaDockAction(
        icon: Icons.navigation,
        label: context.strings.actionFly,
        onTap: onFly,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.night,
        boxShadow: [
          BoxShadow(
            color: context.colors.night.withValues(alpha: 0.9),
            blurRadius: 32,
            spreadRadius: 6,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          16,
          12,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: GroupedActionLayout(
          separatorBuilder: (dot) => StaggeredEntrance(
            index: 4,
            enabled: animate,
            drift: 0,
            extraDelay: kActionGroupDotDelay,
            child: dot,
          ),
          groups: [
            0,
            if (onManage != null) 0,
            1,
            1,
            1,
            if (onStatistics != null) 2,
            3,
          ],
          children: [
            for (var i = 0; i < actions.length; i++)
              StaggeredEntrance(
                index: i,
                enabled: animate,
                drift: 0.7,
                child: actions[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// Same white disc as the Star Reader and constellation docks.
class _AreaDockAction extends StatelessWidget {
  const _AreaDockAction({
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

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.pageScroll,
    required this.previewOffsets,
    required this.index,
    required this.replayKey,
    required this.reverse,
    required this.title,
    this.icon,
    required this.preview,
    required this.action,
    this.staggerPreview = true,
    this.showWatermark = true,
  });

  /// Entrance index of the title; the preview follows one step later. The
  /// [action] animates itself (it may be a tour target, which is never
  /// wrapped from outside).
  final int index;
  final Object replayKey;
  final bool reverse;

  /// False when [preview] already staggers its own contents.
  final ScrollController pageScroll;
  final Map<int, double>? previewOffsets;
  final bool staggerPreview;
  final bool showWatermark;
  final String title;
  final IconData? icon;
  final Widget preview;
  final Widget action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 44),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaggeredEntrance(
          index: index,
          replayKey: replayKey,
          axis: Axis.horizontal,
          reverse: reverse,
          // A one-line title is short, so the default 6% rise is a couple of
          // pixels; this makes it actually visible.
          drift: 0.5,
          child: Text.rich(
            TextSpan(
              children: [
                if (icon != null) ...[
                  // As tall as the text beside it.
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(icon, size: 30, color: context.colors.text),
                  ),
                  const WidgetSpan(child: SizedBox(width: 14)),
                ],
                TextSpan(text: title),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontBranding,
              fontSize: 30,
              color: context.colors.text,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _previewBox(context),
        const SizedBox(height: 18),
        action,
      ],
    ),
  );

  static const _fadeHeight = 66.0;
  static const _scrollbarGutter = 12.0;

  Widget _previewBox(BuildContext context) {
    final box = SizedBox(
      height: 300,
      child: ClipRect(
        child: ScrollbarTheme(
          // The app theme's dark-blue thumb was made for the web; on a phone
          // these previews keep the stock scrollbar they had before.
          data: isTouchOnlyMobile
              ? const ScrollbarThemeData(minThumbLength: 10)
              : ScrollbarTheme.of(context).copyWith(minThumbLength: 10),
          // The thumb is painted after the Stack, while the fades still
          // stay above the preview content. Its track can therefore run
          // to the real bottom edge of the preview.
          // Scrollbar shrinks its track by the screen's safe-area insets, so
          // under the system bar the thumb stopped short of the bottom of
          // a preview. A preview isn't under any system bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: Scrollbar(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (showWatermark)
                    Positioned.fill(
                      child: LogoWatermark(
                        scale: logoWatermarkScale(StarKind.nascent),
                        color: logoWatermarkColor(
                          context.colors,
                          StarKind.nascent,
                        ),
                      ),
                    ),
                  // The right gutter is the scrollbar's lane, so its thumb
                  // sits beside the content instead of over it.
                  Padding(
                    padding: const EdgeInsets.only(right: _scrollbarGutter),
                    child: _ChainedPreviewScroll(
                      outer: pageScroll,
                      initialOffset: previewOffsets?[index] ?? 0,
                      onOffsetChanged: previewOffsets == null
                          ? null
                          : (offset) => previewOffsets![index] = offset,
                      child: preview,
                    ),
                  ),
                  // The fades are only as tall as the fade itself. As
                  // full-box gradients clamped past their last stop, they
                  // left the whole preview a hair lighter than the page on
                  // some phones (+1 per channel against the navy).
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _fadeHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.colors.night,
                              context.colors.night.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _fadeHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.colors.night.withValues(alpha: 0),
                              context.colors.night,
                            ],
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
      ),
    );
    return staggerPreview
        ? StaggeredEntrance(
            index: index + 1,
            replayKey: replayKey,
            axis: Axis.horizontal,
            reverse: reverse,
            child: box,
          )
        : box;
  }
}

/// A preview's own vertical scroll that, once it can't move any further in the
/// direction of the drag, passes that drag on to the page's scroll instead of
/// swallowing it. A nested scrollable normally keeps every drag that started
/// on it, which left the page stuck whenever a finger landed on a preview.
class _ChainedPreviewScroll extends StatefulWidget {
  const _ChainedPreviewScroll({
    required this.outer,
    required this.child,
    this.initialOffset = 0,
    this.onOffsetChanged,
  });

  final ScrollController outer;
  final Widget child;

  /// Where the preview starts scrolled, and a report of where it is scrolled.
  final double initialOffset;
  final ValueChanged<double>? onOffsetChanged;

  @override
  State<_ChainedPreviewScroll> createState() => _ChainedPreviewScrollState();
}

class _ChainedPreviewScrollState extends State<_ChainedPreviewScroll> {
  late final _inner = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  /// The offset still to restore: a preview whose content isn't tall enough
  /// yet (still loading) clamps it away, so it's re-applied once it grows.
  double? _pending;

  @override
  void initState() {
    super.initState();
    if (widget.initialOffset > 0) _pending = widget.initialOffset;
    _inner.addListener(() {
      if (_pending == null) widget.onOffsetChanged?.call(_inner.offset);
    });
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final pending = _pending;
    if (pending == null || !_inner.hasClients) return false;
    final max = notification.metrics.maxScrollExtent;
    if (max <= 0) return false;
    _pending = null;
    final target = pending.clamp(0.0, max);
    if (target != _inner.offset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _inner.hasClients) _inner.jumpTo(target);
      });
    }
    return false;
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  void _onMove(PointerMoveEvent event) {
    final outer = widget.outer;
    if (!_inner.hasClients || !outer.hasClients) return;
    final dy = event.delta.dy;
    final inner = _inner.position;
    final atStart = inner.pixels <= inner.minScrollExtent;
    final atEnd = inner.pixels >= inner.maxScrollExtent;
    // Finger down moves toward the start of the content, finger up toward
    // the end; at that edge the page takes the movement.
    if ((dy > 0 && atStart) || (dy < 0 && atEnd)) {
      final position = outer.position;
      outer.jumpTo(
        (position.pixels - dy).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerMove: _onMove,
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: SingleChildScrollView(
        controller: _inner,
        physics: const ClampingScrollPhysics(),
        // Breathing room at both ends, so at rest the fades don't sit on the
        // first and last lines; the content still scrolls under them.
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: widget.child,
      ),
    ),
  );
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.index,
    required this.replayKey,
    required this.reverse,
    required this.label,
    required this.onPressed,
  });
  final int index;
  final Object replayKey;
  final bool reverse;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => StaggeredEntrance(
    index: index,
    replayKey: replayKey,
    axis: Axis.horizontal,
    reverse: reverse,
    child: Center(
      child: ElevatedButton(
        // Flat: these sit among text, so no lit-button glow.
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        onPressed: onPressed,
        child: AppButtonLabel(label),
      ),
    ),
  );
}
