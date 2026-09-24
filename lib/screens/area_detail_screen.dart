import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/moodboard_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_fonts.dart';
import '../theme/life_area_theme.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/area_hero_art.dart';
import '../widgets/area_artwork_header.dart';
import '../widgets/area_section_header.dart';
import '../widgets/moodboard_grid.dart';
import '../widgets/reflection_questions_section.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/vision_markdown.dart';
import 'area_image_screen.dart';
import 'vision_editor_screen.dart';
import 'moodboard_screen.dart';

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

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  late final Future<MoodboardRepository> _moodboard =
      MoodboardRepository.create();

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
        await _open(MoodboardScreen(area: widget.area, repository: repository));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.moodboardSaveError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final area = widget.area;
    final asset = kAreaHeroArt[area]!.coverAsset;
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
          child: ResponsiveContent(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => CustomScrollView(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: AreaArtworkHeader(
                          asset: asset,
                          imageSize: math.min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          label: strings.viewAreaImageAction,
                          onTap: () => _open(AreaImageScreen(asset: asset)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            28,
                            36,
                            28,
                            32 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AreaSection(
                                index: 0,
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
                                    label: strings.areaSectionOpen,
                                    onPressed: () => _open(
                                      VisionEditorScreen(
                                        area: area,
                                        repository: widget.areaVisionRepository,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _AreaSection(
                                index: 2,
                                staggerPreview: false,
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
                                      items: snapshot.data!
                                          .getItems(area)
                                          .take(6)
                                          .toList(),
                                    );
                                  },
                                ),
                                action: _SectionButton(
                                  index: 4,
                                  label: strings.areaSectionOpen,
                                  onPressed: _openMoodboard,
                                ),
                              ),
                              _AreaSection(
                                index: 4,
                                title: strings.areaReflectionsTitle,
                                preview: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    label: strings.areaSectionOpen,
                                    onPressed: () => _open(
                                      Scaffold(
                                        backgroundColor: Colors.black,
                                        appBar: AppBar(
                                          elevation: 20,
                                          scrolledUnderElevation: 20,
                                          shadowColor: Colors.black,
                                          title: Text(
                                            area.displayName(strings),
                                          ),
                                        ),
                                        body: SafeArea(
                                          child: ResponsiveContent(
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: SingleChildScrollView(
                                                padding:
                                                    const EdgeInsets.all(20),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    StaggeredEntrance(
                                                      index: 0,
                                                      child: AreaSectionHeader(
                                                        title: strings
                                                            .areaReflectionsTitle,
                                                        description: strings
                                                            .reflectionsPageDescription,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 26),
                                                    ReflectionQuestionsSection(
                                                      area: area,
                                                      repository: widget
                                                          .reflectionAnswerRepository,
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: StaggeredEntrance(
                    index: 0,
                    axis: Axis.horizontal,
                    child: IconButton.filled(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
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

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.index,
    required this.title,
    required this.preview,
    required this.action,
    this.staggerPreview = true,
  });

  /// Entrance index of the title; the preview follows one step later. The
  /// [action] animates itself (it may be a tour target, which is never
  /// wrapped from outside).
  final int index;

  /// False when [preview] already staggers its own contents.
  final bool staggerPreview;
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
        _previewBox(),
        const SizedBox(height: 18),
        action,
      ],
    ),
  );

  Widget _previewBox() {
    final box = SizedBox(
      height: 300,
      child: ClipRect(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: preview,
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
    );
    return staggerPreview
        ? StaggeredEntrance(index: index + 1, child: box)
        : box;
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.index,
    required this.label,
    required this.onPressed,
  });
  final int index;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => StaggeredEntrance(
    index: index,
    child: Center(
      child: ElevatedButton.icon(
        style: buildLifeAreaTheme().elevatedButtonTheme.style,
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(label),
      ),
    ),
  );
}
