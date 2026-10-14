/// One point of a cumulative curve: the running [total] reached by [date].
/// Built by `LightStats.cumulative`, drawn by `AccumulationChart`.
class CelebrationPoint {
  const CelebrationPoint(this.date, this.total);
  final DateTime date;
  final int total;
}
