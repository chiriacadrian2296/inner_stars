import 'package:flutter/material.dart';

import '../utils/area_hero_art_tone.dart';

/// Keeps the bottom 23% of the square artwork, including its tagline,
/// pinned as the image scrolls out of view, gently enlarging its tagline
/// during the final part of the collapse.
class AreaArtworkHeader extends SliverPersistentHeaderDelegate {
  const AreaArtworkHeader({
    required this.asset,
    required this.imageSize,
    required this.label,
    required this.onTap,
    this.topInset = 0,
  });

  final String asset;
  final double imageSize;
  final String label;
  final VoidCallback onTap;
  final double topInset;

  @override
  double get minExtent => (imageSize * 0.23 + topInset).clamp(0, imageSize);

  @override
  double get maxExtent => imageSize;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;
    final progress = collapseRange <= 0
        ? 0.0
        : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final zoomProgress = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
    final scale = 1 + 0.25 * Curves.easeInOut.transform(zoomProgress);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          if (zoomProgress > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: zoomProgress),
              blurRadius: 42,
              spreadRadius: 8,
              offset: const Offset(0, 16),
            ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: imageSize,
          child: Semantics(
            button: true,
            label: label,
            child: Tooltip(
              message: label,
              child: InkWell(
                onTap: onTap,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minHeight: imageSize,
                    maxHeight: imageSize,
                    child: Transform.scale(
                      scale: scale,
                      // Taglines sit around 86% of the artwork's height.
                      // Anchor there so zooming does not push them out of view.
                      alignment: const Alignment(0, 0.72),
                      child: tonedAreaHeroArt(
                        child: Image.asset(
                          asset,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant AreaArtworkHeader oldDelegate) =>
      asset != oldDelegate.asset ||
      imageSize != oldDelegate.imageSize ||
      topInset != oldDelegate.topInset ||
      label != oldDelegate.label ||
      onTap != oldDelegate.onTap;
}
