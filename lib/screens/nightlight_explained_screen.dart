import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import 'nightlight_breathing_screen.dart';

/// The second screen of the Nightlight "in crisis" path — reached from
/// [NightlightGateScreen], leads into [NightlightBreathingScreen]. Explains
/// *why* the breathing exercise comes before the victories: an agitated
/// mind finds plausible-sounding reasons to dismiss good news, so it needs
/// to settle first or looking at those victories risks doing nothing (or
/// worse, backfiring).
class NightlightExplainedScreen extends StatelessWidget {
  const NightlightExplainedScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

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
                            Icons.arrow_back,
                            color: colors.nightlightMuted,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst),
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
                          child: Text(
                            strings.nightlightExplainedBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.6,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ResponsiveContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NightlightBreathingScreen(
                                starRepository: starRepository,
                                projectRepository: projectRepository,
                                starsShapeRepository: starsShapeRepository,
                              ),
                            ),
                          ),
                          child: Text(strings.nightlightExplainedContinue),
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
