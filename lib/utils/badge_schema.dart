// Cell widths: room for the icon, a value of up to two digits, three
// characters or a `12/30`-like text, and the gap to the next cell.
const double _narrow = 38;
const double _medium = 46;
const double _wide = 58;

/// One kind of badge on a card. Every card of a kind always shows the same
/// slots in the same order (see [kBadgeRows]); a slot with nothing to say
/// shows a zero or a dash, it never disappears.
///
/// [width] is the slot's cell width in design units (the badge drawn at
/// scale 1: a 14 px icon, 11.5 px bold digits, plus the gap to the next
/// cell). Fixed cells keep the columns of every card of a kind lined up.
enum BadgeSlot {
  /// The card's intensity. It is not part of a row: it is drawn bigger above
  /// the card's first text (see `CardBadges.intensity`).
  intensity(_narrow),

  // A victory.
  voice(_narrow),
  photo(_narrow),
  video(_narrow),
  link(_narrow),

  /// A goal's or a dead star's own date (long form, it has the room).
  date(94),

  // A habit.
  progress(_medium),
  streak(_medium),

  // A constellation and an area.
  litOfTotal(_wide),
  litStars(_narrow),
  pulsarsToday(_medium),
  habits(_narrow),
  goals(_narrow),
  emptySlots(_narrow),
  deadStars(_narrow),
  constellations(_narrow);

  const BadgeSlot(this.width);

  final double width;
}

/// The kinds of card that carry badges.
enum BadgeCardKind { victory, goal, deadStar, habit, constellation, area }

/// The one place that decides which badges each card shows, in which order,
/// and how they are grouped: one inner list is one row. Nothing else
/// reorders them — the same way the quick-look buttons on the sky keep a
/// fixed order. Every card has a single row; its intensity, when it has one,
/// sits above its first text instead (see [BadgeSlot.intensity]).
const Map<BadgeCardKind, List<List<BadgeSlot>>> kBadgeRows = {
  BadgeCardKind.victory: [
    [BadgeSlot.voice, BadgeSlot.photo, BadgeSlot.video, BadgeSlot.link],
  ],
  BadgeCardKind.goal: [
    [BadgeSlot.date],
  ],
  BadgeCardKind.deadStar: [
    [BadgeSlot.date],
  ],
  BadgeCardKind.habit: [
    [BadgeSlot.progress, BadgeSlot.streak],
  ],
  BadgeCardKind.constellation: [
    [
      BadgeSlot.litOfTotal,
      BadgeSlot.pulsarsToday,
      BadgeSlot.goals,
      BadgeSlot.emptySlots,
      BadgeSlot.deadStars,
    ],
  ],
  BadgeCardKind.area: [
    [
      BadgeSlot.constellations,
      BadgeSlot.litStars,
      BadgeSlot.habits,
      BadgeSlot.goals,
      BadgeSlot.emptySlots,
      BadgeSlot.deadStars,
    ],
  ],
};

/// The width of each column of a grid of [rows]: the widest cell of that
/// column across all the rows. Every row uses these, so the cells of a
/// column — and their icons — line up one under the other.
List<double> badgeColumnWidths(List<List<BadgeSlot>> rows) {
  final columns = rows.fold<int>(
    0,
    (m, row) => row.length > m ? row.length : m,
  );
  return [
    for (var c = 0; c < columns; c++)
      rows
          .where((row) => c < row.length)
          .map((row) => row[c].width)
          .reduce((a, b) => a > b ? a : b),
  ];
}

/// The width of a whole grid of [rows] (the sum of its column widths).
double badgeGridWidth(List<List<BadgeSlot>> rows) =>
    badgeColumnWidths(rows).fold<double>(0, (sum, w) => sum + w);

/// The widest grid any card has: the width every card's badges are scaled
/// against, so the same tile width gives the same badge size whatever the
/// card.
final double kBadgeReferenceWidth = [
  for (final rows in kBadgeRows.values) badgeGridWidth(rows),
].reduce((a, b) => a > b ? a : b);
