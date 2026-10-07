import 'package:flutter/material.dart';

/// A centered header title shown whole: one line when it fits, otherwise as
/// few lines as it needs (up to [maxLines]), broken at the words that make
/// them as close in length as possible. A title too long even for that is cut
/// with an ellipsis on the last line.
class BalancedTitle extends StatelessWidget {
  const BalancedTitle({super.key, required this.title, required this.style});

  final String title;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      double measure(String text) => (TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout()).width;

      final maxWidth = constraints.maxWidth;
      final text = _balanced(title, maxWidth, measure);
      return Semantics(
        label: title,
        child: ExcludeSemantics(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      );
    },
  );

  static const maxLines = 2;

  /// The fewest lines that fit, broken at the words that leave them closest
  /// in length. Falls back to the unbroken title (ellipsized by [Text]) when
  /// even [maxLines] lines can't hold it.
  static String _balanced(
    String title,
    double maxWidth,
    double Function(String) measure,
  ) {
    if (measure(title) <= maxWidth) return title;
    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final list = words.toList();
    for (var lines = 2; lines <= maxLines; lines++) {
      final best = _bestSplit(list, lines, maxWidth, measure);
      if (best != null) return best;
    }
    return title;
  }

  static String? _bestSplit(
    List<String> words,
    int lines,
    double maxWidth,
    double Function(String) measure,
  ) {
    String? best;
    var bestSpread = double.infinity;

    void walk(int start, List<String> chosen) {
      if (chosen.length == lines - 1) {
        final last = words.sublist(start).join(' ');
        if (last.isEmpty) return;
        final all = [...chosen, last];
        final widths = [for (final l in all) measure(l)];
        if (widths.any((w) => w > maxWidth)) return;
        final spread =
            widths.reduce((a, b) => a > b ? a : b) -
            widths.reduce((a, b) => a < b ? a : b);
        if (spread < bestSpread) {
          bestSpread = spread;
          best = all.join('\n');
        }
        return;
      }
      for (var end = start + 1; end < words.length; end++) {
        final line = words.sublist(start, end).join(' ');
        if (measure(line) > maxWidth) break;
        walk(end, [...chosen, line]);
      }
    }

    walk(0, const []);
    return best;
  }
}
