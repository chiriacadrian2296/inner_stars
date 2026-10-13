import '../l10n/app_strings.dart';

/// Which of an item's dates the Sky date-range filter and date sort look at.
/// Not every item has every one: see [Star] / [Habit] / [Project] — an
/// item without the chosen date is left out of a date range and sorts last.
enum SkyDateField {
  /// When the item was first made.
  created,

  /// When the item was last edited (falls back to creation for old records).
  modified,

  /// When the thing itself happened: a victory's achieved date, a goal's
  /// target date. Habits and archived items have none.
  occurred;

  String label(AppStrings strings) => switch (this) {
    created => strings.dateFieldCreated,
    modified => strings.dateFieldModified,
    occurred => strings.dateFieldOccurred,
  };
}
