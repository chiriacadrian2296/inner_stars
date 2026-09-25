import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/date_format.dart';
import 'intensity_bolts.dart';
import 'staggered_entrance.dart';
import 'star_glyph.dart';

/// How a reader page's blocks arrive — see `StarReaderScreen`: the same
/// staggered cascade for every kind of page, half as spread out (and held
/// back by [lead] steps, until the page leaving has faded) when swiping.
class ReaderEntrance {
  const ReaderEntrance({
    required this.animate,
    required this.axis,
    required this.reverse,
    required this.lead,
    this.drift = 0.06,
  });

  final bool animate;
  final Axis axis;
  final bool reverse;
  final int lead;

  /// How far a vertical entrance rises from, as a fraction of the block's own
  /// height (see [StaggeredEntrance.drift]).
  final double drift;

  /// The same cascade, but always rising from below by [drift] — for blocks
  /// that should come up rather than in from the side.
  ReaderEntrance risingFromBelow({double drift = 0.7}) => ReaderEntrance(
    animate: animate,
    axis: Axis.vertical,
    reverse: false,
    lead: 0,
    drift: drift,
  );

  /// Wraps [child] as the [order]th block to arrive.
  Widget call(int order, Widget child) => StaggeredEntrance(
    index: axis == Axis.horizontal ? order ~/ 2 + lead : order,
    enabled: animate,
    axis: axis,
    reverse: reverse,
    drift: drift,
    child: child,
  );
}

/// One reader page, whichever kind of star it is — the same four groups in
/// the same order, so moving between stars never rearranges the page:
///
/// 1. **What it is** — the kind's icon (in its own color), its name in
///    white, and the day it was created as the last, smallest line.
/// 2. **Where it is** — area › constellation › number, as one breadcrumb line.
/// 3. **Its particular data** — intensity, target date, streak…: a slot of a
///    fixed height whatever it holds (or nothing), so the texts below always
///    start at the same place.
/// 4. **Its texts** — title and description, or for a kind with none (an
///    empty slot, a dead star) a short note.
class ReaderPage extends StatelessWidget {
  const ReaderPage({
    super.key,
    required this.kind,
    this.lit = true,
    required this.entrance,
    this.createdAt,
    this.project,
    this.numberLabel,
    this.extra,
    this.reserveExtraSlot = true,
    this.title,
    this.titleColor,
    this.description,
    this.note,
  });

  final StarKind kind;

  /// Only matters for a pulsar (burning or dark).
  final bool lit;
  final ReaderEntrance entrance;
  final DateTime? createdAt;
  final Project? project;

  /// "Star #3", "Habit #2" — the last crumb.
  final String? numberLabel;

  /// The particular-data block, laid out inside a slot of [extraHeight].
  final Widget? extra;

  /// Whether the slot is kept even with nothing in it. Off only for a dead
  /// star (a failure), which has no particular data at all.
  final bool reserveExtraSlot;
  final String? title;
  final Color? titleColor;
  final String? description;
  final String? note;

  /// Tall enough for the biggest thing that goes in the data slot.
  static const extraHeight = 76.0;

  static const _iconSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final tint = starKindColor(kind, colors, lit: lit);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. What it is.
        entrance(1, Icon(kind.icon, size: _iconSize, color: tint)),
        const SizedBox(height: 10),
        entrance(
          2,
          Text(
            kind.label(strings),
            textAlign: TextAlign.center,
            // Sized to the icon above it.
            style: TextStyle(
              fontSize: _iconSize * 0.42,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 6),
        entrance(
          2,
          SizedBox(
            height: 16,
            child: createdAt == null
                ? null
                : Text(
                    strings.createdOnLabel(
                      formatDisplayDate(createdAt!, strings),
                    ),
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. Where it is.
        entrance(3, _Breadcrumbs(project: project, numberLabel: numberLabel)),
        const SizedBox(height: 18),

        // 3. Its particular data, in a slot that never changes height.
        if (reserveExtraSlot) ...[
          entrance(
            4,
            SizedBox(
              height: extraHeight,
              child: Center(child: extra ?? const SizedBox.shrink()),
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 4. Its texts.
        if (title != null)
          entrance(
            5,
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontStarTitle,
                fontStyle: FontStyle.italic,
                fontSize: 34,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: titleColor ?? colors.text,
              ),
            ),
          ),
        if (description != null) ...[
          const SizedBox(height: 22),
          entrance(
            6,
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.6,
                color: colors.nightlightMuted,
              ),
            ),
          ),
        ],
        if (note != null) ...[
          SizedBox(height: title == null ? 0 : 16),
          entrance(
            6,
            Text(
              note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: colors.nightlightMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// area › constellation › number, always on one line: each crumb is its
/// generic icon (a supernova, a constellation, a number — the same for every
/// area and project) with the text under it, and a name too long for its
/// share is cut with an ellipsis rather than wrapping the row.
class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.project, required this.numberLabel});

  final Project? project;
  final String? numberLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final crumbs = <Widget>[
      if (project != null) ...[
        _Crumb(icon: Icons.flare, text: project!.area.displayName(strings)),
        _Crumb(icon: Icons.insights, text: project!.name),
      ],
      if (numberLabel != null) _Crumb(icon: Icons.tag, text: numberLabel!),
    ];
    if (crumbs.isEmpty) return const SizedBox(height: 20);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            // Level with the text lines, under the icons: an icon and its
            // gap (18 + 3), then centered on a 13 px line of text.
            Padding(
              padding: const EdgeInsets.only(top: 21, left: 4, right: 4),
              child: Icon(Icons.chevron_right, size: 16, color: colors.muted),
            ),
          Flexible(child: crumbs[i]),
        ],
      ],
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.gold),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.nightlightMuted,
          ),
        ),
      ],
    );
  }
}

/// A big value with a small caption under it — how every kind's particular
/// data is shown, so they all take the same room.
class _DataBlock extends StatelessWidget {
  const _DataBlock({required this.value, this.caption});

  final Widget value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// A star's page in the star reader: a victory, a goal, or (deleted) a
/// failure.
class StarReaderContent extends StatelessWidget {
  const StarReaderContent({
    super.key,
    required this.star,
    required this.project,
    required this.entrance,
  });

  final Star star;
  final Project? project;
  final ReaderEntrance entrance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    Widget? extra;
    if (star.dead) {
      extra = null;
    } else if (star.isLit) {
      extra = _DataBlock(
        value: IntensityBolts(
          intensity: star.intensity!,
          size: 28,
          spacing: 6,
          emphasizeLast: true,
        ),
      );
    } else {
      // Gold with a date, blue (the unlit star's own color) without one.
      final hasDate = star.targetDate != null;
      final tint = hasDate ? colors.gold : colors.starUnlit;
      extra = _DataBlock(
        value: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 28, color: tint),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasDate
                    ? formatDisplayDate(star.targetDate!, strings)
                    : strings.noDateShortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
        caption: strings.targetDateBadgeLabel,
      );
    }

    return ReaderPage(
      kind: star.kind,
      entrance: entrance,
      reserveExtraSlot: !star.dead,
      createdAt: star.createdAt,
      project: project,
      numberLabel: strings.starSlotLabel(star.slotSequence),
      extra: extra,
      title: star.title,
      titleColor: star.dead ? colors.muted : null,
      description: star.dead ? null : star.description,
      note: star.dead ? strings.deadStarBody : null,
    );
  }
}

/// A pulsar's page in the star reader — a habit, burning (kept today) or
/// dark; deleted, a failure.
class PulsarReaderContent extends StatelessWidget {
  const PulsarReaderContent({
    super.key,
    required this.habit,
    required this.project,
    required this.number,
    required this.lit,
    required this.streak,
    required this.weekProgress,
    required this.entrance,
  });

  final Habit habit;
  final Project? project;

  /// Which habit of the constellation this is, from 1 in order of creation.
  final int? number;
  final bool lit;
  final int streak;

  /// Only shown for a weekly habit.
  final int weekProgress;
  final ReaderEntrance entrance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final tint = starKindColor(StarKind.pulsar, colors, lit: lit);

    Widget? extra;
    if (!habit.dead) {
      final isWeekly = habit.frequency == HabitFrequency.weekly;
      extra = _DataBlock(
        value: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 40, color: tint),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: tint,
                height: 1,
              ),
            ),
          ],
        ),
        caption: isWeekly
            ? '${strings.habitCurrentStreakLabel} · '
                  '${strings.habitProgressThisWeek(weekProgress, habit.targetPerPeriod)}'
            : strings.habitCurrentStreakLabel,
      );
    }

    return ReaderPage(
      kind: habit.dead ? StarKind.dead : StarKind.pulsar,
      lit: lit,
      entrance: entrance,
      reserveExtraSlot: !habit.dead,
      createdAt: habit.createdAt,
      project: project,
      numberLabel: number == null ? null : strings.pulsarNumberLabel(number!),
      extra: extra,
      title: habit.title,
      titleColor: habit.dead ? colors.muted : null,
      description: habit.dead ? null : habit.description,
      note: habit.dead ? strings.deadPulsarBody : null,
    );
  }
}

/// A nascent star's page in the star reader — an empty slot on the
/// constellation's shape, with nothing to read yet: what it is, which star
/// of the shape it would be, whose it is, and (from the reader's own bottom
/// action) the way to give it a meaning.
class NascentReaderContent extends StatelessWidget {
  const NascentReaderContent({
    super.key,
    required this.slot,
    required this.project,
    required this.entrance,
  });

  final int slot;
  final Project? project;
  final ReaderEntrance entrance;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ReaderPage(
      kind: StarKind.nascent,
      entrance: entrance,
      project: project,
      numberLabel: strings.starSlotLabel(slot),
      note: strings.starKindNascentMeaning,
    );
  }
}
