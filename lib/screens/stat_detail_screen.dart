import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/date_format.dart';
import '../utils/star_stats.dart';
import '../widgets/area_tag.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';

/// The dashboard's three stat cards (Total Stars, Current Streak, Longest
/// Streak) each open one of these — a closer look, in the same reflective,
/// gradient-background style as [StarReaderScreen], but built around one big
/// number and a card of supporting facts rather than a browsable star.
class TotalStarsDetailScreen extends StatelessWidget {
  const TotalStarsDetailScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final stars = starRepository.getAll().where((s) => s.isLit).toList();

    if (stars.isEmpty) {
      return _StatDetailScaffold(
        icon: Icons.star,
        value: '0',
        caption: strings.totalStarsLabel,
        body: _EmptyBody(text: strings.archiveEmpty),
      );
    }

    final byDateAscending = [...stars]
      ..sort((a, b) => a.achievedDate!.compareTo(b.achievedDate!));
    final combinedIntensity = stars.fold<int>(
      0,
      (sum, s) => sum + s.intensity!,
    );

    final projectsById = {
      for (final project in projectRepository.getAll()) project.id: project,
    };
    final countByArea = <LifeArea, int>{};
    for (final star in stars) {
      final area = projectsById[star.projectId]?.area;
      if (area == null) continue;
      countByArea[area] = (countByArea[area] ?? 0) + 1;
    }
    final areasByCount = countByArea.keys.toList()
      ..sort((a, b) => countByArea[b]!.compareTo(countByArea[a]!));

    return _StatDetailScaffold(
      icon: Icons.star,
      value: '${stars.length}',
      caption: strings.totalStarsLabel,
      body: Column(
        children: [
          _DetailCard(
            children: [
              _DetailRow(
                label: strings.firstStarLabel,
                value: formatDisplayDate(
                  byDateAscending.first.achievedDate!,
                  strings,
                ),
              ),
              _DetailRow(
                label: strings.mostRecentStarLabel,
                value: formatDisplayDate(
                  byDateAscending.last.achievedDate!,
                  strings,
                ),
              ),
              _DetailRow(
                label: strings.combinedIntensityLabel,
                value: '$combinedIntensity',
                isLast: true,
              ),
            ],
          ),
          if (areasByCount.isNotEmpty) ...[
            const SizedBox(height: 24),
            StaggeredEntrance(
              index: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.starsByAreaLabel,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colors.nightlightMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _DetailCard(
              divideRows: true,
              startIndex: 3,
              children: [
                for (var i = 0; i < areasByCount.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AreaTag(
                            area: areasByCount[i],
                            iconSize: 16,
                            fontSize: 14,
                            textColor: colors.text,
                          ),
                        ),
                        Text(
                          strings.starsCount(countByArea[areasByCount[i]]!),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.nightlightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CurrentStreakDetailScreen extends StatelessWidget {
  const CurrentStreakDetailScreen({super.key, required this.starRepository});

  final StarRepository starRepository;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final stars = starRepository.getAll().where((s) => s.isLit).toList();
    final dayCounts = starCountsByDay(stars);
    final range = currentStreakRange(dayCounts);

    if (dayCounts.isEmpty) {
      return _StatDetailScaffold(
        icon: Icons.local_fire_department,
        value: '0',
        caption: strings.currentStreakLabel,
        body: _EmptyBody(text: strings.archiveEmpty),
      );
    }
    if (range.length == 0) {
      return _StatDetailScaffold(
        icon: Icons.local_fire_department,
        value: '0',
        caption: strings.currentStreakLabel,
        body: _EmptyBody(text: strings.noCurrentStreakBody),
      );
    }

    return _StatDetailScaffold(
      icon: Icons.local_fire_department,
      value: '${range.length}',
      caption: strings.currentStreakLabel,
      body: _DetailCard(
        children: [
          _DetailRow(
            label: strings.streakFromLabel,
            value: formatDisplayDate(range.start!, strings),
          ),
          _DetailRow(label: strings.streakToLabel, value: strings.todayLabel),
          _DetailRow(
            label: strings.starsLoggedLabel,
            value: '${_starsWithinRange(stars, range)}',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class LongestStreakDetailScreen extends StatelessWidget {
  const LongestStreakDetailScreen({super.key, required this.starRepository});

  final StarRepository starRepository;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final stars = starRepository.getAll().where((s) => s.isLit).toList();
    final dayCounts = starCountsByDay(stars);
    final range = longestStreakRange(dayCounts);

    if (range.length == 0) {
      return _StatDetailScaffold(
        icon: Icons.emoji_events,
        value: '0',
        caption: strings.longestStreakLabel,
        body: _EmptyBody(text: strings.archiveEmpty),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final stillGoing = range.end == today;

    return _StatDetailScaffold(
      icon: Icons.emoji_events,
      value: '${range.length}',
      caption: strings.longestStreakLabel,
      body: _DetailCard(
        children: [
          _DetailRow(
            label: strings.streakFromLabel,
            value: formatDisplayDate(range.start!, strings),
          ),
          _DetailRow(
            label: strings.streakToLabel,
            value: stillGoing
                ? strings.todayLabel
                : formatDisplayDate(range.end!, strings),
          ),
          _DetailRow(
            label: strings.starsLoggedLabel,
            value: '${_starsWithinRange(stars, range)}',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

/// How many achieved stars fall within [range]'s inclusive day span — the
/// streak's length in days, unlike this, can be lower than the star count on
/// days where more than one victory was achieved.
int _starsWithinRange(List<Star> stars, StreakRange range) {
  final start = range.start!;
  final end = range.end!;
  return stars.where((s) {
    final date = s.achievedDate!;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }).length;
}

class _StatDetailScaffold extends StatelessWidget {
  const _StatDetailScaffold({
    required this.icon,
    required this.value,
    required this.caption,
    required this.body,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggeredEntrance(
                index: 0,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, color: colors.nightlightMuted),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // Top padding has to be generous, not just a small gap
                  // below the back button — the icon's own glow (28px blur)
                  // paints outside its 84x84 circle, and a scrollable clips
                  // to its own viewport bounds regardless of scroll
                  // position, so too little room here clips the glow itself.
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                  child: ResponsiveContent(
                    child: Column(
                      children: [
                        StaggeredEntrance(
                          index: 0,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.gold.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.gold.withValues(alpha: 0.4),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: Icon(icon, size: 38, color: colors.gold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 1,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontFamily: kFontMono,
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StaggeredEntrance(
                          index: 1,
                          child: Text(
                            caption.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: colors.accentDim,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        StaggeredEntrance(
                          index: 2,
                          child: body,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.children,
    this.divideRows = false,
    this.startIndex = 0,
  });

  final List<Widget> children;
  final bool divideRows;

  /// Entrance index of the first row; each following row arrives one step
  /// later, so the facts in a card appear one after another.
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: colors.nightlightMuted.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            StaggeredEntrance(
              index: startIndex + i,
              child: divideRows && i > 0
                  ? Column(
                      children: [
                        Divider(
                          color: colors.nightlightMuted.withValues(alpha: 0.12),
                          height: 1,
                        ),
                        children[i],
                      ],
                    )
                  : children[i],
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.nightlightMuted.withValues(alpha: 0.12),
                ),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: colors.nightlightMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: kFontMono,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: context.colors.nightlightMuted,
      ),
    );
  }
}
