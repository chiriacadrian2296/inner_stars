import 'package:flutter/material.dart';

import '../../data/constellation_shape.dart';
import '../../l10n/strings_scope.dart';
import '../../models/habit.dart';
import '../../models/life_area.dart';
import '../../models/project.dart';
import '../../models/star.dart';
import '../../models/star_kind.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../utils/area_hero_art.dart';
import '../../utils/date_format.dart';
import '../intensity_bolts.dart';
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
  GalleryStarData.fromStar(Star star, this.project)
    : star = star,
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
            stops: [from, 1],
            colors: [night.withValues(alpha: 0), night.withValues(alpha: 0.94)],
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
          final Widget dataRow = switch (kind) {
            StarKind.lit => IntensityBolts(
              intensity: data.star!.intensity ?? 0,
              size: 14 * u,
              spacing: 2 * u,
            ),
            StarKind.unlit => _DataLine(
              icon: Icons.calendar_month_rounded,
              text: data.star!.targetDate == null
                  ? '—'
                  : formatDisplayDate(data.star!.targetDate!, strings),
              color: color,
              unit: u,
            ),
            StarKind.pulsar => _DataLine(
              icon: Icons.local_fire_department_rounded,
              text: '${data.streak}',
              color: color,
              unit: u,
            ),
            StarKind.dead => _DataLine(
              icon: Icons.cancel_outlined,
              text: data.deadDate == null
                  ? '—'
                  : formatDisplayDate(data.deadDate!, strings),
              color: color,
              unit: u,
            ),
            StarKind.nascent => const SizedBox.shrink(),
          };
          return Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto) ...[
                PhotoImage(
                  photoPath: photoPath,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                ),
                const _BottomScrim(from: 0.3),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14 * u,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8 * u),
                    dataRow,
                    if (data.project != null) ...[
                      SizedBox(height: 6 * u),
                      Text(
                        data.project!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 10 * u),
                      ),
                    ],
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

class _DataLine extends StatelessWidget {
  const _DataLine({
    required this.icon,
    required this.text,
    required this.color,
    required this.unit,
  });

  final IconData icon;
  final String text;
  final Color color;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14 * unit, color: color),
        SizedBox(width: 4 * unit),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 12 * unit,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Constellation ----------------------------------------------------------

class GalleryProjectData {
  const GalleryProjectData({
    required this.project,
    required this.shape,
    required this.slotKinds,
    required this.pulsarsLit,
    required this.totalStars,
    required this.litStars,
  });

  final Project project;
  final ConstellationShape? shape;

  /// Kind of the star sitting on each of the shape's points (0-based); a
  /// point missing here is a nascent slot.
  final Map<int, StarKind> slotKinds;

  /// One entry per live habit (pulsar): whether it is lit right now.
  final List<bool> pulsarsLit;
  final int totalStars;
  final int litStars;
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
    final shape = data.shape;
    return _TileFrame(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final u = _unit(constraints);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (shape != null && shape.points.isNotEmpty)
                Positioned(
                  left: 14 * u,
                  right: 14 * u,
                  top: 14 * u,
                  bottom: 84 * u,
                  child: CustomPaint(
                    painter: _MiniConstellationPainter(
                      shape: shape,
                      slotKinds: data.slotKinds,
                      pulsarsLit: data.pulsarsLit,
                      colors: colors,
                      lineColor: colors.text.withValues(alpha: 0.4),
                      pointRadius: 3.2 * u,
                    ),
                  ),
                )
              else
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Icon(
                    Icons.insights,
                    size: 40 * u,
                    color: colors.muted,
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(12 * u),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.project.area.displayName(strings).toUpperCase(),
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
                        fontSize: 14 * u,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8 * u),
                    _DataLine(
                      icon: Icons.star_rounded,
                      text: '${data.litStars} / ${data.totalStars}',
                      color: colors.gold,
                      unit: u,
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

/// A shape's points are normalized to a 0..1 square; this draws that square
/// as large as fits (centered) so wide and tall boxes keep its proportions.
class _MiniConstellationPainter extends CustomPainter {
  const _MiniConstellationPainter({
    required this.shape,
    required this.slotKinds,
    required this.pulsarsLit,
    required this.colors,
    required this.lineColor,
    required this.pointRadius,
  });

  final ConstellationShape shape;
  final Map<int, StarKind> slotKinds;
  final List<bool> pulsarsLit;
  final AppColors colors;
  final Color lineColor;
  final double pointRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final points = [
      for (final p in shape.points) origin + Offset(p.dx * side, p.dy * side),
    ];
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (a, b) in shape.edges) {
      if (a >= points.length || b >= points.length) continue;
      canvas.drawLine(points[a], points[b], linePaint);
    }
    for (var i = 0; i < points.length; i++) {
      final kind = slotKinds[i] ?? StarKind.nascent;
      canvas.drawCircle(
        points[i],
        pointRadius,
        Paint()..color = starKindColor(kind, colors),
      );
    }
    // Habits aren't part of the shape: small loose dots around its edges.
    for (var i = 0; i < pulsarsLit.length && i < _pulsarSpots.length; i++) {
      final spot = _pulsarSpots[i];
      canvas.drawCircle(
        origin + Offset(spot.dx * side, spot.dy * side),
        pointRadius * 0.7,
        Paint()
          ..color = starKindColor(StarKind.pulsar, colors, lit: pulsarsLit[i]),
      );
    }
  }

  /// Fixed spots (normalized to the square) for the first few habits.
  static const _pulsarSpots = [
    Offset(0.04, 0.08),
    Offset(0.96, 0.14),
    Offset(0.06, 0.92),
    Offset(0.95, 0.88),
    Offset(0.5, 0.01),
    Offset(0.5, 0.99),
    Offset(0.01, 0.5),
    Offset(0.99, 0.5),
  ];

  @override
  bool shouldRepaint(covariant _MiniConstellationPainter old) =>
      shape != old.shape ||
      slotKinds != old.slotKinds ||
      pulsarsLit != old.pulsarsLit ||
      colors != old.colors ||
      lineColor != old.lineColor ||
      pointRadius != old.pointRadius;
}

// -- Area -------------------------------------------------------------------

class GalleryAreaData {
  const GalleryAreaData({
    required this.area,
    required this.constellationCount,
    required this.starCount,
  });

  final LifeArea area;
  final int constellationCount;
  final int starCount;
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
                        : Image.asset(
                            asset,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: colors.night),
                          ),
                  ),
                ),
                SizedBox(height: 10 * u),
                Text(
                  data.area.displayName(strings),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontBranding,
                    fontSize: 18 * u,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 8 * u),
                Row(
                  children: [
                    _DataLine(
                      icon: Icons.insights_outlined,
                      text: '${data.constellationCount}',
                      color: colors.gold,
                      unit: u,
                    ),
                    SizedBox(width: 12 * u),
                    _DataLine(
                      icon: Icons.star_outline_rounded,
                      text: '${data.starCount}',
                      color: colors.gold,
                      unit: u,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
