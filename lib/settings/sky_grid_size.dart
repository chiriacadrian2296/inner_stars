/// The Sky grid's card sizes — a short, fixed list rather than a free range,
/// so the size slider jumps between a few deliberate sizes. Each value is the
/// width a card aims for (logical pixels); [skyGridColumnsFor] turns it into a
/// whole number of columns for the space available, so a phone gets 4, 3, 2
/// and 1 columns across the four steps and a wide window gets proportionally
/// more.
const List<double> kSkyGridTileExtents = [90, 120, 170, 320];

/// Parked (see the TRB): the Sky shows its grid only. The list view — its
/// cards, the list/grid switch in the controls sheet and the saved
/// [SettingsController.skyGridView] choice — is all still in place; flip this
/// back on to restore it exactly as before.
const bool kShowSkyListView = false;

/// Where a person who never touched the slider lands: the third step (Large).
const int kSkyGridDefaultSizeStep = 2;

int clampSkyGridSizeStep(int step) =>
    step.clamp(0, kSkyGridTileExtents.length - 1);

/// Columns for [step] in [availableWidth] (the grid's own width, without its
/// outer padding). Rounded — not ceiled like a max-extent grid does — so that
/// neighbouring steps never collapse onto the same column count.
int skyGridColumnsFor(int step, double availableWidth) {
  final target = kSkyGridTileExtents[clampSkyGridSizeStep(step)];
  return (availableWidth / target).round().clamp(1, 12);
}
