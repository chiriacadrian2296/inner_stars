import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../utils/badge_schema.dart';
import '../utils/project_card_info.dart';
import '../utils/star_card_info.dart';
import '../widgets/badge_icon.dart';
import '../widgets/badge_rows.dart';

/// A lab page for the card badges: the real rows of every kind of card with
/// the boxes of each cell, icon and text tinted, to see how the icons sit —
/// their size, the space around them, the gap to the text and between
/// badges — and every badge icon on its own, raw next to corrected.
class BadgeLabScreen extends StatefulWidget {
  const BadgeLabScreen({super.key});

  @override
  State<BadgeLabScreen> createState() => _BadgeLabScreenState();
}

class _BadgeLabScreenState extends State<BadgeLabScreen> {
  double _zoom = 2.5;
  bool _boxes = true;
  bool _raw = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final created = DateTime(2026, 1, 1);
    final now = DateTime.now();

    StarMedia media(StarMediaKind kind, String id) => StarMedia(
      id: id,
      kind: kind,
      path: kind == StarMediaKind.link ? null : 'file-$id',
      url: kind == StarMediaKind.link ? 'https://example.com' : null,
      createdAt: created,
    );
    final victory = Star(
      id: 1,
      projectId: 1,
      slotSequence: 1,
      title: 'Victory',
      createdAt: created,
      achievedDate: created,
      intensity: 5,
      media: [
        media(StarMediaKind.voice, 'a'),
        media(StarMediaKind.photo, 'b'),
        media(StarMediaKind.photo, 'c'),
        media(StarMediaKind.video, 'd'),
        media(StarMediaKind.link, 'e'),
      ],
    );
    final goal = Star(
      id: 2,
      projectId: 1,
      slotSequence: 2,
      title: 'Goal',
      createdAt: created,
      targetDate: DateTime(now.year, now.month, now.day + 20),
    );
    final dead = Star(
      id: 3,
      projectId: 1,
      slotSequence: 3,
      title: 'Dead',
      createdAt: created,
      dead: true,
      deadDate: created,
    );
    final dailyHabit = Habit(
      id: 1,
      projectId: 1,
      title: 'Daily',
      createdAt: created,
      frequency: HabitFrequency.daily,
      targetPerPeriod: 3,
    );
    final weeklyHabit = Habit(
      id: 2,
      projectId: 1,
      title: 'Weekly',
      createdAt: created,
      frequency: HabitFrequency.weekly,
      targetPerPeriod: 3,
    );
    final stars = [victory, goal, dead];
    final samples = <(String, CardBadges)>[
      ('Victory', starCardBadges(victory, colors, strings)),
      ('Goal', starCardBadges(goal, colors, strings)),
      ('Dead star', starCardBadges(dead, colors, strings)),
      (
        'Habit, daily 2/3',
        habitCardBadges(
          dailyHabit,
          {DateTime(now.year, now.month, now.day): 2},
          colors,
          strings,
        ),
      ),
      ('Habit, weekly', habitCardBadges(weeklyHabit, {}, colors, strings)),
      (
        'Constellation',
        projectCardBadges(
          stars: stars,
          habits: [dailyHabit, weeklyHabit],
          slotCount: 8,
          colors: colors,
          strings: strings,
        ),
      ),
      (
        'Area',
        areaCardBadges(
          constellationCount: 4,
          stars: stars,
          habits: [dailyHabit, weeklyHabit],
          emptySlots: 5,
          colors: colors,
          strings: strings,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge lab'),
        backgroundColor: colors.night,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'Blue: a badge cell. Green: the icon box. Red: the value box.',
              style: TextStyle(color: colors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Zoom', style: TextStyle(color: colors.text)),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1,
                    max: 4,
                    divisions: 12,
                    label: '${_zoom.toStringAsFixed(2)}x',
                    onChanged: (value) => setState(() => _zoom = value),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tinted boxes'),
              value: _boxes,
              onChanged: (value) => setState(() => _boxes = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Raw icons (no optical correction)'),
              value: _raw,
              onChanged: (value) => setState(() => _raw = value),
            ),
            const SizedBox(height: 12),
            _Heading('Rows', colors),
            for (final (label, badges) in samples) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Text(
                  label,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _Panel(
                  colors: colors,
                  child: SizedBox(
                    width: kBadgeReferenceWidth * _zoom,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badges.intensity != null) ...[
                          IntensityBadge(
                            badge: badges.intensity!,
                            scale: _zoom,
                          ),
                          SizedBox(height: 6 * _zoom),
                        ],
                        BadgeRows(
                          rows: badges.rows,
                          maxScale: _zoom,
                          debug: _boxes,
                          rawIcons: _raw,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            _Heading('Icons: raw | corrected', colors),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final icon in kBadgeIconSet)
                  _IconSample(icon: icon, colors: colors, zoom: _zoom),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.colors);

  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: colors.text,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.colors, required this.child});

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.nightPanel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.nightBorder),
    ),
    child: child,
  );
}

/// One badge icon at the badge size in its 24-unit grid box, raw and then
/// corrected, with a cross at the centre of the box.
class _IconSample extends StatelessWidget {
  const _IconSample({
    required this.icon,
    required this.colors,
    required this.zoom,
  });

  final IconData icon;
  final AppColors colors;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final size = BadgeRows.iconSize * zoom;
    Widget box(Widget child) => Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          color: Colors.blue.withValues(alpha: 0.25),
        ),
        Container(width: size, height: 1, color: Colors.white24),
        Container(width: 1, height: size, color: Colors.white24),
        child,
      ],
    );
    return _Panel(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              box(BadgeIcon(icon, size: size, color: colors.gold, raw: true)),
              SizedBox(width: 8 * zoom),
              box(BadgeIcon(icon, size: size, color: colors.gold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            icon.codePoint.toRadixString(16),
            style: TextStyle(color: colors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
