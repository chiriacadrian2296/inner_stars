import 'package:flutter/material.dart';

import '../data/constellation_shape.dart';
import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/icon_for_slug.dart';
import 'area_tag.dart';
import 'constellation_editor_painter.dart';

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

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: BoxDecoration(gradient: colors.nightlightGradient)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
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
                  ),
                  const SizedBox(height: 24),
                  Icon(iconForSlug(project.iconSlug), size: 32, color: colors.gold),
                  const SizedBox(height: 16),
                  AreaTag(area: project.area, iconSize: 24, fontSize: 21),
                  const SizedBox(height: 24),
                  Text(
                    project.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontStarTitle,
                      fontStyle: FontStyle.italic,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: colors.text,
                    ),
                  ),
                  if (project.description != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      project.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: colors.nightlightMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    strings.constellationTooltipLitCount(0, shape.points.length),
                    style: TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 15,
                      color: colors.nightlightMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
