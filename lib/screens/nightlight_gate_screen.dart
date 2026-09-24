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
import '../widgets/nightlight_zone_measurer.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
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

class _NightlightGateScreenState extends State<NightlightGateScreen>
    with NightlightZoneMeasuring {
  late final BackgroundTrack _previousTrack =
      widget.audioService.backgroundTrack;

  final _titleKey = GlobalKey();
  final _questionKey = GlobalKey();
  final _okButtonKey = GlobalKey();
  final _crisisButtonKey = GlobalKey();

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
    // Establishes a dependency on the current screen size, so a resize (a
    // browser window, an orientation change) rebuilds this and, in turn,
    // re-measures the zones below against the new layout.
    MediaQuery.sizeOf(context);
    scheduleZoneMeasurement([
      _titleKey,
      _questionKey,
      _okButtonKey,
      _crisisButtonKey,
    ]);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
          key: stackKey,
          children: [
            // Kept clear of the title, the question, and both buttons —
            // see [NightlightZoneMeasuring] — measured off their own
            // actual, current position rather than a fixed guess, so this
            // stays correct across screen sizes instead of only fitting
            // whichever one it was tuned against.
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ResponsiveContent(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          // Title, question, and buttons all in this one
                          // centered column now — the same distance (98)
                          // between each of the 3 — rather than the title
                          // pinned near the top separately from the rest.
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StaggeredEntrance(
                                index: 1,
                                child: Text(
                                  'Nightlight',
                                  key: _titleKey,
                                  style: TextStyle(
                                    fontFamily: kFontBranding,
                                    fontSize: 56,
                                    color: colors.text,
                                    // Same layered soft-blur glow as
                                    // [NightlightStarfield]'s own stars —
                                    // white shadows rather than a painted
                                    // blur pass, since this is a [Text]
                                    // rather than a canvas shape.
                                    shadows: const [
                                      Shadow(color: Colors.white, blurRadius: 22),
                                      Shadow(
                                        color: Colors.white54,
                                        blurRadius: 42,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 98),
                              // The question's own two keywords bold —
                              // same words the two buttons below use — so
                              // the question and its matching answer read
                              // as connected at a glance.
                              StaggeredEntrance(
                                index: 2,
                                child: Text.rich(
                                  key: _questionKey,
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
                                    StaggeredEntrance(
                                      index: 3,
                                      child: ElevatedButton.icon(
                                        key: _okButtonKey,
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
                                    ),
                                    const SizedBox(height: 14),
                                    StaggeredEntrance(
                                      index: 4,
                                      child: OutlinedButton.icon(
                                        key: _crisisButtonKey,
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
