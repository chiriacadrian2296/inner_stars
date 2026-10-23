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

/// Tiles in a regular grid that fills the box: as many equal columns as the
/// count calls for, the last row's tiles stretching to close the row.
class MoodboardContactSheet extends StatelessWidget {
  const MoodboardContactSheet({super.key, required this.tiles, this.gap = 4});
  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final n = tiles.length;
    final columns = n <= 2 ? n : (n <= 4 ? 2 : (n <= 9 ? 3 : 4));
    final rows = (n / columns).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (
                  var i = r * columns;
                  i < math.min(n, (r + 1) * columns);
                  i++
                ) ...[
                  if (i > r * columns) SizedBox(width: gap),
                  Expanded(child: tiles[i]),
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
/// `i % columns`), every tile upright (4:5) and the middle column dropped
/// half a tile, so the columns don't repeat each other. The whole stack is
/// scaled down to fit when it is taller than the box.
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
    final rows = (tiles.length / count).ceil();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth.isFinite ? box.maxWidth : 300.0;
        final tileWidth = (width - (count - 1) * gap) / count;
        final tileHeight = tileWidth * 1.25;
        final height =
            rows * tileHeight +
            (rows - 1) * gap +
            (count > 1 ? tileHeight / 2 : 0);
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width,
            height: height,
            child: Row(
              children: [
                for (var c = 0; c < count; c++) ...[
                  if (c > 0) SizedBox(width: gap),
                  SizedBox(
                    width: tileWidth,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: c.isOdd ? tileHeight / 2 : 0,
                      ),
                      child: Column(
                        children: [
                          for (
                            var i = c, k = 0;
                            i < tiles.length;
                            i += count, k++
                          ) ...[
                            if (k > 0) SizedBox(height: gap),
                            SizedBox(
                              width: tileWidth,
                              height: tileHeight,
                              child: tiles[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
