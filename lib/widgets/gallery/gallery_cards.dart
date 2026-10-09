import 'package:flutter/material.dart';

import '../../l10n/strings_scope.dart';
import '../../models/habit.dart';
import '../../models/life_area.dart';
import '../../models/project.dart';
import '../../models/star.dart';
import '../../models/star_kind.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../utils/area_hero_art.dart';
import '../../utils/area_hero_art_tone.dart';
import '../../utils/star_card_info.dart';
import '../badge_rows.dart';
import '../constellation_painter.dart' show ConstellationStar;
import '../photo_image.dart';
import '../star_glyph.dart';

/// Cosmo's Gallery tiles: miniature, portrait (2:3) versions of the single
/// pages — a star's reader page, a constellation's page, an area's cover —
/// laid out in a grid so many can be seen at once. Everything is sized from
/// the tile's own width ([_unit]), so the same widget also serves as the big
/// page in `GalleryPager`.
///
/// Experimental: this folder is self-contained so it can be kept or deleted
/// as a whole.
const double kGalleryTileAspectRatio = 2 / 3;

/// One star-like entry as the Gallery shows it: a [Star], or a [Habit]
/// (pulsar, or dead pulsar).
class GalleryStarData {
  GalleryStarData.fromStar(
    Star star,
    this.project, {
    this.badges = CardBadges.none,
  }) : star = star,
       habit = null,
       kind = star.kind,
       streak = 0,
       pulsarLit = true,
       sortKey = star.achievedDate ?? star.createdAt;

  GalleryStarData.fromHabit(
    Habit habit,
    this.project, {
    required this.streak,
    required this.pulsarLit,
    this.badges = CardBadges.none,
  }) : star = null,
       habit = habit,
       kind = habit.dead ? StarKind.dead : StarKind.pulsar,
       sortKey = habit.createdAt;

  final Star? star;
  final Habit? habit;
  final Project? project;
  final StarKind kind;
  final int streak;
  final bool pulsarLit;
  final DateTime sortKey;

  /// The entry's badges (see `starCardBadges` / `habitCardBadges`).
  final CardBadges badges;

  String get title => star?.title ?? habit!.title;
  String get key => star != null ? 's${star!.id}' : 'p${habit!.id}';
  DateTime? get deadDate => star?.deadDate ?? habit?.deadDate;
}

/// Tile width → scale factor; 160 logical pixels wide reads as 1.0.
double _unit(BoxConstraints c) => c.maxWidth / 160;

class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: colors.nightPanel,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.nightBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark wash over the lower part of a tile so text stays readable on top of
/// a photo or artwork.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim({this.from = 0.4});

  final double from;

  @override
  Widget build(BuildContext context) {
    final night = context.colors.night;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Darker sooner: a middle stop at 60% keeps the text readable on
            // a busy photo instead of fading in only at the very bottom.
            stops: [from, from + (1 - from) * 0.5, 1],
            colors: [
              night.withValues(alpha: 0),
              night.withValues(alpha: 0.62),
              night.withValues(alpha: 0.97),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Star -------------------------------------------------------------------

/// Miniature of the star reader's page: kind icon, kind label, title, the
/// kind's own data (intensity bolts / target date / streak / dead date) and
/// the constellation it belongs to. A lit star's photo fills the tile.
class GalleryStarTile extends StatelessWidget {
  const GalleryStarTile({super.key, required this.data, this.onTap});

  final GalleryStarData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final kind = data.kind;
    final color = starKindColor(kind, colors, lit: data.pulsarLit);
    final photoPath = data.star?.photoPath;
    final hasPhoto = kind == StarKind.lit && photoPath != null;

    return _TileFrame(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final u = _unit(constraints);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto) ...[
                PhotoImage(
                  photoPath: photoPath,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                ),
                const _BottomScrim(from: 0.2),
              ],
              Padding(
                padding: EdgeInsets.all(12 * u),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: hasPhoto
                            ? Alignment.topLeft
                            : Alignment.center,
                        child: Icon(
                          kind.icon,
                          size: (hasPhoto ? 22 : 44) * u,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(height: 10 * u),
                    if (data.badges.intensity != null) ...[
                      IntensityBadge(
                        badge: data.badges.intensity!,
                        scale: u * _kTileBadgeScale,
                      ),
                      SizedBox(height: 4 * u),
                    ],
                    Text(
                      kind.label(strings).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 9.5 * u,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4 * u),
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: kFontStarTitle,
                        fontSize: 18 * u,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (data.project != null) ...[
                      SizedBox(height: 4 * u),
                      Text(
                        '${data.project!.area.displayName(strings)} → '
                        '${data.project!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 10 * u),
                      ),
                    ],
                    SizedBox(height: 6 * u),
                    BadgeRows(
                      rows: data.badges.rows,
                      maxScale: u * _kTileBadgeScale,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A tile's badges are drawn at this fraction of the tooltip size (the tile
/// text is smaller than the card's), times the tile's own scale.
const double _kTileBadgeScale = 12 / 14;

// -- Constellation ----------------------------------------------------------

class GalleryProjectData {
  const GalleryProjectData({
    required this.project,
    required this.renderStars,
    required this.edges,
    required this.totalStars,
    required this.litStars,
    this.badges = CardBadges.none,
  });

  final Project project;

  /// Exactly what Cosmo and the constellation page draw for this project
  /// (`buildConstellationRenderStars`): every star on the shape's grown
  /// layout, nascent slots, overflow stars and the scattered pulsars.
  final List<ConstellationStar> renderStars;

  /// Index pairs into the shape's grown layout; a star at slot N sits at
  /// index N - 1.
  final List<(int, int)> edges;
  final int totalStars;
  final int litStars;

  /// The constellation's badges (see `projectCardBadges`).
  final CardBadges badges;
}

/// Miniature of a constellation's page: its shape on the flat navy panel
/// (lit stars gold, the rest dim), the name, and how many are lit.
class GalleryProjectTile extends StatelessWidget {
  const GalleryProjectTile({super.key, required this.data, this.onTap});

  final GalleryProjectData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return _TileFrame(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final u = _unit(constraints);
          // The shape sits in the upper part like the area's art: it takes
          // the room the text leaves, centred in it.
          return Padding(
            padding: EdgeInsets.all(12 * u),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14 * u),
                    child: SizedBox.expand(
                      child: data.renderStars.isNotEmpty
                          ? CustomPaint(
                              painter: _MiniConstellationPainter(
                                stars: data.renderStars,
                                edges: data.edges,
                                colorOf: (star) => starKindColor(
                                  star.kind,
                                  colors,
                                  lit: star.lit,
                                ),
                                lineColor: colors.text.withValues(alpha: 0.4),
                                pointRadius: 3.2 * u,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.insights,
                                size: 40 * u,
                                color: colors.muted,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 10 * u),
                if (data.badges.intensity != null) ...[
                  IntensityBadge(
                    badge: data.badges.intensity!,
                    scale: u * _kTileBadgeScale,
                  ),
                  SizedBox(height: 4 * u),
                ],
                Text(
                  strings.projectLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.gold,
                    fontSize: 9.5 * u,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4 * u),
                Text(
                  data.project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 18 * u,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4 * u),
                Text(
                  data.project.area.displayName(strings),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 10 * u),
                ),
                SizedBox(height: 6 * u),
                BadgeRows(
                  rows: data.badges.rows,
                  maxScale: u * _kTileBadgeScale,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Draws a constellation the way Cosmo does — every star at its real
/// position, colored by kind — scaled to fit the box. The fit uses the bounds
/// of *all* the stars (pulsars and overflow stars scatter beyond the shape),
/// uniformly, so proportions are never distorted.
class _MiniConstellationPainter extends CustomPainter {
  const _MiniConstellationPainter({
    required this.stars,
    required this.edges,
    required this.colorOf,
    required this.lineColor,
    required this.pointRadius,
  });

  final List<ConstellationStar> stars;
  final List<(int, int)> edges;
  final Color Function(ConstellationStar star) colorOf;
  final Color lineColor;
  final double pointRadius;

  /// Dot size relative to a regular star: Cosmo draws pulsars as smaller
  /// points, and an empty slot is only a hint of a star.
  static double _radiusFactor(ConstellationStar star) => switch (star.kind) {
    StarKind.pulsar => 0.65,
    StarKind.nascent => 0.7,
    _ => 1.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final star in stars) {
      final p = star.position;
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final inset = pointRadius + 2;
    final usableWidth = (size.width - 2 * inset).clamp(1.0, double.infinity);
    final usableHeight = (size.height - 2 * inset).clamp(1.0, double.infinity);
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    // A single point or a perfectly straight row has a zero span on one axis;
    // only the other one decides the scale then.
    final scale = switch ((spanX > 0, spanY > 0)) {
      (true, true) => (usableWidth / spanX).clamp(0.0, usableHeight / spanY),
      (true, false) => usableWidth / spanX,
      (false, true) => usableHeight / spanY,
      _ => 1.0,
    };
    final center = Offset(size.width / 2, size.height / 2);
    final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    Offset place(Offset p) => center + (p - mid) * scale;

    // Edges refer to the grown layout's indices; a star on the shape sits at
    // its slot's index.
    final bySlot = <int, Offset>{
      for (final star in stars)
        if (star.slotSequence != null)
          star.slotSequence! - 1: place(star.position),
    };
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (a, b) in edges) {
      final from = bySlot[a];
      final to = bySlot[b];
      if (from == null || to == null) continue;
      canvas.drawLine(from, to, linePaint);
    }
    for (final star in stars) {
      canvas.drawCircle(
        place(star.position),
        pointRadius * _radiusFactor(star),
        Paint()..color = colorOf(star),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniConstellationPainter old) =>
      stars != old.stars ||
      edges != old.edges ||
      lineColor != old.lineColor ||
      pointRadius != old.pointRadius;
}

// -- Area -------------------------------------------------------------------

class GalleryAreaData {
  const GalleryAreaData({
    required this.area,
    required this.constellationCount,
    required this.starCount,
    this.badges = CardBadges.none,
  });

  final LifeArea area;
  final int constellationCount;
  final int starCount;

  /// The area's badges (see `areaCardBadges`).
  final CardBadges badges;
}

/// Miniature of an area's cover page: its hero art, the name, and counts.
class GalleryAreaTile extends StatelessWidget {
  const GalleryAreaTile({super.key, required this.data, this.onTap});

  final GalleryAreaData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final asset = kAreaHeroArt[data.area]?.skyAsset;
    return _TileFrame(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final u = _unit(constraints);
          // The artwork sits inset in the upper part of the card instead of
          // filling it, so it reads smaller; name and counts go below.
          return Padding(
            padding: EdgeInsets.all(12 * u),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * u),
                    child: asset == null
                        ? ColoredBox(
                            color: colors.night,
                            child: Center(
                              child: Icon(
                                Icons.flare,
                                size: 36 * u,
                                color: colors.gold,
                              ),
                            ),
                          )
                        : tonedAreaHeroArt(
                            child: Image.asset(
                              asset,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  ColoredBox(color: colors.night),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 10 * u),
                if (data.badges.intensity != null) ...[
                  IntensityBadge(
                    badge: data.badges.intensity!,
                    scale: u * _kTileBadgeScale,
                  ),
                  SizedBox(height: 4 * u),
                ],
                if (data.badges.title != null)
                  EyebrowWithBadge(
                    label: strings.areaLabel,
                    color: colors.gold,
                    badge: data.badges.title!,
                    fontSize: 9.5 * u,
                    letterSpacing: 1.2,
                    scale: u * _kTileBadgeScale,
                  )
                else
                  Text(
                    strings.areaLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.gold,
                      fontSize: 9.5 * u,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                SizedBox(height: 4 * u),
                Text(
                  data.area.displayName(strings),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 18 * u,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4 * u),
                Text(
                  strings.galaxyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 10 * u),
                ),
                SizedBox(height: 6 * u),
                BadgeRows(
                  rows: data.badges.rows,
                  maxScale: u * _kTileBadgeScale,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
