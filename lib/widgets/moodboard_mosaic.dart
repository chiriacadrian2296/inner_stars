import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Every tile of a moodboard at once, in the same pattern as the board itself
/// (a large tile beside two stacked ones, the sides alternating row by row),
/// but squeezed to fill the available box: no scrolling, so a full board shows
/// all of its items, smaller. Tiles are expected to crop their content to the
/// cell they are given.
class MoodboardMosaic extends StatelessWidget {
  const MoodboardMosaic({super.key, required this.tiles, this.gap = 6});
  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 3) ...[
          if (i > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              textDirection: (i ~/ 3).isEven
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              children: [
                Expanded(flex: 3, child: tiles[i]),
                if (i + 1 < tiles.length) ...[
                  SizedBox(width: gap),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: tiles[i + 1]),
                        if (i + 2 < tiles.length) ...[
                          SizedBox(height: gap),
                          Expanded(child: tiles[i + 2]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tiles dealt across [columns] columns (tile `i` goes to column
/// `i % columns`), every tile of a column the same height, with the middle
/// column dropped half a tile so the three don't repeat each other.
class MoodboardColumns extends StatelessWidget {
  const MoodboardColumns({
    super.key,
    required this.tiles,
    this.columns = 3,
    this.gap = 6,
  });
  final List<Widget> tiles;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final count = math.min(columns, tiles.length);
    // Rows in the tallest column, so every tile has the same height.
    final rows = (tiles.length / count).ceil();
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight.isFinite ? box.maxHeight : 300.0;
        // The middle column is shifted by half a tile; the grid is sized so
        // that shift still fits.
        final tile = (height - (rows - 1) * gap) / (rows + .5);
        return Row(
          children: [
            for (var c = 0; c < count; c++) ...[
              if (c > 0) SizedBox(width: gap),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: c.isOdd ? tile / 2 : 0),
                  child: Column(
                    children: [
                      for (
                        var i = c, k = 0;
                        i < tiles.length;
                        i += count, k++
                      ) ...[
                        if (k > 0) SizedBox(height: gap),
                        SizedBox(
                          height: tile,
                          width: double.infinity,
                          child: tiles[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
