import '../l10n/app_strings.dart';

/// Formats a date as e.g. "26 Aug 2026", using [strings]' localized month
/// abbreviations.
String formatDisplayDate(DateTime date, AppStrings strings) {
  final day = date.day.toString().padLeft(2, '0');
  final month = strings.monthAbbreviations[date.month - 1];
  return '$day $month ${date.year}';
}

/// Formats a date as e.g. "15/06" — day/month only, no year, both numeric
/// so it needs no locale data. Used where space is tight (the date-range
/// filter button) and the year is implied by context.
String formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

/// [formatShortDate] plus a 2-digit year, e.g. "15/06/25" — for the one case
/// where the year *isn't* implied by context: a date-range filter button
/// showing a span that reaches outside the current year.
String formatShortDateWithYear(DateTime date) {
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '${formatShortDate(date)}/$year';
}

/// Formats a time as e.g. "14:32" (24-hour, no AM/PM ambiguity to localize).
String formatDisplayTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Formats a date and time as e.g. "26 Aug 2026 · 14:32".
String formatDisplayDateTime(DateTime date, AppStrings strings) {
  return '${formatDisplayDate(date, strings)} · ${formatDisplayTime(date)}';
}
