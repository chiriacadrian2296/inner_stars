import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/background_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
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
            const Positioned.fill(child: NightlightStarfield()),
            SafeArea(
              child: Column(
                children: [
                  ResponsiveContent(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: colors.nightlightMuted,
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Nightlight',
                                style: TextStyle(
                                  fontFamily: kFontBranding,
                                  fontSize: 40,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 40),
                              Text(
                                strings.nightlightGateQuestion,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.4,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _openOk,
                                  child: Text(strings.nightlightGateOk),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _openCrisis,
                                  child: Text(strings.nightlightGateCrisis),
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
