/// One day a [Habit] was completed. Day-granularity only — [date] is always
/// normalized to midnight at write time (see `HabitCompletionRepository`),
/// since time-of-day is meaningless for a "once a day" target.
class HabitCompletion {
  const HabitCompletion({
    required this.id,
    DateTime? updatedAt,
    this.deleted = false,
    required this.habitId,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? date,
       updatedAt = updatedAt ?? createdAt ?? date;

  final String id;
  final DateTime updatedAt;
  final bool deleted;
  final String habitId;
  final DateTime date;

  /// When the check-in was logged, independently of its calendar day.
  final DateTime createdAt;

  factory HabitCompletion.fromJson(Map<String, dynamic> json) {
    return HabitCompletion(
      updatedAt: (json['updatedAt'] as String?) == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      deleted: json['deleted'] as bool? ?? false,
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse((json['createdAt'] ?? json['date']) as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
      'habitId': habitId,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is HabitCompletion &&
        other.id == id &&
        other.updatedAt == updatedAt &&
        other.deleted == deleted &&
        other.habitId == habitId &&
        other.date == date &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deleted, id, habitId, date, createdAt);
}
