import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_field.dart' show FieldResetButton;

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
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$count',
                style: TextStyle(color: colors.text),
              ),
              TextSpan(
                text:
                    ' ${word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)}',
              ),
            ],
          ),
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

/// Under Sky's count badge, once at least one card is turned over: how many
/// (left), the flip glyph (middle) and the button turning them all face up
/// again (right), as one centred group. Slides in and out as the count goes
/// from and to zero.
class FlippedCardsRow extends StatefulWidget {
  const FlippedCardsRow({
    super.key,
    required this.count,
    required this.onReset,
  });

  final int count;
  final VoidCallback onReset;

  @override
  State<FlippedCardsRow> createState() => _FlippedCardsRowState();
}

class _FlippedCardsRowState extends State<FlippedCardsRow> {
  // Kept while the row animates out, when [FlippedCardsRow.count] is 0.
  int _shownCount = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (widget.count > 0) _shownCount = widget.count;
    final visible = widget.count > 0;
    final disabled = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: disabled ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: disabled ? Duration.zero : const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: !visible
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: const ValueKey('flipped-row'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The count and the reset button take the same width, so
                    // they sit at the same distance from the middle glyph.
                    SizedBox(
                      width: FieldResetButton.width,
                      child: Text(
                        '$_shownCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Icon(Icons.flip, size: 26, color: colors.muted),
                    FieldResetButton(onReset: widget.onReset),
                  ],
                ),
              ),
      ),
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
