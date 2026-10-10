import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'search_result_card.dart' show SearchStarVisual;
import 'staggered_entrance.dart';

/// The gap between the tile row at the top of a creation/edit form and the
/// first thing under it — the same in every form.
const double kFormTilesGap = 24;

/// One tile of [FormKindTiles]: just a picture in a square, its name below.
class FormKindTile {
  const FormKindTile({
    required this.visual,
    required this.label,
    required this.selected,
    this.onTap,
  });

  /// The constellation tile.
  factory FormKindTile.constellation(
    BuildContext context, {
    required bool selected,
    VoidCallback? onTap,
  }) => FormKindTile(
    visual: SearchStarVisual(
      kind: StarKind.lit,
      icon: Icons.insights,
      color: context.colors.gold,
    ),
    label: context.strings.projectLabel,
    selected: selected,
    onTap: onTap,
  );

  /// The tile of one kind of star.
  factory FormKindTile.star(
    BuildContext context,
    StarKind kind, {
    required bool selected,
    VoidCallback? onTap,
  }) => FormKindTile(
    visual: SearchStarVisual(kind: kind, pulsarBothStates: true),
    label: kind.label(context.strings),
    selected: selected,
    onTap: onTap,
  );

  final Widget visual;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
}

/// The row of square tiles at the top of every creation and edit form, always
/// there — with one tile, two or four. A form only offers the tiles that make
/// sense for what it is doing, but the row, the tile size and the gap under
/// it are the same everywhere.
///
/// [leading] (the constellation) and [trailing] (the kinds of star) are set
/// apart by a thin vertical line when both are present. Tiles are sized as
/// if four were shown, so they never change size between forms.
class FormKindTiles extends StatelessWidget {
  const FormKindTiles({
    super.key,
    this.leading = const [],
    this.trailing = const [],
    this.onSwipe,
  });

  final List<FormKindTile> leading;
  final List<FormKindTile> trailing;

  /// Called with -1 or 1 on a horizontal swipe over the row.
  final ValueChanged<int>? onSwipe;

  static const double _gap = 8;

  /// The line is as thick as a tile's border, with 12 of air either side.
  static const double _dividerWidth = 12 + kBorderWidth + 12;
  static const double _maxSide = 104;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The four-tile layout: constellation, divider, three stars.
        final side = ((constraints.maxWidth - 2 * _gap - _dividerWidth) / 4)
            .floorToDouble()
            .clamp(0.0, _maxSide);

        var index = 0;
        Widget tile(FormKindTile t) {
          final i = index++;
          return StaggeredEntrance(
            index: i + 1,
            axis: Axis.horizontal,
            child: SizedBox(
              width: side,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: t.onTap,
                    borderRadius: BorderRadius.circular(kRadiusField),
                    child: Container(
                      width: side,
                      height: side,
                      // The picture is clipped to the tile's rounded corners.
                      clipBehavior: Clip.antiAlias,
                      decoration: selectableDecoration(
                        colors,
                        selected: t.selected,
                      ),
                      // Drawn smaller than the tile so it has room to breathe.
                      child: Opacity(
                        opacity: t.selected ? 1 : 0.55,
                        child: Transform.scale(
                          scale: 0.72,
                          child: SizedBox.expand(child: t.visual),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // The name selects the tile too, not just the square above it.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: t.onTap,
                    child: SizedBox(
                      width: side,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t.label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: t.selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: t.selected ? colors.text : colors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget group(List<FormKindTile> tiles) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              tile(tiles[i]),
            ],
          ],
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: onSwipe == null
              ? null
              : (details) {
                  const minimumVelocity = 180.0;
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < minimumVelocity) return;
                  onSwipe!(velocity.isNegative ? 1 : -1);
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading.isNotEmpty) group(leading),
              if (leading.isNotEmpty && trailing.isNotEmpty)
                SizedBox(
                  width: _dividerWidth,
                  height: side,
                  child: Center(
                    child: Container(
                      width: kBorderWidth,
                      height: side * 0.7,
                      color: colors.nightBorder,
                    ),
                  ),
                ),
              if (trailing.isNotEmpty) group(trailing),
            ],
          ),
        );
      },
    );
  }
}
