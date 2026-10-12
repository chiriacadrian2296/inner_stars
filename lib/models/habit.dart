/// [daily]: `targetPerPeriod` times *that day* (reset every midnight).
/// [weekly]: `targetPerPeriod` times on that many *distinct* days within one
/// calendar week (Monday–Sunday) — two sessions the same day still count as
/// one day toward the target, not two. See `habit_stats.dart` for exactly
/// how each is scored.
enum HabitFrequency { daily, weekly }

/// A pulsar: the *present* effort — something you keep doing day by day,
/// tracked separately from a constellation's own shape as its own small,
/// scattered star. Gold on the days the rhythm is kept (see
/// `habit_stats.dart`), dark blue the moment it breaks.
///
/// Like every other star, a pulsar carries an [intensity] — how much the
/// effort costs you each day, not how long the streak is.
///
/// Deleting a pulsar never removes its record: [dead] is set instead, the
/// same tombstone a [Star] gets, so it stays in the sky as a dead star that
/// still remembers it was a pulsar. Reigniting it (see
/// [HabitRepository.resurrect]) therefore always brings back a pulsar,
/// never some other kind of star.
class Habit {
  const Habit({
    required this.id,
    required this.projectId,
    required this.title,
    this.iconSlug = '',
    this.description,
    required this.createdAt,
    this.frequency = HabitFrequency.daily,
    this.targetPerPeriod = 1,
    this.intensity = 3,
    this.reminderHour,
    this.reminderMinute,
    this.dead = false,
    this.deadDate,
  }) : assert(
         intensity >= 1 && intensity <= 5,
         'intensity must be 1-5, was $intensity',
       );

  final int id;
  final int projectId;
  final String title;

  /// An empty slug keeps the original activity icon for older records.
  final String iconSlug;
  final String? description;
  final DateTime createdAt;

  final HabitFrequency frequency;

  /// How many times [frequency]'s own period asks for — see
  /// [HabitFrequency]'s own doc comment for what that means per value.
  final int targetPerPeriod;

  /// How much effort keeping this up costs on a given day, 1 (light) to 5
  /// (a lot) — the same scale a [Star]'s own intensity uses, so "intensity
  /// of the effort" means one single thing across every kind of star.
  /// Defaults to 3 rather than being nullable: unlike a goal (whose real
  /// cost is only known once it's reached), a habit's cost is knowable the
  /// day it's created, and pulsars stored before this field existed read
  /// back as a plain middle value instead of a hole.
  final int intensity;

  /// null = inherits the app's single global reminder time
  /// ([SettingsController]). Not yet acted on by [ReminderService] in v1 —
  /// see its own doc comment.
  final int? reminderHour;
  final int? reminderMinute;

  /// Tombstone: true once this pulsar has been "deleted". It stops counting
  /// as an active pulsar anywhere, and renders as a dead star instead.
  final bool dead;

  /// When [dead] became true. Null for a pulsar that's never been deleted;
  /// cleared on resurrection along with [dead] itself.
  final DateTime? deadDate;

  bool get isActive => !dead;

  Habit copyWith({
    int? id,
    int? projectId,
    String? title,
    String? iconSlug,
    String? description,
    DateTime? createdAt,
    HabitFrequency? frequency,
    int? targetPerPeriod,
    int? intensity,
    int? reminderHour,
    int? reminderMinute,
    bool? dead,
    DateTime? deadDate,
  }) {
    return Habit(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      iconSlug: iconSlug ?? this.iconSlug,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      frequency: frequency ?? this.frequency,
      targetPerPeriod: targetPerPeriod ?? this.targetPerPeriod,
      intensity: intensity ?? this.intensity,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      dead: dead ?? this.dead,
      deadDate: deadDate ?? this.deadDate,
    );
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as int,
      projectId: json['projectId'] as int,
      title: json['title'] as String,
      iconSlug: json['iconSlug'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      frequency: HabitFrequency.values.byName(
        json['frequency'] as String? ?? 'daily',
      ),
      targetPerPeriod: json['targetPerPeriod'] as int? ?? 1,
      // Pre-intensity pulsars read back as the middle of the scale rather
      // than failing the constructor's own assert.
      intensity: json['intensity'] as int? ?? 3,
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
      dead: json['dead'] as bool? ?? false,
      deadDate: switch (json['deadDate'] as String?) {
        final value? => DateTime.parse(value),
        null => null,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'iconSlug': iconSlug,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'frequency': frequency.name,
      'targetPerPeriod': targetPerPeriod,
      'intensity': intensity,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'dead': dead,
      'deadDate': deadDate?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Habit &&
        other.id == id &&
        other.projectId == projectId &&
        other.title == title &&
        other.iconSlug == iconSlug &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.frequency == frequency &&
        other.targetPerPeriod == targetPerPeriod &&
        other.intensity == intensity &&
        other.reminderHour == reminderHour &&
        other.reminderMinute == reminderMinute &&
        other.dead == dead &&
        other.deadDate == deadDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    iconSlug,
    description,
    createdAt,
    frequency,
    targetPerPeriod,
    intensity,
    reminderHour,
    reminderMinute,
    dead,
    deadDate,
  );
}
