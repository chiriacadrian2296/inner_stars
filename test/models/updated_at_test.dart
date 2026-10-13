import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';

void main() {
  test('a star stored without updatedAt falls back to createdAt', () {
    final star = Star.fromJson({
      'id': 1,
      'projectId': 1,
      'slotSequence': 1,
      'title': 'Old',
      'createdAt': '2026-01-02T10:00:00.000',
    });
    expect(star.updatedAt, isNull);
    expect(star.lastModified, DateTime.parse('2026-01-02T10:00:00.000'));
  });

  test('updatedAt round-trips through json', () {
    final star = Star(
      id: 1,
      projectId: 1,
      slotSequence: 1,
      title: 'New',
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 3, 4),
    );
    expect(Star.fromJson(star.toJson()).lastModified, DateTime(2026, 3, 4));
  });

  test('a project without updatedAt falls back to createdAt', () {
    final project = Project.fromJson({
      'id': 1,
      'name': 'P',
      'area': 'personal',
      'iconSlug': 'star',
      'createdAt': '2026-01-02T10:00:00.000',
    });
    expect(project.lastModified, project.createdAt);
  });
}
