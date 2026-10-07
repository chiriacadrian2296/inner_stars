import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:markdown/markdown.dart' as markdown;

import '../data/area_vision_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../utils/page_settled.dart';
import '../theme/app_fonts.dart';
import '../utils/area_hero_art.dart';
import '../utils/area_hero_art_tone.dart';
import '../tutorials/tour_step_card.dart';
import '../tutorials/tutorial_replay.dart';

import '../widgets/responsive_content.dart';
import '../widgets/looping_hero_carousel.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/vision_markdown.dart';
import 'area_detail_screen.dart';

/// All 8 supernovas in one place, each showing the vision written for it —
/// the third thing the Sky menu lets you do, alongside lighting a star and
/// drawing a constellation.
///
/// This one isn't about making anything: it's for coming back to what you
/// said you wanted, re-reading it, and revising it as you change. Tapping a
/// supernova opens its own page ([AreaDetailScreen]), which is where the
/// vision is actually edited.
class VisionsScreen extends StatefulWidget {
  const VisionsScreen({
    super.key,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.projectRepository,
    required this.starRepository,
  });

  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;

  @override
  State<VisionsScreen> createState() => _VisionsScreenState();
}

class _VisionsScreenState extends State<VisionsScreen> {
  bool _freeScroll = false;

  @override
  void initState() {
    super.initState();
    // The "supernova-vision" tour — continues into [AreaDetailScreen]'s
    // own edit-vision button once the user taps through.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      whenPageSettled(context, () {
        startTourAuto(Tour.read(context), 'supernova-vision');
      });
    });
  }

  Future<void> _openArea(LifeArea area) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailScreen(
          area: area,
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
          projectRepository: widget.projectRepository,
          starRepository: widget.starRepository,
        ),
      ),
    );
    // A vision edited on the detail page has to show through here on the
    // way back — this list reads straight from the repository, so a plain
    // rebuild is all it takes.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              // Starts near the top, under the title, rather than centering
              // the whole page vertically.
              padding: const EdgeInsets.only(top: 20, bottom: 24),
              children: [
                ResponsiveContent(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StaggeredEntrance(
                          index: 0,
                          child: Text(
                            strings.areasTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: kFontStarTitle,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        StaggeredEntrance(
                          index: 0,
                          child: Text(
                            strings.visionsSubtitle,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: colors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
                ResponsiveContent(
                  child: HintTarget(
                    tour: 'supernova-vision',
                    order: 1,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.supernovaTourListTitle,
                    description: strings.supernovaTourListBody,
                    child: StaggeredEntrance(
                      index: 1,
                      child: LayoutBuilder(
                        builder: (context, constraints) => SizedBox(
                          height: (constraints.maxWidth * 1.15).clamp(
                            340.0,
                            560.0,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              LoopingHeroCarousel(
                                freeScroll: _freeScroll,
                                onTap: (index) =>
                                    _openArea(LifeArea.values[index]),
                                children: [
                                  for (final area in LifeArea.values)
                                    _VisionCard(
                                      area: area,
                                      vision: widget.areaVisionRepository
                                          .getVision(area),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ResponsiveContent(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        StaggeredEntrance(
                          index: 2,
                          child: Semantics(
                            label: strings.carouselFreeScroll,
                            child: Switch(
                              value: _freeScroll,
                              onChanged: (value) =>
                                  setState(() => _freeScroll = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        StaggeredEntrance(
                          index: 2,
                          child: Text(
                            _freeScroll
                                ? strings.carouselFreeScroll
                                : strings.carouselOneAtATime,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Artwork remains visible in the narrow previews beside the hero card.
class _VisionCard extends StatelessWidget {
  const _VisionCard({required this.area, required this.vision});

  final LifeArea area;
  final String vision;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final trimmed = vision.trim();
    final side = HeroCarouselEmphasis.sideOf(context);
    final preview = trimmed.isEmpty
        ? strings.visionEmptyLabel
        : markdown.Document(
                encodeHtml: false,
                inlineSyntaxes: [VisionUnderlineSyntax()],
              )
              .parseLines(trimmed.split('\n'))
              .map((node) => node.textContent)
              .join('\n');
    return Semantics(
      label: area.displayName(strings),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.colors.nightPanel),
          // The artwork sits a little smaller, centered in the card, rather
          // than filling it; the card itself keeps its size.
          LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.04,
              ),
              child: Align(
                alignment: Alignment.center,
                child: tonedAreaHeroArt(
                  child: Image.asset(
                    kAreaHeroArt[area]!.skyAsset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.night.withValues(alpha: 0),
                  context.colors.night.withValues(alpha: 0.6),
                  context.colors.night.withValues(alpha: 0.96),
                ],
                stops: [0.45 - 0.3 * side, 0.78 - 0.18 * side, 1],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 160) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.displayName(strings),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kFontStarTitle,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontStarTitle,
                        fontSize: 15,
                        height: 1.45,
                        fontStyle: trimmed.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: const Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
