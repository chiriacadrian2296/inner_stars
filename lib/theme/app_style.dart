import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's shape and surface language, in one place.
///
/// Everything here descends from one image: a supernova. A white glyph
/// inside a gold ring, glowing outward against the night. That's the whole
/// grammar — **gold and glowing means burning** (chosen, filled, active,
/// primary), **navy and flat means dark** (available, empty, secondary).
/// Nothing in the app should invent a third way of saying either.
///
/// Concretely that means: one radius scale, one border rule, one glow, one
/// selected-surface treatment. Screens reach for these rather than
/// hand-rolling a `BoxDecoration`, so a control looks the same wherever it
/// turns up.

/// Corner radii — three steps, and no others.
///
/// [kRadiusField] covers anything you touch or type into: fields, tiles,
/// chips, pickers. [kRadiusCard] covers anything that *contains* those:
/// cards, panels, dialogs, sheets — always one step softer than its
/// contents, so a card never looks tighter than the things inside it.
/// Buttons and the sky's own overlay controls are pills instead
/// ([StadiumBorder]), which is what sets an *action* apart from a surface
/// at a glance.
const double kRadiusField = 12;
const double kRadiusCard = 16;

/// Any radius at or above this resolves to a stadium at the sizes the app
/// actually uses. Named rather than written as 20/22/30 at each site, which
/// is how three different "pills" ended up visibly different from each
/// other.
const double kRadiusPill = 999;

/// Border weights. Active is heavier as well as gold — the weight alone
/// carries the state for anyone who can't easily separate the two colors.
///
/// A hairline this thin is a logical-pixel width, not a physical one — on
/// a high-DPI phone (confirmed: the test emulator runs at
/// devicePixelRatio 2.625) a 1.0-wide border still resolves to a crisp
/// ~2.6 real pixels, but on a typical desktop browser window
/// (confirmed: devicePixelRatio 1.25) that same border resolves to barely
/// more than one real pixel, thin enough that anti-aliasing washes it out
/// to near-invisibility — not a rendering bug, just a width too thin to
/// survive a low-DPI display. Bumped enough to stay solid at low DPI
/// without reading as noticeably heavier on the high-DPI devices this was
/// already tuned for.
const double kBorderWidth = 1.5;
const double kBorderWidthActive = 2;

/// The one glow in the app: gold, soft, centered. Scaled by [strength]
/// (0 = none, 1 = a resting lit control, >1 = something actively pressed or
/// pulsing) and by [size], which should be roughly the control's own extent
/// so a small chip doesn't get a button-sized halo.
///
/// This is the supernova's own outer glow, reused where something is
/// actually burning — a lit star, a primary action disc/pill, a focused
/// field. Deliberately *not* used by [selectableDecoration]: a merely
/// chosen chip/button/toggle is lit, not burning, and stays flat.
List<BoxShadow> goldGlow(
  AppColors colors, {
  double strength = 1,
  double size = 48,
}) {
  if (strength <= 0) return const [];
  return [
    BoxShadow(
      color: colors.gold.withValues(alpha: 0.16 * strength),
      blurRadius: size * 0.42 * strength,
      spreadRadius: size * 0.01 * strength,
    ),
  ];
}

/// A plain surface: night panel, navy hairline border. The app's default
/// container — cards, sheets, anything not currently being acted on.
BoxDecoration panelDecoration(AppColors colors, {double radius = kRadiusCard}) {
  return BoxDecoration(
    color: colors.nightPanel,
    border: Border.all(color: colors.nightBorder, width: kBorderWidth),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// A surface that can be picked — a chip, a toggle pill, an icon tile, a
/// filter button, a kind card.
///
/// Unselected it's a plain panel. Selected it's the same panel with a gold
/// ring instead of a navy hairline — flat, not a glow or a radial fill.
/// There used to be a gold gradient-and-glow "burning" treatment here; it's
/// gone for good (confirmed unwanted, more than once) — don't reintroduce it
/// on a button, a switch/toggle pill, or a multi-choice chip.
BoxDecoration selectableDecoration(
  AppColors colors, {
  required bool selected,
  double radius = kRadiusField,
}) {
  return BoxDecoration(
    color: colors.nightPanel,
    border: Border.all(
      color: selected ? colors.gold : colors.nightBorder,
      // Never wider when selected: a border takes up room, so a thicker one
      // made the whole control grow. Only its color says it's chosen.
      width: kBorderWidth,
    ),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// The three states a field can be in, and the only three it can be in.
///
/// This is the rule the whole app now follows, and the one place it's
/// written down: a field is dark while it's empty, lights up once it holds
/// something, and burns brightest while you're actually in it. Before this,
/// typed fields went gold only on focus, picker fields went gold only once
/// filled, and date fields never went gold at all — three controls that
/// look identical behaving three different ways.
enum FieldState {
  /// Empty and not focused. Navy hairline, no light.
  empty,

  /// Holds a value. Gold ring, no glow — it's lit, but resting.
  filled,

  /// Being typed into or otherwise engaged. Gold ring and a glow.
  focused,
}

/// Resolves [FieldState] from the two things a field actually knows.
FieldState fieldStateOf({required bool hasValue, required bool focused}) {
  if (focused) return FieldState.focused;
  return hasValue ? FieldState.filled : FieldState.empty;
}

Color fieldBorderColor(AppColors colors, FieldState state) {
  return state == FieldState.empty ? colors.nightBorder : colors.gold;
}

/// The same in every state: a field's border takes up room, so a thicker one
/// for filled/focused made the field grow. The color (and the glow, which
/// takes up none) say what state it's in.
double fieldBorderWidth(FieldState state) => kBorderWidth;

/// The shared look of every field in the app — typed or tapped, they're the
/// same object to a user, so they get the same decoration from the same
/// function.
BoxDecoration fieldDecoration(AppColors colors, FieldState state) {
  return BoxDecoration(
    color: colors.nightPanel,
    borderRadius: BorderRadius.circular(kRadiusField),
    border: Border.all(
      color: fieldBorderColor(colors, state),
      width: fieldBorderWidth(state),
    ),
    boxShadow: state == FieldState.focused
        ? goldGlow(colors, strength: 0.7, size: 40)
        : null,
  );
}

/// The translucent disc/pill the sky's own overlay controls float in — the
/// only surface that sits directly on the sky rather than on a page, so it
/// keeps its transparency, but takes its gold ring and radius scale from
/// the same grammar as everything else.
BoxDecoration skyControlDecoration(
  AppColors colors, {
  bool circle = false,
  double radius = kRadiusField,
}) {
  return BoxDecoration(
    color: colors.nightPanel.withValues(alpha: 0.75),
    shape: circle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: circle ? null : BorderRadius.circular(radius),
    border: Border.all(color: colors.gold, width: kBorderWidthActive),
  );
}
