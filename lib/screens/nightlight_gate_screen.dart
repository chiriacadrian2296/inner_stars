import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/background_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/nightlight_style.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import 'admire_stars_screen.dart';
import 'nightlight_explained_screen.dart';

/// The first screen of the Nightlight flow — reached from the Sky menu's
/// "Find Your Light" entry (see `sky_screen.dart`'s `_openNightlight`).
/// Asks a single calm-check question before anything else: "sto bene" skips
/// straight to [AdmireStarsScreen], "sono in crisi" first goes through
/// [NightlightExplainedScreen] and the breathing exercise. This screen is
/// the flow's single entry/exit point, so it's also the one place that
/// switches the background music to [BackgroundTrack.nightlight] and
/// restores whatever was playing before once the whole flow is left.
class NightlightGateScreen extends StatefulWidget {
  const NightlightGateScreen({
    super.key,
    required this.audioService,
    required this.starRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final AudioService audioService;
  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<NightlightGateScreen> createState() => _NightlightGateScreenState();
}

class _NightlightGateScreenState extends State<NightlightGateScreen> {
  late final BackgroundTrack _previousTrack =
      widget.audioService.backgroundTrack;

  @override
  void initState() {
    super.initState();
    widget.audioService.setBackgroundTrack(BackgroundTrack.nightlight);
  }

  @override
  void dispose() {
    widget.audioService.setBackgroundTrack(_previousTrack);
    super.dispose();
  }

  void _openOk() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdmireStarsScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
  }

  void _openCrisis() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NightlightExplainedScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
          children: [
            // Kept clear of a band directly behind the title text itself
            // — see [NightlightStarfield.exclusionZones] — narrow enough
            // that stars still show up above it and to either side, just
            // not drifting across the word itself.
            Positioned.fill(
              child: NightlightStarfield(
                exclusionZones: [Rect.fromLTWH(0.2, 0.11, 0.6, 0.15)],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  ResponsiveContent(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveContent(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 36, bottom: 4),
                      child: Text(
                        'Nightlight',
                        style: TextStyle(
                          fontFamily: kFontBranding,
                          fontSize: 56,
                          color: colors.text,
                          // Same layered soft-blur glow as
                          // [NightlightStarfield]'s own stars — white
                          // shadows rather than a painted blur pass, since
                          // this is a [Text] rather than a canvas shape.
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 22),
                            Shadow(color: Colors.white54, blurRadius: 42),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ResponsiveContent(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The question's own two keywords bold —
                              // same words the two buttons below use — so
                              // the question and its matching answer read
                              // as connected at a glance.
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 27,
                                    height: 1.35,
                                    color: colors.text,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          strings.nightlightGateQuestionPrefix,
                                    ),
                                    TextSpan(
                                      text:
                                          strings.nightlightGateQuestionOkWord,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          strings.nightlightGateQuestionMiddle,
                                    ),
                                    TextSpan(
                                      text: strings
                                          .nightlightGateQuestionCrisisWord,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          strings.nightlightGateQuestionSuffix,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 98),
                              // Both buttons stretched to match the wider
                              // of the two labels ("I'm in crisis" needs
                              // more room than "I'm okay") rather than each
                              // sized to its own — and both sized to that
                              // shared width rather than the full screen.
                              IntrinsicWidth(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _openOk,
                                      style: nightlightButtonStyle(colors),
                                      icon: const Icon(
                                        Icons.thumb_up_alt_outlined,
                                      ),
                                      label: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: strings
                                                  .nightlightGateOkPrefix,
                                            ),
                                            TextSpan(
                                              text:
                                                  strings.nightlightGateOkWord,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: _openCrisis,
                                      style: nightlightOutlinedButtonStyle(
                                        colors,
                                      ),
                                      icon: const Icon(
                                        Icons.thumb_down_alt_outlined,
                                      ),
                                      label: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: strings
                                                  .nightlightGateCrisisPrefix,
                                            ),
                                            TextSpan(
                                              text: strings
                                                  .nightlightGateCrisisWord,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
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
