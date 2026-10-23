import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Relative widths cycled over a row's tiles (by global position), so the
/// rows read as an uneven mosaic rather than a grid of equal cells.
const _kMosaicWeights = [3, 2, 2, 3, 2, 3, 3, 2, 2];

/// Every tile of a moodboard at once, packed to fill the available box: rows
/// of unequal widths, no scrolling, so a full board shows all of its items
/// (smaller) instead of the first few.
class MoodboardMosaic extends StatelessWidget {
  const MoodboardMosaic({super.key, required this.tiles, this.gap = 6});
  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final n = tiles.length;
        final width = box.maxWidth.isFinite ? box.maxWidth : 300.0;
        final height = box.maxHeight.isFinite ? box.maxHeight : width;
        final rows = math.sqrt(n * height / width).round().clamp(1, n);
        var index = 0;
        return Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) SizedBox(height: gap),
              Expanded(
                // Alternate row heights a little for the same reason.
                flex: r.isEven ? 5 : 4,
                child: Row(
                  children: [
                    // Spread the remainder over the first rows.
                    for (
                      var c = 0;
                      c < n ~/ rows + (r < n % rows ? 1 : 0);
                      c++, index++
                    ) ...[
                      if (c > 0) SizedBox(width: gap),
                      Expanded(
                        flex:
                            _kMosaicWeights[(index + r) %
                                _kMosaicWeights.length],
                        child: tiles[index],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tiles dealt across [columns] columns (tile `i` goes to column
/// `i % columns`), each column stacking its own with a different rhythm of
/// heights, so no two columns repeat and nothing is tall and thin.
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

  static const _heights = [
    [3, 2, 3, 2],
    [2, 3, 2, 3],
    [3, 3, 2, 2],
  ];

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final count = math.min(columns, tiles.length);
    return Row(
      children: [
        for (var c = 0; c < count; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                for (var i = c, k = 0; i < tiles.length; i += count, k++) ...[
                  if (k > 0) SizedBox(height: gap),
                  Expanded(
                    flex:
                        _heights[c % _heights.length][k %
                            _heights[c % _heights.length].length],
                    child: tiles[i],
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
