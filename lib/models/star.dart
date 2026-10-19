import 'package:flutter/foundation.dart' show listEquals;

import 'star_kind.dart';
import 'star_media.dart';

/// A single star on a constellation's shape: one *effort*, either still
/// ahead of you (unlit — a goal) or already made (lit — a victory). The same
/// underlying thing either way, told apart only by whether [achievedDate] is
/// set. See [StarKind] for how these two sit alongside the other three kinds
/// (nascent, pulsar, dead).
///
/// [slotSequence] is assigned once at creation, per project, and never
/// changes afterwards (not even when the star is edited, achieved, or
/// deleted) — it's the only thing that decides where this star sits in the
/// constellation. [number] is a separate, permanent "this is your Nth
/// victory" label, assigned the first time [achievedDate] becomes non-null
/// and cleared if it ever goes back to null (see [StarRepository]).
///
/// Deleting a star never removes its record: [dead] is set instead, so its
/// slot stays occupied forever and no other star in the project ever shifts
/// position. A dead star can later be resurrected — its content replaced by
/// a new title/description/etc. via [StarRepository.resurrect], reusing the
/// same [id] and [slotSequence].
class Star {
  const Star({
    required this.id,
    required this.projectId,
    required this.slotSequence,
    this.number,
    required this.title,
    this.iconSlug = '',
    this.description,
    required this.createdAt,
    DateTime? updatedAt,
    this.deleted = false,
    this.targetDate,
    this.achievedDate,
    this.intensity,
    this.photoPath,
    this.media = const [],
    this.dead = false,
    this.deadDate,
  }) : updatedAt = updatedAt ?? createdAt,
       assert(
         intensity == null || (intensity >= 1 && intensity <= 5),
         'intensity must be 1-5, was $intensity',
       ),
       assert(
         achievedDate == null || intensity != null,
         'intensity is required once achievedDate is set',
       );

  final String id;
  final String projectId;
  final int slotSequence;
  final int? number;
  final String title;

  /// An empty slug keeps the original activity icon for older records.
  final String iconSlug;
  final String? description;
  final DateTime createdAt;

  /// The last local write, falling back to creation time for legacy records.
  final DateTime updatedAt;

  /// Permanent sync deletion, distinct from archiving an activity.
  final bool deleted;

  /// When this star was last edited, falling back to [createdAt].
  DateTime get lastModified => updatedAt;

  /// Optional, aspirational only — set while the star is still unlit.
  /// Never affects [slotSequence], and isn't cleared once lit (it can still
  /// answer "you set this for X, reached it on Y").
  final DateTime? targetDate;

  /// When this star was lit. null = still unlit (a goal, an effort not yet
  /// made); non-null = lit (a victory, made on this date).
  final DateTime? achievedDate;

  /// The intensity of the effort this star stands for, 1 (light) to 5 (a
  /// lot) — the same scale every other kind of star uses. Required once
  /// [achievedDate] is set, null otherwise: an unlit star's real cost isn't
  /// knowable until it's actually been lit.
  final int? intensity;

  final String? photoPath;

  /// Optional extras on a victory (voice notes, secondary photos, videos,
  /// links), on top of the cover [photoPath]. Empty for anything not lit.
  final List<StarMedia> media;

  /// Archived: its slot is kept
  /// forever, but it stops counting as lit or unlit anywhere. What it can
  /// be reignited as is decided by what it was: a star here, a pulsar in
  /// [Habit].
  final bool dead;

  /// When [dead] became true. Null for a star that's never been deleted;
  /// cleared on resurrection along with [dead] itself, since a resurrected
  /// star isn't dead anymore and shouldn't remember when it last was.
  final DateTime? deadDate;

  /// Lit — a victory, an effort already made.
  bool get isLit => achievedDate != null && !dead && !deleted;

  /// How many extras of [kind] this star carries.
  int mediaCount(StarMediaKind kind) =>
      media.where((item) => item.kind == kind).length;

  /// Unlit — a goal, an effort still ahead.
  bool get isUnlit => achievedDate == null && !dead && !deleted;

  /// Which of the five families this star currently belongs to. Never
  /// [StarKind.nascent] (that's a slot with no star in it yet) and never
  /// [StarKind.pulsar] (that's a [Habit]) — the single place the
  /// dead/lit/unlit decision is made, so no screen re-derives it by hand.
  StarKind get kind =>
      dead ? StarKind.dead : (isLit ? StarKind.lit : StarKind.unlit);

  /// The activity type retained when the star is archived.
  StarKind get originalKind =>
      achievedDate != null ? StarKind.lit : StarKind.unlit;

  Star copyWith({
    String? id,
    String? projectId,
    int? slotSequence,
    int? number,
    String? title,
    String? iconSlug,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    DateTime? targetDate,
    DateTime? achievedDate,
    int? intensity,
    String? photoPath,
    List<StarMedia>? media,
    bool? dead,
    DateTime? deadDate,
  }) {
    return Star(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      slotSequence: slotSequence ?? this.slotSequence,
      number: number ?? this.number,
      title: title ?? this.title,
      iconSlug: iconSlug ?? this.iconSlug,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      targetDate: targetDate ?? this.targetDate,
      achievedDate: achievedDate ?? this.achievedDate,
      intensity: intensity ?? this.intensity,
      photoPath: photoPath ?? this.photoPath,
      media: media ?? this.media,
      dead: dead ?? this.dead,
      deadDate: deadDate ?? this.deadDate,
    );
  }

  factory Star.fromJson(Map<String, dynamic> json) {
    return Star(
      id: json['id'] as String,
      deleted: json['deleted'] as bool? ?? false,
      projectId: json['projectId'] as String,
      slotSequence: json['slotSequence'] as int,
      number: json['number'] as int?,
      title: json['title'] as String,
      iconSlug: json['iconSlug'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] as String?).let(DateTime.parse),
      targetDate: (json['targetDate'] as String?).let(DateTime.parse),
      achievedDate: (json['achievedDate'] as String?).let(DateTime.parse),
      intensity: json['intensity'] as int?,
      photoPath: json['photoPath'] as String?,
      media: [
        for (final m in (json['media'] as List?) ?? const [])
          ?StarMedia.tryFromJson(Map<String, dynamic>.from(m as Map)),
      ],
      dead: json['dead'] as bool? ?? false,
      deadDate: (json['deadDate'] as String?).let(DateTime.parse),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deleted': deleted,
      'projectId': projectId,
      'slotSequence': slotSequence,
      'number': number,
      'title': title,
      'iconSlug': iconSlug,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'achievedDate': achievedDate?.toIso8601String(),
      'intensity': intensity,
      'photoPath': photoPath,
      'media': [for (final m in media) m.toJson()],
      'dead': dead,
      'deadDate': deadDate?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Star &&
        other.id == id &&
        other.deleted == deleted &&
        other.projectId == projectId &&
        other.slotSequence == slotSequence &&
        other.number == number &&
        other.title == title &&
        other.iconSlug == iconSlug &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.targetDate == targetDate &&
        other.achievedDate == achievedDate &&
        other.intensity == intensity &&
        other.photoPath == photoPath &&
        listEquals(other.media, media) &&
        other.dead == dead &&
        other.deadDate == deadDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    projectId,
    slotSequence,
    number,
    title,
    iconSlug,
    description,
    createdAt,
    updatedAt,
    targetDate,
    achievedDate,
    intensity,
    photoPath,
    Object.hashAll(media),
    dead,
    deadDate,
  );
}

/// Small null-safe pipe so [Star.fromJson] can parse an optional ISO string
/// in one expression instead of a local variable + if-null check per field.
extension _NullableLet on String? {
  T? let<T>(T Function(String) f) {
    final value = this;
    return value == null ? null : f(value);
  }
}
