import 'package:flutter/widgets.dart';

import 'life_area.dart';

enum ShareSubject { victory, goal, habit, project, vision, moodboard, quote }

/// A snapshot of the selected content. Styling this snapshot never writes back
/// to the source entity. Missing metadata stays absent instead of using samples.
class ShareContent {
  const ShareContent({
    required this.subject,
    required this.title,
    required this.typeLabel,
    this.description = '',
    this.area,
    this.areaLabel,
    this.projectLabel,
    this.dateLabel,
    this.statLabel,
    this.intensity,
    this.artwork,
    this.photos = const [],
    this.tiles = const [],
    this.heroValue,
    this.heroCaption,
    this.completed,
    this.total,
    this.isReflection = false,
  });
  final ShareSubject subject;
  final String title;
  final String typeLabel;
  final String description;
  final LifeArea? area;
  final String? areaLabel;
  final String? projectLabel;
  final String? dateLabel;
  final String? statLabel;
  final int? intensity;
  final Widget? artwork;
  final List<String> photos;

  /// One ready-made widget per moodboard item, in order; the moodboard
  /// compositions arrange all of them instead of one scrolling [artwork].
  final List<Widget> tiles;
  final String? heroValue;
  final String? heroCaption;
  final int? completed;
  final int? total;
  final bool isReflection;
}
