import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_content.dart';
import '../widgets/sky_explorer_view.dart';
import '../widgets/staggered_entrance.dart';

/// Popped by [SkySearchScreen]'s own explicit close button — same
/// "close whatever menu opened this" signal a real `SkyNavigationTarget`
/// (a card's "take me there") already carries, just without any camera
/// movement to go with it. A plain back (the header's arrow, or a system
/// back gesture) pops with neither, which is exactly what tells
/// `SkyScreen._openSearch` to leave that menu open behind it instead —
/// most likely a peek that wasn't meant to go anywhere.
class SkySearchClosed {
  const SkySearchClosed();
}

/// A full-screen popup opened from the Sky's sky-search overlay
/// button — search/filter/3-level browsing ([SkyExplorerView]), under a
/// slim back-arrow/eyebrow header (the selected level is already shown by
/// [SkyExplorerView]'s own mode switch, so it isn't repeated up here).
/// Every card's "take me there" button pops this page with a
/// `SkyNavigationTarget` for `SkyScreen` to fly its camera to; the header's
/// own close button (see [SkySearchClosed]) pops with that instead, for a
/// deliberate "I'm done here" that a plain back doesn't mean.
class SkySearchScreen extends StatefulWidget {
  const SkySearchScreen({
    super.key,
    required this.projectRepository,
    required this.starRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
  });

  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;

  @override
  State<SkySearchScreen> createState() => _SkySearchScreenState();
}

class _SkySearchScreenState extends State<SkySearchScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: ResponsiveContent(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.arrow_back, color: colors.muted),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        strings.searchScreenEyebrow,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: colors.accentDim,
                        ),
                      ),
                      const Spacer(),
                      // Deliberate "I'm done here" — closes whichever menu
                      // opened this popup along with the popup itself (see
                      // [SkySearchClosed]), unlike the plain back arrow
                      // above, which leaves that menu open behind it.
                      IconButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop<Object>(const SkySearchClosed()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: strings.closeAction,
                        icon: Icon(Icons.close, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SkyExplorerView(
                projectRepository: widget.projectRepository,
                starRepository: widget.starRepository,
                habitRepository: widget.habitRepository,
                habitCompletionRepository: widget.habitCompletionRepository,
                starsShapeRepository: widget.starsShapeRepository,
                areaVisionRepository: widget.areaVisionRepository,
                reflectionAnswerRepository: widget.reflectionAnswerRepository,
                onNavigateTo: (target) => Navigator.of(context).pop(target),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
