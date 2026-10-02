import 'package:flutter/material.dart';

import '../data/moodboard_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'moodboard_grid.dart';
import 'share_arrangement.dart';
import 'vision_markdown.dart';

class ShareableVisionCard extends StatelessWidget {
  const ShareableVisionCard({
    super.key,
    required this.area,
    required this.vision,
  });

  final LifeArea area;
  final String vision;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final arrangement = ShareArrangementScope.of(context);
    final cleanVision = vision
        .replaceAll(RegExp(r'[#*_>`]'), '')
        .replaceAll(RegExp(r'<\/?u>'), '')
        .trim();
    return ColoredBox(
      color: colors.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: switch (arrangement) {
            ShareArrangement.editorial => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VICTORY STARS',
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const Spacer(),
                Icon(area.icon, color: colors.gold, size: 38),
                const SizedBox(height: 16),
                Text(
                  '${strings.visionSection} · ${area.displayName(strings)}',
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Flexible(child: VisionMarkdown(data: vision)),
                const Spacer(),
              ],
            ),
            ShareArrangement.photographic => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(area.icon, color: colors.gold, size: 54),
                    const Spacer(),
                    Text(
                      'VICTORY STARS',
                      style: TextStyle(
                        color: colors.gold,
                        fontFamily: kFontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  area.displayName(strings),
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.visionSection.toUpperCase(),
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Flexible(child: VisionMarkdown(data: vision)),
              ],
            ),
            ShareArrangement.statement => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(area.icon, color: colors.gold, size: 30),
                    const Spacer(),
                    Text(
                      'VICTORY STARS',
                      style: TextStyle(
                        color: colors.gold,
                        fontFamily: kFontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  cleanVision,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Container(height: 1, color: colors.gold.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '${strings.visionSection} · ${area.displayName(strings)}',
                  style: TextStyle(
                    color: colors.muted,
                    fontFamily: kFontMono,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class ShareableMoodboardCard extends StatelessWidget {
  const ShareableMoodboardCard({
    super.key,
    required this.area,
    required this.items,
  });

  final LifeArea area;
  final List<MoodboardItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final arrangement = ShareArrangementScope.of(context);
    final grid = MoodboardGrid(
      items: items.take(6).toList(),
      placeholders: items.isEmpty,
      showEmptyMessage: false,
    );
    return ColoredBox(
      color: colors.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: switch (arrangement) {
            ShareArrangement.editorial => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VICTORY STARS',
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${strings.moodboardTitle} · ${area.displayName(strings)}',
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: ClipRect(child: grid)),
              ],
            ),
            ShareArrangement.photographic => Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(child: grid),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colors.night.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: Text(
                      '${strings.moodboardTitle} · ${area.displayName(strings)}',
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: kFontStarTitle,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ShareArrangement.statement => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(area.icon, color: colors.gold, size: 32),
                    const Spacer(),
                    Text(
                      'VICTORY STARS',
                      style: TextStyle(
                        color: colors.gold,
                        fontFamily: kFontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  area.displayName(strings),
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 42,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  strings.moodboardTitle.toUpperCase(),
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(height: 250, child: ClipRect(child: grid)),
                const Spacer(),
              ],
            ),
          },
        ),
      ),
    );
  }
}
