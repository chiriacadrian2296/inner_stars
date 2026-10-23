import 'package:flutter/material.dart';

import '../data/moodboard_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/life_area.dart';
import '../models/share_content.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../widgets/constellation_editor_painter.dart';
import '../widgets/moodboard_grid.dart';
import '../screens/share_composer_screen.dart';
import '../widgets/shareable_area_content_card.dart';
import '../widgets/shareable_constellation_card.dart';
import '../widgets/shareable_goal_card.dart';
import '../widgets/shareable_lit_star_card.dart';
import '../widgets/shareable_pulsar_card.dart';
import '../widgets/shareable_reflection_card.dart';
import 'date_format.dart';

/// Adapt the real card at the common share entry point, keeping all callers on
/// one composer and deriving the content type from their selected entity.
ShareContent shareContentFromCard(BuildContext context, Widget card) {
  final strings = context.strings;
  if (card is ShareableLitStarCard || card is ShareableGoalCard) {
    final lit = card is ShareableLitStarCard;
    final star = lit ? card.star : (card as ShareableGoalCard).star;
    final project = lit ? card.project : (card as ShareableGoalCard).project;
    final date = lit ? star.achievedDate : star.targetDate;
    return ShareContent(
      subject: lit ? ShareSubject.victory : ShareSubject.goal,
      title: star.displayTitle,
      description: star.description ?? '',
      typeLabel: (lit ? StarKind.lit : StarKind.unlit).label(strings),
      area: project?.area,
      areaLabel: project?.area.displayName(strings),
      projectLabel: project?.displayName,
      dateLabel: date == null ? null : formatDisplayDate(date, strings),
      intensity: star.intensity,
      photos: star.photoPath == null ? const [] : [star.photoPath!],
      artwork: Icon(
        lit ? Icons.star : Icons.star_border,
        size: 72,
        color: context.colors.gold,
      ),
    );
  }
  if (card is ShareablePulsarCard) {
    final habit = card.habit;
    return ShareContent(
      subject: ShareSubject.habit,
      title: habit.displayTitle,
      description: habit.description ?? '',
      typeLabel: StarKind.pulsar.label(strings),
      area: card.project?.area,
      areaLabel: card.project?.area.displayName(strings),
      projectLabel: card.project?.displayName,
      intensity: habit.intensity,
      dateLabel: formatDisplayDate(habit.createdAt, strings),
      statLabel: strings.cycleHistoryItem(habit.cycleLength),
      artwork: Icon(StarKind.pulsar.icon, size: 72, color: context.colors.gold),
    );
  }
  if (card is ShareableConstellationCard) {
    final shape = card.shape;
    return ShareContent(
      subject: ShareSubject.project,
      title: card.project.displayName,
      description: card.project.description ?? '',
      typeLabel: strings.projectLabel,
      area: card.project.area,
      areaLabel: card.project.area.displayName(strings),
      dateLabel: formatDisplayDate(card.project.createdAt, strings),
      artwork: LayoutBuilder(
        builder: (context, bounds) => CustomPaint(
          size: Size(bounds.maxWidth, bounds.maxHeight),
          painter: ConstellationEditorPainter(
            points: [
              for (final p in shape.points)
                Offset(
                  20 + p.dx * (bounds.maxWidth - 40),
                  20 + p.dy * (bounds.maxHeight - 40),
                ),
            ],
            edges: shape.edges,
            highlightedIndex: null,
            pointColor: context.colors.gold,
            highlightColor: context.colors.gold,
            lineColor: context.colors.text.withValues(alpha: .5),
            pointRadius: 4,
          ),
        ),
      ),
    );
  }
  if (card is ShareableVisionCard) {
    return ShareContent(
      subject: ShareSubject.vision,
      title: strings.visionSection,
      description: card.vision
          .replaceAll(RegExp(r'[#*_>`]'), '')
          .replaceAll(RegExp(r'<\/?u>'), '')
          .trim(),
      typeLabel: strings.visionSection,
      area: card.area,
      areaLabel: card.area.displayName(strings),
    );
  }
  if (card is ShareableMoodboardCard) {
    return ShareContent(
      subject: ShareSubject.moodboard,
      title: strings.moodboardTitle,
      typeLabel: strings.moodboardTitle,
      area: card.area,
      areaLabel: card.area.displayName(strings),
      artwork: SingleChildScrollView(
        child: MoodboardGrid(items: card.items.take(12).toList()),
      ),
      tiles: [
        for (final item in card.items.take(12))
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.kind == MoodboardKind.quote && item.quoteDesign != null
                ? ShareQuoteArtwork(
                    data: ShareContent(
                      subject: ShareSubject.quote,
                      title: item.content,
                      description: item.author,
                      typeLabel: strings.moodboardQuote,
                    ),
                    design: item.quoteDesign!,
                    fill: true,
                  )
                : MoodboardMedia(
                    key: ValueKey('${item.id}:${item.content}'),
                    item: item,
                  ),
          ),
      ],
      photos: [
        for (final item in card.items)
          if (item.kind == MoodboardKind.photo) item.content,
      ],
    );
  }
  if (card is ShareableReflectionCard) {
    final record = card.reflection;
    return ShareContent(
      subject: ShareSubject.vision,
      title: record.title,
      description: card.showBody ? card.bodyOverride ?? record.body : '',
      typeLabel: strings.areaReflectionsTitle,
      area: record.area,
      areaLabel: record.area.displayName(strings),
      dateLabel: formatDisplayDate(record.createdAt, strings),
      isReflection: true,
    );
  }
  throw ArgumentError.value(
    card.runtimeType,
    'card',
    'Unsupported share content',
  );
}
