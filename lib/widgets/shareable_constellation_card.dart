import 'package:flutter/material.dart';

import '../data/constellation_shape.dart';
import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../theme/app_colors.dart';
import '../utils/icon_for_slug.dart';
import 'area_tag.dart';
import 'constellation_editor_painter.dart';
import 'share_arrangement.dart';

/// A static "just born" portrait of a whole constellation — exists only to
/// be captured as an image via a [RepaintBoundary] wrapped around it (see
/// `SkyScreen`'s own creation share flow), the same trick
/// [ShareableLitStarCard] already uses for a single star. Unlike every
/// other member of that family, there's no single star's own title to
/// lead with — [shape] itself, drawn the same way the shape picker's own
/// thumbnails are (see `NewProjectScreen`'s `_ShapeThumbnail`), is the
/// centerpiece instead.
class ShareableConstellationCard extends StatelessWidget {
  const ShareableConstellationCard({
    super.key,
    required this.project,
    required this.shape,
  });

  final Project project;
  final ConstellationShape shape;

  static const _shapeSide = 220.0;
  static const _shapeInset = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final drawable = _shapeSide - _shapeInset * 2;

    final shapeGraphic = SizedBox(
      width: _shapeSide,
      height: _shapeSide,
      child: CustomPaint(
        size: Size.square(_shapeSide),
        painter: ConstellationEditorPainter(
          points: [
            for (final p in shape.points)
              Offset(
                _shapeInset + p.dx * drawable,
                _shapeInset + p.dy * drawable,
              ),
          ],
          edges: shape.edges,
          highlightedIndex: null,
          pointColor: colors.gold,
          highlightColor: colors.gold,
          lineColor: colors.text.withValues(alpha: 0.5),
          pointRadius: 4,
        ),
      ),
    );
    return ShareableStoryLayout(
      title: project.name,
      description: project.description,
      hero: shapeGraphic,
      context: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(iconForSlug(project.iconSlug), size: 24, color: colors.gold),
          AreaTag(area: project.area, iconSize: 20, fontSize: 16),
        ],
      ),
      meta: strings.constellationTooltipLitCount(0, shape.points.length),
    );
  }
}
