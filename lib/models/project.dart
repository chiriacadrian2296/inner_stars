import 'life_area.dart';

/// A user-created project within a [LifeArea] (e.g. "Build this app" under
/// Professional). Its [iconSlug] selects only the badge icon shown in
/// project lists — purely cosmetic, unrelated to its constellation. The
/// actual shape its wins light up stars in is the hand-drawn
/// [starsShapeId] (see `StarsShapeRepository`), which
/// every project is expected to have — `NewProjectScreen` requires picking
/// or drawing one before a project can be created. It's still nullable here
/// because pre-editor projects only get one lazily, via
/// `backfillMissingConstellations`.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.area,
    required this.iconSlug,
    this.starsShapeId,
    this.description,
    required this.createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String name;
  final LifeArea area;
  final String iconSlug;
  final String? starsShapeId;

  /// Optional, freeform — what this project is about. Never required,
  /// unlike [name].
  final String? description;
  final DateTime createdAt;

  /// The last local write, falling back to creation time for legacy records.
  final DateTime updatedAt;

  /// Permanent sync deletion, distinct from archiving an activity.
  final bool deleted;

  /// When this project was last edited, falling back to [createdAt].
  DateTime get lastModified => updatedAt;

  Project copyWith({
    String? id,
    String? name,
    LifeArea? area,
    String? iconSlug,
    String? starsShapeId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      iconSlug: iconSlug ?? this.iconSlug,
      starsShapeId: starsShapeId ?? this.starsShapeId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      deleted: json['deleted'] as bool? ?? false,
      name: json['name'] as String,
      area: LifeArea.values.byName(json['area'] as String),
      iconSlug: json['iconSlug'] as String,
      // Keep the persisted storage key compatible. The UUID migration remaps
      // its value before parsing without renaming the key.
      starsShapeId: json['customConstellationId'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: switch (json['updatedAt'] as String?) {
        final value? => DateTime.parse(value),
        null => null,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deleted': deleted,
      'name': name,
      'area': area.name,
      'iconSlug': iconSlug,
      // Same pre-rename key as fromJson reads — see its own comment.
      if (starsShapeId != null) 'customConstellationId': starsShapeId,
      if (description != null) 'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Project &&
        other.id == id &&
        other.deleted == deleted &&
        other.name == name &&
        other.area == area &&
        other.iconSlug == iconSlug &&
        other.starsShapeId == starsShapeId &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    name,
    area,
    iconSlug,
    starsShapeId,
    description,
    createdAt,
    updatedAt,
  );
}
