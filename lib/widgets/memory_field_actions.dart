import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_field.dart' show fieldLimitStyle;

/// A placeholder icon with a small "+" at its lower right, for the kinds of
/// memory whose Material icon has no ready-made "add" variant.
class PlusBadgeIcon extends StatelessWidget {
  const PlusBadgeIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final double size;
  final Color color;

  /// The surface behind the icon, so the badge can cut a clean notch out of
  /// it.
  final Color background;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color, size: size),
          Positioned(
            right: -badge * 0.15,
            bottom: -badge * 0.15,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: color, size: badge),
            ),
          ),
        ],
      ),
    );
  }
}

/// A discreet caption centered under a photo zone.
class MemoryCaption extends StatelessWidget {
  const MemoryCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: fieldLimitStyle(context),
        ),
      ),
    );
  }
}

/// The small round "remove this item" badge pinned to the top-right corner of
/// a photo, video, voice-note or link tile. One widget so every kind carries
/// the same one, 18 px across like the Reset icon beside the field name.
class RemoveBadge extends StatelessWidget {
  const RemoveBadge({super.key, required this.background});

  /// The surface the tile sits on, so the badge reads against it.
  final Color background;

  static const double diameter = 18;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: colors.gold),
      ),
      child: Icon(Icons.close_rounded, size: 11, color: colors.gold),
    );
  }
}
