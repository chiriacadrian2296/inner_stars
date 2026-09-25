import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// The five kinds of star — the app's whole vocabulary for *one effort*,
/// at every point in time an effort can be in.
///
/// A star is always an effort (past, present or future); its
/// intensity is the intensity of that effort. Which kind it is says *when*
/// the effort sits in time and whether it's still burning:
///
/// - [nascent] — an empty slot on a constellation's shape, drawn but not
///   configured yet. Neutral white. Becomes [lit] or [unlit] once the user
///   fills it in.
/// - [lit] — a victory. A past effort, already made, already burning gold.
/// - [unlit] — a goal. A future effort, still dark, waiting to be lit (or
///   to die).
/// - [pulsar] — a habit. A present effort, done day by day: gold on the
///   days it's kept, dark blue the moment the rhythm breaks.
/// - [dead] — a deleted star. Keeps its place in the sky forever and
///   remembers what it was, so reigniting it brings back the same kind.
///
/// The graphic families (see `StarGlyph` and `ConstellationPainter`):
/// light/gold ([lit]), no light/dark blue ([unlit], [dead]), both
/// ([pulsar], depending on today), neutral white ([nascent]).
enum StarKind { nascent, lit, unlit, pulsar, dead }

/// The three kinds a user can actually *create*, in the order the star form's
/// own switch shows them — past, present, future.
const kCreatableStarKinds = [StarKind.lit, StarKind.pulsar, StarKind.unlit];

/// The kinds that can appear in a list or a filter. [StarKind.nascent] is
/// left out on purpose: a nascent star has no record behind it, only a slot
/// on a shape, so there's nothing to list, search or filter for — you meet
/// one by looking at the sky, and nowhere else.
const kListableStarKinds = [
  StarKind.lit,
  StarKind.unlit,
  StarKind.pulsar,
  StarKind.dead,
];

extension StarKindX on StarKind {
  /// The one icon that stands for this kind everywhere it's named in text
  /// (cards, filter chips, the form's switch, the metaphor guide) — one
  /// distinct glyph per kind, never shared.
  IconData get icon => switch (this) {
    StarKind.nascent => Icons.circle_outlined,
    StarKind.lit => Icons.star,
    StarKind.unlit => Icons.star_border,
    StarKind.pulsar => Icons.restart_alt,
    StarKind.dead => Icons.hide_source,
  };

  /// Singular name ("Lit star"), for one card's own kind label. Not called
  /// `name` — that's already the enum's own value name.
  String label(AppStrings s) => switch (this) {
    StarKind.nascent => s.starKindNascentName,
    StarKind.lit => s.starKindLitName,
    StarKind.unlit => s.starKindUnlitName,
    StarKind.pulsar => s.starKindPulsarName,
    StarKind.dead => s.starKindDeadName,
  };

  /// Plural name ("Lit stars"), for filter chips and counts.
  String plural(AppStrings s) => switch (this) {
    StarKind.nascent => s.starKindNascentPlural,
    StarKind.lit => s.starKindLitPlural,
    StarKind.unlit => s.starKindUnlitPlural,
    StarKind.pulsar => s.starKindPulsarPlural,
    StarKind.dead => s.starKindDeadPlural,
  };

  /// What this kind *means* in plain words ("a victory — an effort you
  /// already made") — the bridge between the astronomy name and the thing
  /// it stands for. Shown under the name wherever a kind is being chosen or
  /// explained, never on its own.
  String meaning(AppStrings s) => switch (this) {
    StarKind.nascent => s.starKindNascentMeaning,
    StarKind.lit => s.starKindLitMeaning,
    StarKind.unlit => s.starKindUnlitMeaning,
    StarKind.pulsar => s.starKindPulsarMeaning,
    StarKind.dead => s.starKindDeadMeaning,
  };
}
