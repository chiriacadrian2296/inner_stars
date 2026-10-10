import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import 'star_form_screen.dart';

/// Opens the one creation page — a constellation or a star of any kind,
/// chosen by its tiles at the top — saves whatever it returns, and hands
/// back what was created: a [Project], a [Star] or a [Habit] (a pulsar), or
/// null when the page was closed without saving.
///
/// [constellation] opens on the constellation tile; [area] pre-fills the
/// area. Shared by every "add" button so they all land on the same page.
Future<Object?> showCreatePage(
  BuildContext context, {
  required ProjectRepository projectRepository,
  required StarsShapeRepository starsShapeRepository,
  required StarRepository starRepository,
  required HabitRepository habitRepository,
  bool constellation = false,
  LifeArea? area,
}) async {
  final result = await Navigator.of(context).push<Object>(
    MaterialPageRoute(
      builder: (_) => StarFormScreen(
        projectRepository: projectRepository,
        starsShapeRepository: starsShapeRepository,
        allowConstellation: true,
        startAsConstellation: constellation,
        presetArea: area,
      ),
    ),
  );
  if (result is Project) return result;
  if (result is! StarFormResult) return null;

  if (result.kind == StarKind.pulsar) {
    return habitRepository.add(
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      intensity: result.intensity ?? 3,
      frequency: result.habitFrequency ?? HabitFrequency.daily,
      targetPerPeriod: result.habitTargetPerPeriod ?? 1,
      reminderHour: result.reminderHour,
      reminderMinute: result.reminderMinute,
    );
  }
  return starRepository.add(
    title: result.title,
    description: result.description,
    projectId: result.projectId,
    slotSequence: result.slotSequence,
    targetDate: result.targetDate,
    achievedDate: result.achievedDate,
    intensity: result.intensity,
    photoPath: result.photoPath,
    media: result.media,
  );
}
