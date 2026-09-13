import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_glow.dart';
import '../widgets/area_tag.dart';
import '../widgets/responsive_content.dart';
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
      backgroundColor: colors.night,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ResponsiveContent(
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
                          color: colors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.visionsTitle,
                    style: TextStyle(
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
                  for (var i = 0; i < LifeArea.values.length; i++) ...[
                    if (i == 0)
                      HintTarget(
                        tour: 'supernova-vision',
                        order: 1,
                        pulse: true,
                        showArrow: true,
                        spotlightPadding: kTourGlowSpotlightPadding,
                        title: strings.supernovaTourListTitle,
                        description: strings.supernovaTourListBody,
                        child: TourGlow(
                          tour: 'supernova-vision',
                          order: 1,
                          color: colors.gold,
                          child: _VisionCard(
                            area: LifeArea.values[i],
                            vision: widget.areaVisionRepository.getVision(
                              LifeArea.values[i],
                            ),
                            onTap: () => _openArea(LifeArea.values[i]),
                          ),
                        ),
                      )
                    else
                      _VisionCard(
                        area: LifeArea.values[i],
                        vision: widget.areaVisionRepository.getVision(
                          LifeArea.values[i],
                        ),
                        onTap: () => _openArea(LifeArea.values[i]),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One supernova's row: its tag up top, then either the first few lines of
/// its vision or a muted "nothing written yet". The vision text is the
/// point of the card, so it gets the room — the stats live on the detail
/// page instead.
class _VisionCard extends StatelessWidget {
  const _VisionCard({
    required this.area,
    required this.vision,
    required this.onTap,
  });

  final LifeArea area;
  final String vision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final borderRadius = BorderRadius.circular(kRadiusCard);
    final trimmed = vision.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: panelDecoration(colors),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AreaTag(area: area, iconSize: 20, fontSize: 16),
                    ),
                    Icon(Icons.chevron_right, color: colors.muted, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trimmed.isEmpty ? strings.visionEmptyLabel : trimmed,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontStyle: trimmed.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: trimmed.isEmpty ? colors.muted : colors.text,
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
