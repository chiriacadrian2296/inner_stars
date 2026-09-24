import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/constellation_field.dart' show kSkyStarPalette;
import '../widgets/constellation_painter.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/star_glyph.dart';

/// The metaphor, written down in one place: what a supernova, a
/// constellation and a star each stand for, how they nest, and what each of
/// the five kinds of star means — every level with a name, a plain-words
/// meaning, a short explanation, examples, and a picture of the real thing
/// as the app actually draws it.
///
/// Reachable any time from the menu's Info section. Deliberately a reference
/// you can come back to rather than a tutorial you sit through once —
/// that's what onboarding is for, and this is the page onboarding is a
/// summary of.
class MetaphorScreen extends StatefulWidget {
  const MetaphorScreen({super.key});

  @override
  State<MetaphorScreen> createState() => _MetaphorScreenState();
}

class _MetaphorScreenState extends State<MetaphorScreen> {
  /// Loaded the same way every other screen that draws constellations
  /// loads it — without it the sample constellation below renders its
  /// unlit/nascent stars but no glow on the lit ones, so the picture would
  /// quietly contradict the text next to it.
  ui.FragmentProgram? _flareProgram;

  @override
  void initState() {
    super.initState();
    _loadFlareProgram();
  }

  Future<void> _loadFlareProgram() async {
    final program = await buildConstellationFlareProgram();
    if (!mounted) return;
    setState(() => _flareProgram = program);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, color: colors.muted),
                        ),
                        Text(
                          strings.guideEyebrow,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                            color: colors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      strings.guideTitle,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      strings.guideIntroBody,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Biggest to smallest, in the order the sky itself nests
                  // — a star sits in a constellation, which sits in a
                  // supernova. Reading top to bottom is reading inward.
                  StaggeredEntrance(
                    index: 1,
                    child: _LevelSection(
                      title: strings.guideAreaTitle,
                      meaning: strings.guideAreaMeaning,
                      body: strings.guideAreaBody,
                      examples: strings.guideAreaExamples,
                      picture: const _SupernovaPicture(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StaggeredEntrance(
                    index: 2,
                    child: _LevelSection(
                      title: strings.guideConstellationTitle,
                      meaning: strings.guideConstellationMeaning,
                      body: strings.guideConstellationBody,
                      examples: strings.guideConstellationExamples,
                      picture: _ConstellationPicture(
                        flareProgram: _flareProgram,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StaggeredEntrance(
                    index: 3,
                    child: _LevelSection(
                      title: strings.guideStarTitle,
                      meaning: strings.guideStarMeaning,
                      body: strings.guideStarBody,
                      examples: strings.guideStarExamples,
                      picture: const _StarKindsRow(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggeredEntrance(
                    index: 4,
                    child: _SectionHeading(strings.guideKindsTitle),
                  ),
                  const SizedBox(height: 6),
                  StaggeredEntrance(
                    index: 4,
                    child: Text(
                      strings.guideKindsBody,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final kind in StarKind.values) ...[
                    StaggeredEntrance(
                      index: 5 + kind.index,
                      child: _KindCard(kind: kind),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 18),
                  StaggeredEntrance(
                    index: 4,
                    child: _SectionHeading(strings.guideIntensityTitle),
                  ),
                  const SizedBox(height: 6),
                  StaggeredEntrance(
                    index: 4,
                    child: Text(
                      strings.guideIntensityBody,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.muted,
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

/// One level of the sky — supernova, constellation, or star. Same shape
/// every time: the picture first (this page is about what things *look*
/// like as much as what they mean), then the name, the plain-words meaning,
/// the explanation, and the examples.
class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.title,
    required this.meaning,
    required this.body,
    required this.examples,
    required this.picture,
  });

  final String title;
  final String meaning;
  final String body;
  final String examples;
  final Widget picture;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      decoration: panelDecoration(colors),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Center(child: picture),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 1,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.gold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          StaggeredEntrance(
            index: 2,
            child: Text(
              meaning,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(height: 10),
          StaggeredEntrance(
            index: 3,
            child: Text(
              body,
              style: TextStyle(fontSize: 14, height: 1.5, color: colors.muted),
            ),
          ),
          const SizedBox(height: 12),
          StaggeredEntrance(
            index: 4,
            child: Text(
              strings.examplesLabel,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: colors.accentDim,
              ),
            ),
          ),
          const SizedBox(height: 4),
          StaggeredEntrance(
            index: 4,
            child: Text(
              examples,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: context.colors.text,
      ),
    );
  }
}

/// One of the five kinds: its own glyph, its name, what it means in plain
/// words, and a real example of the kind of thing it stands for.
class _KindCard extends StatelessWidget {
  const _KindCard({required this.kind});

  final StarKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      decoration: panelDecoration(colors),
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredEntrance(
            index: 0,
            axis: Axis.horizontal,
            child: StarGlyph(kind: kind, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StaggeredEntrance(
              index: 1,
              axis: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind.label(strings),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: starKindColor(kind, colors),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind.meaning(strings),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kind.example(strings),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A supernova the way the sky draws one: a white area glyph inside a gold
/// gradient ring, burning outward. Uses the Physical area's icon purely as
/// a stand-in — the point is the light around it, not which area it is.
class _SupernovaPicture extends StatelessWidget {
  const _SupernovaPicture();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.gold.withValues(alpha: 0.55),
            colors.gold.withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: colors.gold.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.gold.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(LifeArea.physical.icon, color: Colors.white, size: 38),
    );
  }
}

/// A sample constellation, painted by the very same [ConstellationPainter]
/// the sky itself uses — not an illustration of it. Four slots on the
/// shape, deliberately in four different states (two lit, one unlit, one
/// still nascent) plus a pulsar scattered off the shape, so the text about
/// "the shape is there from the first day" has the picture to match.
class _ConstellationPicture extends StatelessWidget {
  const _ConstellationPicture({required this.flareProgram});

  final ui.FragmentProgram? flareProgram;

  static const _stars = [
    ConstellationStar(
      entityId: 1,
      position: Offset(0.20, 0.72),
      kind: StarKind.lit,
      lit: true,
      label: '',
      slotSequence: 1,
    ),
    ConstellationStar(
      entityId: 2,
      position: Offset(0.42, 0.30),
      kind: StarKind.lit,
      lit: true,
      label: '',
      slotSequence: 2,
    ),
    ConstellationStar(
      entityId: 3,
      position: Offset(0.66, 0.56),
      kind: StarKind.unlit,
      lit: false,
      label: '',
      slotSequence: 3,
    ),
    ConstellationStar(
      entityId: 4,
      position: Offset(0.84, 0.22),
      kind: StarKind.nascent,
      lit: false,
      label: '',
      slotSequence: 4,
    ),
    ConstellationStar(
      entityId: 5,
      position: Offset(0.55, 0.85),
      kind: StarKind.pulsar,
      lit: true,
      label: '',
    ),
  ];

  static const _edges = [(0, 1), (1, 2), (2, 3)];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: ConstellationPainter(
          stars: _stars,
          flareProgram: flareProgram,
          // Fixed: nothing about this sample ever changes, so the only
          // repaint it needs is the one when the shader finishes loading —
          // which the painter already catches through [flareProgram].
          revision: 0,
          palette: kSkyStarPalette,
          edges: _edges,
          lineWidthScale: 3.5,
          lineAlpha: 0.9,
          // Bolder than the sky's own 2.2: at 200px this preview is a
          // fraction of a real constellation's on-screen size, and the
          // painter scales every mark to its canvas, so without this the
          // unlit and nascent stars come out as specks.
          sparkleScale: 4,
        ),
      ),
    );
  }
}

/// The five kinds side by side, each drawn the way the sky draws it — the
/// picture for the "star" level, since what a star *looks* like is exactly
/// what its kind decides.
class _StarKindsRow extends StatelessWidget {
  const _StarKindsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        for (final kind in StarKind.values)
          StaggeredEntrance(
            index: kind.index,
            axis: Axis.horizontal,
            child: StarGlyph(kind: kind, size: 26),
          ),
      ],
    );
  }
}

/// Kept out of `StarKindX` itself: an example only ever belongs on this
/// page, and the extension is imported nearly everywhere.
extension _StarKindExample on StarKind {
  String example(AppStrings s) => switch (this) {
    StarKind.nascent => s.starKindNascentExample,
    StarKind.lit => s.starKindLitExample,
    StarKind.unlit => s.starKindUnlitExample,
    StarKind.pulsar => s.starKindPulsarExample,
    StarKind.dead => s.starKindDeadExample,
  };
}
