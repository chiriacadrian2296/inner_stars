import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';

/// "23 of 123" with a small icon centred above it saying what is being
/// counted (constellations, activities), like Sky's count badge. Sits above
/// the buttons of a reader's dock.
class PositionCounter extends StatelessWidget {
  const PositionCounter({
    super.key,
    required this.index,
    required this.total,
    required this.icon,
  });

  /// 1-based position.
  final int index;
  final int total;
  final IconData icon;

  /// The space between this block and the row of buttons below it.
  static const double gapBelow = 16;

  /// Its height, for the docks that reserve room for it.
  static const double height = 14 + 2 + 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            context.strings.indexOfCount(index, total),
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
