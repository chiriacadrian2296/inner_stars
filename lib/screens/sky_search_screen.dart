import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/sky_explorer_view.dart';

/// A full-screen popup opened from the Sky's sky-search overlay
/// button — search/filter/3-level browsing ([SkyExplorerView]).
/// Every card's "take me there" button pops this page with a
/// `SkyNavigationTarget` for `SkyScreen` to fly its camera to.
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
    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
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
    );
  }
}
