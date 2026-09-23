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
import '../theme/app_fonts.dart';
import '../utils/area_hero_art.dart';
import '../utils/area_hero_art_tone.dart';
import '../tutorials/tour_intro_target.dart';
import '../tutorials/tour_step_card.dart';

import '../widgets/responsive_content.dart';
import '../widgets/looping_hero_carousel.dart';
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
      if (mounted) Tour.read(context).start('supernova-vision');
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
      backgroundColor: Colors.black,
      body: SafeArea(
        left: false,
        right: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            ResponsiveContent(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, color: colors.muted),
                        ),
                        Text(
                          strings.visionsEyebrow,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.visionsTitle,
                      style: TextStyle(
                        fontFamily: kFontStarTitle,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.visionsSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TourIntroTarget(
                      tour: 'supernova-vision',
                      order: 1,
                      title: strings.supernovaTourIntroTitle,
                      description: strings.supernovaTourIntroBody,
                    ),
                  ],
                ),
              ),
            ),
            HintTarget(
              tour: 'supernova-vision',
              order: 2,
              showArrow: true,
              contentBuilder: appTourStepCard,
              title: strings.supernovaTourListTitle,
              description: strings.supernovaTourListBody,
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: (constraints.maxWidth * 1.15).clamp(340.0, 560.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LoopingHeroCarousel(
                        freeScroll: _freeScroll,
                        onTap: (index) => _openArea(LifeArea.values[index]),
                        children: [
                          for (final area in LifeArea.values)
                            _VisionCard(
                              area: area,
                              vision: widget.areaVisionRepository.getVision(
                                area,
                              ),
                            ),
                        ],
                      ),
                    ],
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
                    Semantics(
                      label: strings.carouselFreeScroll,
                      child: Switch(
                        value: _freeScroll,
                        onChanged: (value) =>
                            setState(() => _freeScroll = value),
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? const Color(0xFF0D1220)
                              : Colors.white,
                        ),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : const Color(0xFF0D1220),
                        ),
                        trackOutlineColor: const WidgetStatePropertyAll(
                          Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _freeScroll
                          ? strings.carouselFreeScroll
                          : strings.carouselOneAtATime,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          tonedAreaHeroArt(
            child: Image.asset(
              kAreaHeroArt[area]!.skyAsset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.transparent,
                  Color(0x99000000),
                  Color(0xF5000000),
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
