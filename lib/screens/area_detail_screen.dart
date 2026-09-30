import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/moodboard_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../models/star_kind.dart';
import '../theme/app_fonts.dart';
import '../theme/life_area_theme.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/area_hero_art.dart';
import '../utils/area_hero_art_tone.dart';
import '../widgets/area_section_header.dart';
import '../widgets/moodboard_grid.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/reflection_questions_section.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/vision_markdown.dart';
import 'vision_editor_screen.dart';
import 'moodboard_screen.dart';
import 'new_project_screen.dart';

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
  });
  final LifeArea area;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

/// The full reflection editor, shared by an area's section action and dock.
class AreaReflectionsScreen extends StatelessWidget {
  const AreaReflectionsScreen({
    super.key,
    required this.area,
    required this.repository,
  });

  final LifeArea area;
  final ReflectionAnswerRepository repository;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ResponsiveContent(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredEntrance(
                        index: 0,
                        child: AreaSectionHeader(
                          title:
                              '${strings.areaReflectionsTitle} - ${area.displayName(strings)}',
                          description: strings.reflectionsPageDescription,
                        ),
                      ),
                      const SizedBox(height: 26),
                      ReflectionQuestionsSection(area: area, repository: repository),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  late LifeArea _area;
  bool _contentReverse = false;
  bool _hasNavigatedAreas = false;
  late final Future<MoodboardRepository> _moodboard =
      MoodboardRepository.create();
  late final Future<StarsShapeRepository> _starsShapes =
      StarsShapeRepository.create();

  @override
  void initState() {
    super.initState();
    _area = widget.area;
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
    final theme = buildLifeAreaTheme();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Theme(data: theme, child: page),
      ),
    );
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

  Future<void> _openNewConstellation() async {
    final starsShapeRepository = await _starsShapes;
    if (!mounted) return;
    await _open(
      NewProjectScreen(
        projectRepository: widget.projectRepository,
        starsShapeRepository: starsShapeRepository,
        presetArea: _area,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final area = _area;
    final vision = widget.areaVisionRepository.getVision(area);
    final questions = area.reflectionQuestions(strings);
    final answers = widget.reflectionAnswerRepository.getAnswersForArea(area);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: ResponsiveContent(
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
                                child: SizedBox(
                                  width: double.infinity,
                                  child: tonedAreaHeroArt(
                                    child: Image.asset(
                                      kAreaHeroArt[area]!.skyAsset,
                                      width: constraints.maxWidth,
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              28,
                              36,
                              28,
                              80 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AreaSection(
                                  index: 0,
                                  replayKey: area,
                                  reverse: _contentReverse,
                                  title: strings.areaCoverVisionTitle,
                                  preview: VisionMarkdown(
                                    data: vision.trim().isEmpty
                                        ? area.visionPlaceholder(strings)
                                        : vision,
                                    color: Colors.white,
                                  ),
                                  action: HintTarget(
                                    tour: 'supernova-vision',
                                    order: 3,
                                    showArrow: true,
                                    contentBuilder: appTourStepCard,
                                    title: strings.supernovaTourEditTitle,
                                    description: strings.supernovaTourEditBody,
                                    child: _SectionButton(
                                      index: 2,
                                      replayKey: area,
                                      reverse: _contentReverse,
                                      label: strings.areaSectionOpen,
                                      onPressed: () => _open(
                                        VisionEditorScreen(
                                          area: area,
                                          repository:
                                              widget.areaVisionRepository,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _AreaSection(
                                  index: 2,
                                  replayKey: area,
                                  reverse: _contentReverse,
                                  staggerPreview: false,
                                  showWatermark: false,
                                  title: strings.moodboardTitle,
                                  preview: FutureBuilder<MoodboardRepository>(
                                    future: _moodboard,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return Text(strings.moodboardSaveError);
                                      }
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                      return MoodboardGrid(
                                        placeholders: true,
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
                                  index: 4,
                                  replayKey: area,
                                  reverse: _contentReverse,
                                  title: strings.areaReflectionsTitle,
                                  preview: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${answers.length}/${questions.length} ${strings.reflectionAnsweredCountLabel}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      for (
                                        var i = 0;
                                        i < questions.length;
                                        i++
                                      ) ...[
                                        Text(
                                          questions[i],
                                          style: const TextStyle(
                                            fontFamily: kFontStarTitle,
                                            fontSize: 18,
                                            height: 1.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          answers['$i']?.answerText ??
                                              strings.reflectionAnswerHint,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                      ],
                                    ],
                                  ),
                                  action: HintTarget(
                                    tour: 'supernova-vision',
                                    order: 4,
                                    showArrow: true,
                                    contentBuilder: appTourStepCard,
                                    title: strings.supernovaTourReflectionTitle,
                                    description:
                                        strings.supernovaTourReflectionBody,
                                    child: _SectionButton(
                                      index: 6,
                                      replayKey: area,
                                      reverse: _contentReverse,
                                      label: strings.areaSectionOpen,
                                      onPressed: () => _open(
                                        AreaReflectionsScreen(
                                          area: area,
                                          repository:
                                              widget.reflectionAnswerRepository,
                                        ),
                                      ),
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
              );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _AreaDock(
                    animate: !_hasNavigatedAreas,
                    onVision: () => _open(
                      VisionEditorScreen(
                        area: area,
                        repository: widget.areaVisionRepository,
                      ),
                    ),
                    onMoodboard: _openMoodboard,
                    onReflections: () => _open(
                      AreaReflectionsScreen(
                        area: area,
                        repository: widget.reflectionAnswerRepository,
                      ),
                    ),
                    onNewConstellation: _openNewConstellation,
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
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    elevation: 20,
    shadowColor: Colors.black,
    surfaceTintColor: Colors.transparent,
    child: SizedBox(
      height: 64,
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
              icon: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
          Expanded(
            child: StaggeredEntrance(
              replayKey: replayKey,
              index: 1,
              axis: Axis.horizontal,
              reverse: reverse,
              enabled: animate,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kFontStarTitle,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
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
              icon: const Icon(Icons.chevron_right, color: Colors.white),
            ),
          ),
        ],
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
  });

  final bool animate;
  final VoidCallback onVision;
  final VoidCallback onMoodboard;
  final VoidCallback onNewConstellation;
  final VoidCallback onReflections;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.9),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StaggeredEntrance(
            index: 0,
            enabled: animate,
            drift: 0.7,
            child: _AreaDockAction(
              icon: Icons.edit_outlined,
              label: 'Vision',
              onTap: onVision,
            ),
          ),
          const SizedBox(width: 8),
          StaggeredEntrance(
            index: 1,
            enabled: animate,
            drift: 0.7,
            child: _AreaDockAction(
              icon: Icons.photo_library_outlined,
              label: 'Moodboard',
              onTap: onMoodboard,
            ),
          ),
          const SizedBox(width: 8),
          StaggeredEntrance(
            index: 2,
            enabled: animate,
            drift: 0.7,
            child: _AreaDockAction(
              icon: Icons.auto_stories_outlined,
              label: 'Riflessioni',
              onTap: onReflections,
            ),
          ),
          const SizedBox(width: 8),
          StaggeredEntrance(
            index: 3,
            enabled: animate,
            drift: 0.7,
            child: _AreaDockAction(
              icon: Icons.insights,
              label: '+ Costellazione',
              onTap: onNewConstellation,
            ),
          ),
          const SizedBox(width: 8),
          StaggeredEntrance(
            index: 4,
            enabled: animate,
            drift: 0.7,
            child: _AreaDockAction(
              icon: Icons.navigation,
              label: 'Vola',
              onTap: onReflections,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Same compact, phone-width 48 px action geometry as the Star Reader dock.
/// Area actions intentionally stay icon-only: this dock sits below rich
/// content, so a white disc behind every action pulls attention away from it.
class _AreaDockAction extends StatelessWidget {
  const _AreaDockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: Colors.white),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      splashRadius: 24,
    ),
  );
}

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.index,
    required this.replayKey,
    required this.reverse,
    required this.title,
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
  final bool staggerPreview;
  final bool showWatermark;
  final String title;
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
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kFontBranding,
              fontSize: 30,
              color: Colors.white,
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

  Widget _previewBox(BuildContext context) {
    final box = SizedBox(
      height: 300,
      child: ClipRect(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: ScrollbarTheme(
              data: ScrollbarTheme.of(context).copyWith(minThumbLength: 10),
              // The thumb is painted after the Stack, while the fades still
              // stay above the preview content. Its track can therefore run
              // to the real bottom edge of the preview.
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
                    SingleChildScrollView(child: preview),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black, Colors.transparent],
                            stops: [0, 0.22],
                          ),
                        ),
                      ),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                            stops: [0.78, 1],
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
      child: ElevatedButton.icon(
        style: buildLifeAreaTheme().elevatedButtonTheme.style!.copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Colors.white, width: 2),
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: Text(label.toUpperCase()),
      ),
    ),
  );
}
