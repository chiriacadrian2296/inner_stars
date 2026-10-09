import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The icon of a Sky level (area, constellation, star) followed by how many
/// cards that level would show and the level's word — one line, used both
/// under Sky's search bar (what the page shows now) and above the buttons of
/// its filter sheets (what the page would show once the pending choice is
/// applied).
class ResultsCountRow extends StatelessWidget {
  const ResultsCountRow({
    super.key,
    required this.icon,
    required this.count,
    required this.word,
  });

  final IconData icon;
  final int count;
  final String word;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: count == 0 ? colors.muted : colors.gold),
        const SizedBox(width: 6),
        Text(
          '$count ${word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

/// How a filter sheet previews its pending selection: the level's [icon] and,
/// for any selection [T] the sheet can hold, how many cards it would leave,
/// plus the level's [wordFor] that count.
class FilterPreview<T> {
  const FilterPreview({
    required this.icon,
    required this.countFor,
    required this.wordFor,
  });

  final IconData icon;
  final int Function(T selection) countFor;
  final String Function(int count) wordFor;

  /// The preview row for [selection].
  Widget rowFor(T selection) {
    final count = countFor(selection);
    return ResultsCountRow(icon: icon, count: count, word: wordFor(count));
  }
}
