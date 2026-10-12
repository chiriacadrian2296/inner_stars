import 'package:flutter/material.dart';

/// An action icon with a small "NEW" label under it (just the letters, no
/// background), the pair centred as one
/// group: marks the buttons that create something (+ Constellation, + Star).
class IconWithNewBadge extends StatelessWidget {
  const IconWithNewBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    this.lift = 0,
  });

  final IconData icon;

  /// Size of [icon]; the label is 40% of it.
  final double size;
  final Color color;

  /// Moves the whole pair up by this much, when the glyphs look low in their
  /// button.
  final double lift;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, -lift),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        Text(
          'NEW',
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}
