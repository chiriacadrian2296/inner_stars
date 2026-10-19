/// [daily]: `targetPerPeriod` times *that day* (reset every midnight).
/// [weekly]: `targetPerPeriod` times on that many *distinct* days within one
/// calendar week (Monday–Sunday) — two sessions the same day still count as
/// one day toward the target, not two. See `habit_stats.dart` for exactly
/// how each is scored.
enum HabitFrequency { daily, weekly }

/// Shortest and longest cycle a pulsar can have, and the one new pulsars
/// start with. The form offers [kCyclePresets] as quick picks plus a custom
/// value.
const int kMinCycleLength = 1;
const int kMaxCycleLength = 365;
const int kDefaultCycleLength = 30;
const List<int> kCyclePresets = [7, 30, 90];

/// A pulsar: the *present* effort — something you keep doing day by day,
/// tracked separately from a constellation's own shape as its own small,
/// scattered star. Gold on the days the rhythm is kept (see
/// `habit_stats.dart`), dark blue the moment it breaks.
///
/// A pulsar works in **cycles**: the user picks a [cycleLength] (a number of
/// distinct days of doing it) and an [intensity] — the reward that cycle is
/// worth. Reaching the length earns the intensity once, like lighting a star
/// (see `HabitCycle`); how often or how fast the days come never matters,
/// only that they get there. [frequency] and [targetPerPeriod] are just the
/// rhythm the user would like — they never decide the pulsar's state or the
/// stats.
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
    DateTime? updatedAt,
    this.deleted = false,
    this.frequency = HabitFrequency.daily,
    this.targetPerPeriod = 1,
    this.intensity = 3,
    this.cycleLength = kDefaultCycleLength,
    this.cycleStart,
    this.reminderHour,
    this.reminderMinute,
    this.dead = false,
    this.deadDate,
  }) : updatedAt = updatedAt ?? createdAt,
       assert(
         intensity >= 1 && intensity <= 5,
         'intensity must be 1-5, was $intensity',
       ),
       assert(
         cycleLength >= kMinCycleLength && cycleLength <= kMaxCycleLength,
         'cycleLength must be $kMinCycleLength-$kMaxCycleLength, '
         'was $cycleLength',
       );

  final String id;
  final String projectId;
  final String title;

  /// An empty slug keeps the original activity icon for older records.
  final String iconSlug;
  final String? description;
  final DateTime createdAt;

  /// The last local write, falling back to creation time for legacy records.
  final DateTime updatedAt;

  /// Permanent sync deletion, distinct from archiving an activity.
  final bool deleted;

  /// When this habit was last edited, falling back to [createdAt].
  DateTime get lastModified => updatedAt;

  final HabitFrequency frequency;

  /// How many times [frequency]'s own period asks for — see
  /// [HabitFrequency]'s own doc comment for what that means per value.
  final int targetPerPeriod;

  /// What completing one cycle is worth, 1 (light) to 5 (a lot) — the same
  /// scale a [Star]'s own intensity uses, so "intensity" means one single
  /// thing across every kind of star. Unlike a victory (rated once it's
  /// lit), the user picks it up front: it is the prize they are working
  /// toward, and it is earned only when the cycle is completed.
  final int intensity;

  /// How many distinct days of doing this make up one cycle. Reaching it
  /// earns [intensity]; there is no deadline.
  final int cycleLength;

  /// First day that counts toward the current cycle. Null on a pulsar that
  /// never restarted its cycle: read it through [currentCycleStart].
  final DateTime? cycleStart;

  /// The day (midnight) the current cycle began, falling back to the day
  /// the pulsar was created.
  DateTime get currentCycleStart {
    final start = cycleStart ?? createdAt;
    return DateTime(start.year, start.month, start.day);
  }

  /// null = inherits the app's single global reminder time
  /// ([SettingsController]). Not yet acted on by [ReminderService] in v1 —
  /// see its own doc comment.
  final int? reminderHour;
  final int? reminderMinute;

  /// Archived: this pulsar stops counting
  /// as an active pulsar anywhere, and renders as a dead star instead.
  final bool dead;

  /// When [dead] became true. Null for a pulsar that's never been deleted;
  /// cleared on resurrection along with [dead] itself.
  final DateTime? deadDate;

  bool get isActive => !dead && !deleted;

  Habit copyWith({
    String? id,
    String? projectId,
    String? title,
    String? iconSlug,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    HabitFrequency? frequency,
    bool? deleted,
    int? targetPerPeriod,
    int? intensity,
    int? cycleLength,
    DateTime? cycleStart,
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
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      frequency: frequency ?? this.frequency,
      targetPerPeriod: targetPerPeriod ?? this.targetPerPeriod,
      intensity: intensity ?? this.intensity,
      cycleLength: cycleLength ?? this.cycleLength,
      cycleStart: cycleStart ?? this.cycleStart,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      dead: dead ?? this.dead,
      deadDate: deadDate ?? this.deadDate,
    );
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      deleted: json['deleted'] as bool? ?? false,
      projectId: json['projectId'] as String,
      title: json['title'] as String,
      iconSlug: json['iconSlug'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: switch (json['updatedAt'] as String?) {
        final value? => DateTime.parse(value),
        null => null,
      },
      frequency: HabitFrequency.values.byName(
        json['frequency'] as String? ?? 'daily',
      ),
      targetPerPeriod: json['targetPerPeriod'] as int? ?? 1,
      intensity: json['intensity'] as int? ?? 3,
      cycleLength: json['cycleLength'] as int? ?? kDefaultCycleLength,
      cycleStart: switch (json['cycleStart'] as String?) {
        final value? => DateTime.parse(value),
        null => null,
      },
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
      'deleted': deleted,
      'projectId': projectId,
      'title': title,
      'iconSlug': iconSlug,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'frequency': frequency.name,
      'targetPerPeriod': targetPerPeriod,
      'intensity': intensity,
      'cycleLength': cycleLength,
      'cycleStart': cycleStart?.toIso8601String(),
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
        other.deleted == deleted &&
        other.projectId == projectId &&
        other.title == title &&
        other.iconSlug == iconSlug &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.frequency == frequency &&
        other.targetPerPeriod == targetPerPeriod &&
        other.intensity == intensity &&
        other.cycleLength == cycleLength &&
        other.cycleStart == cycleStart &&
        other.reminderHour == reminderHour &&
        other.reminderMinute == reminderMinute &&
        other.dead == dead &&
        other.deadDate == deadDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    projectId,
    title,
    iconSlug,
    description,
    createdAt,
    updatedAt,
    frequency,
    targetPerPeriod,
    intensity,
    cycleLength,
    cycleStart,
    reminderHour,
    reminderMinute,
    dead,
    deadDate,
  );
}
