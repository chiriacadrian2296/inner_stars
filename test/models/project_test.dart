import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';

void main() {
  test('fromJson() on data saved before starsShapeId existed yields null, not a crash', () {
    final json = {
      'id': 1,
      'name': 'Build this app',
      'area': LifeArea.professional.name,
      'iconSlug': 'rocket_launch',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    };

    final project = Project.fromJson(json);

    expect(project.starsShapeId, isNull);
    expect(project.description, isNull);
  });

  test('fromJson/toJson round-trips a set description', () {
    final original = Project(
      id: 1,
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
      description: 'A personal-growth app for recording victories',
      createdAt: DateTime(2026, 1, 1),
    );

    final roundTripped = Project.fromJson(original.toJson());

    expect(roundTripped, original);
    expect(roundTripped.description, original.description);
  });

  test('fromJson/toJson round-trips a set starsShapeId', () {
    final original = Project(
      id: 1,
      name: 'Build this app',
      area: LifeArea.professional,
      iconSlug: 'rocket_launch',
      starsShapeId: 42,
      createdAt: DateTime(2026, 1, 1),
    );

    final roundTripped = Project.fromJson(original.toJson());

    expect(roundTripped, original);
    expect(roundTripped.starsShapeId, 42);
  });
}
