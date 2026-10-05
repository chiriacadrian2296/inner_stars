// Calendar-day arithmetic that stays correct across daylight-saving changes.
//
// `DateTime.add(Duration(days: n))` / `difference().inDays` count 24-hour
// blocks, so on a local date a DST shift lands on 23:00 or 01:00 instead of
// midnight (breaking lookups keyed by midnight dates) or reports a one-day
// gap as zero days. These helpers work on the calendar fields instead.

/// [date] truncated to local midnight.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The calendar day [days] after [date] (negative for before), at midnight.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier),
/// ignoring time of day and DST.
int dayDiff(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
