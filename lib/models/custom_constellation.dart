import 'dart:ui';

import '../data/constellation_shape.dart';

/// One shape in the user's own list: either drawn by hand in
/// `StarsShapeEditorScreen`, or copied out of the ready-made library
/// (see `constellation_presets.dart`) when a project picked one. Saved
/// under its own name and reusable across projects.
///
/// Wraps a [ConstellationShape] rather than duplicating its `points`/`edges`
/// fields, so every existing consumer of that class (`buildConstellationLayout`,
/// `boundingBoxOf`, `ConstellationPainter`) accepts it unchanged.
///
/// Only ever has a [name] — no description. A shape is a reusable pattern
/// (the same one can be picked for more than one project), so "what it
/// means" belongs to whichever project is using it, not to the shape
/// itself — see `Project.description` for that.
class StarsShape {
  const StarsShape({
    required this.id,
    required this.name,
    required this.shape,
    required this.createdAt,
    this.presetId,
  });

  final int id;
  final String name;
  final ConstellationShape shape;
  final DateTime createdAt;

  /// The [StarsShapePreset.id] this was copied from, or null for a shape
  /// drawn by hand. Only a provenance tag — the points live here either way,
  /// so a preset that's later retired from the catalogue costs the tag and
  /// nothing else.
  ///
  /// Cleared the moment the user edits the shape (see
  /// [StarsShapeRepository.update]): once the points differ from
  /// the library's, calling it a copy of "Bicycle" would make the next
  /// person to pick Bicycle inherit someone else's edits.
  final String? presetId;

  factory StarsShape.fromJson(Map<String, dynamic> json) {
    return StarsShape(
      id: json['id'] as int,
      name: json['name'] as String,
      shape: ConstellationShape(
        points: (json['points'] as List<dynamic>)
            .map(
              (p) => Offset((p as List<dynamic>)[0] as double, p[1] as double),
            )
            .toList(),
        edges: (json['edges'] as List<dynamic>)
            .map((e) => ((e as List<dynamic>)[0] as int, e[1] as int))
            .toList(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      presetId: json['presetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'points': shape.points.map((p) => [p.dx, p.dy]).toList(),
      'edges': shape.edges.map((e) => [e.$1, e.$2]).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (presetId != null) 'presetId': presetId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! StarsShape) return false;
    if (other.id != id ||
        other.name != name ||
        other.createdAt != createdAt ||
        other.presetId != presetId ||
        other.shape.points.length != shape.points.length ||
        other.shape.edges.length != shape.edges.length) {
      return false;
    }
    for (var i = 0; i < shape.points.length; i++) {
      if (other.shape.points[i] != shape.points[i]) return false;
    }
    for (var i = 0; i < shape.edges.length; i++) {
      if (other.shape.edges[i] != shape.edges[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    presetId,
    Object.hashAll(shape.points),
    Object.hashAll(shape.edges),
  );
}
