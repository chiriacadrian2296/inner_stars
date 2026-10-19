/// One completed cycle of a pulsar: the moment its [length] distinct days
/// were reached and the [intensity] reward was earned.
///
/// Created the instant the goal is reached — the reward is real at once, like
/// lighting a star — and [resolved] flips once the user has gone through the
/// end-of-cycle reflection and chosen how to continue. An unresolved cycle is
/// simply a reflection still waiting to be opened.
class HabitCycle {
  const HabitCycle({
    required this.id,
    DateTime? updatedAt,
    this.deleted = false,
    required this.habitId,
    required this.startDate,
    required this.completedDate,
    required this.length,
    required this.intensity,
    this.resolved = false,
    this.whatHelped,
    this.whatWasHard,
    this.howItFeels,
  }) : updatedAt = updatedAt ?? completedDate,
       assert(
         intensity >= 1 && intensity <= 5,
         'intensity must be 1-5, was $intensity',
       );

  final String id;
  final DateTime updatedAt;
  final bool deleted;
  final String habitId;

  /// First day (midnight) that counted toward this cycle.
  final DateTime startDate;

  /// The day (midnight) the last needed repetition happened — when the
  /// reward lands in the stats.
  final DateTime completedDate;

  /// How many distinct days the cycle asked for.
  final int length;

  /// The reward earned, frozen at the moment the cycle was completed so later
  /// edits to the pulsar never rewrite history.
  final int intensity;

  /// Whether the end-of-cycle reflection has been finished.
  final bool resolved;

  /// The optional guided answers from the reflection page.
  final String? whatHelped;
  final String? whatWasHard;
  final String? howItFeels;

  bool get hasReflection =>
      (whatHelped?.isNotEmpty ?? false) ||
      (whatWasHard?.isNotEmpty ?? false) ||
      (howItFeels?.isNotEmpty ?? false);

  HabitCycle copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? resolved,
    String? whatHelped,
    String? whatWasHard,
    String? howItFeels,
  }) {
    return HabitCycle(
      id: id,
      habitId: habitId,
      startDate: startDate,
      completedDate: completedDate,
      length: length,
      intensity: intensity,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      resolved: resolved ?? this.resolved,
      whatHelped: whatHelped ?? this.whatHelped,
      whatWasHard: whatWasHard ?? this.whatWasHard,
      howItFeels: howItFeels ?? this.howItFeels,
    );
  }

  factory HabitCycle.fromJson(Map<String, dynamic> json) {
    return HabitCycle(
      id: json['id'] as String,
      updatedAt: (json['updatedAt'] as String?) == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      deleted: json['deleted'] as bool? ?? false,
      habitId: json['habitId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      completedDate: DateTime.parse(json['completedDate'] as String),
      length: json['length'] as int,
      intensity: json['intensity'] as int,
      resolved: json['resolved'] as bool? ?? false,
      whatHelped: json['whatHelped'] as String?,
      whatWasHard: json['whatWasHard'] as String?,
      howItFeels: json['howItFeels'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
      'habitId': habitId,
      'startDate': startDate.toIso8601String(),
      'completedDate': completedDate.toIso8601String(),
      'length': length,
      'intensity': intensity,
      'resolved': resolved,
      'whatHelped': whatHelped,
      'whatWasHard': whatWasHard,
      'howItFeels': howItFeels,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is HabitCycle &&
        other.id == id &&
        other.updatedAt == updatedAt &&
        other.deleted == deleted &&
        other.habitId == habitId &&
        other.startDate == startDate &&
        other.completedDate == completedDate &&
        other.length == length &&
        other.intensity == intensity &&
        other.resolved == resolved &&
        other.whatHelped == whatHelped &&
        other.whatWasHard == whatWasHard &&
        other.howItFeels == howItFeels;
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deleted,
    habitId,
    startDate,
    completedDate,
    length,
    intensity,
    resolved,
    whatHelped,
    whatWasHard,
    howItFeels,
  );
}
