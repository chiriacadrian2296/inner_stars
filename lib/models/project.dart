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
  });

  final int id;
  final String name;
  final LifeArea area;
  final String iconSlug;
  final int? starsShapeId;

  /// Optional, freeform — what this project is about. Never required,
  /// unlike [name].
  final String? description;
  final DateTime createdAt;

  Project copyWith({
    int? id,
    String? name,
    LifeArea? area,
    String? iconSlug,
    int? starsShapeId,
    String? description,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      iconSlug: iconSlug ?? this.iconSlug,
      starsShapeId: starsShapeId ?? this.starsShapeId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String,
      area: LifeArea.values.byName(json['area'] as String),
      iconSlug: json['iconSlug'] as String,
      // Reads from the pre-rename storage key on purpose — every project
      // already saved on a device has this key, and there's no migration
      // step that runs before this parse, so changing it here would drop
      // every existing project's shape assignment on next launch.
      starsShapeId: json['customConstellationId'] as int?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area.name,
      'iconSlug': iconSlug,
      // Same pre-rename key as fromJson reads — see its own comment.
      if (starsShapeId != null) 'customConstellationId': starsShapeId,
      if (description != null) 'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Project &&
        other.id == id &&
        other.name == name &&
        other.area == area &&
        other.iconSlug == iconSlug &&
        other.starsShapeId == starsShapeId &&
        other.description == description &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    area,
    iconSlug,
    starsShapeId,
    description,
    createdAt,
  );
}
