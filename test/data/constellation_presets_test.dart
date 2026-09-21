import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_presets.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/utils/icon_for_slug.dart';

/// Guards the two halves of the shape catalogue against drifting apart:
/// `constellation_presets.dart` (100 shapes) and `icon_for_slug.dart` (100
/// badge icons, one per shape). Everything here is checkable without pumping
/// a widget, so it stays a plain data test.
void main() {
  test('there are 100 presets, with unique ids', () {
    expect(starsShapePresets, hasLength(100));
    expect(
      starsShapePresets.map((p) => p.id).toSet(),
      hasLength(starsShapePresets.length),
    );
  });

  test('every preset pairs with its own icon, and every icon is used once', () {
    final slugs = starsShapePresets.map((p) => p.iconSlug).toList();
    expect(slugs.toSet(), hasLength(slugs.length), reason: 'no shared icons');
    expect(slugs.toSet(), availableIconSlugs);
  });

  test('no preset icon collides with a reserved area icon', () {
    final areaSlugs = LifeArea.values.map((a) => a.iconSlug).toSet();
    expect(availableIconSlugs.intersection(areaSlugs), isEmpty);
  });

  test('every category has presets, and every preset has a name in all three languages', () {
    for (final category in PresetCategory.values) {
      expect(presetsIn(category), isNotEmpty, reason: category.name.en);
      for (final code in ['en', 'it', 'ro']) {
        expect(category.name.of(code), isNotEmpty);
      }
    }
    for (final preset in starsShapePresets) {
      for (final code in ['en', 'it', 'ro']) {
        expect(preset.name.of(code), isNotEmpty, reason: preset.id);
      }
    }
  });

  test('every shape is drawable: on-grid points, valid edges, nothing stranded', () {
    for (final preset in starsShapePresets) {
      final reason = preset.id;
      expect(preset.grid.length, greaterThanOrEqualTo(2), reason: reason);
      // The editor's own soft cap (`_maxEditorPoints`) — a preset the user
      // couldn't have drawn by hand would be a shape they can't then edit.
      expect(preset.grid.length, lessThanOrEqualTo(25), reason: reason);
      expect(preset.grid.toSet(), hasLength(preset.grid.length), reason: reason);

      for (final (x, y) in preset.grid) {
        expect(x, inInclusiveRange(0, 10), reason: reason);
        expect(y, inInclusiveRange(0, 10), reason: reason);
      }

      final wired = <int>{};
      for (final (a, b) in preset.edges) {
        expect(a, isNot(b), reason: reason);
        expect(a, inInclusiveRange(0, preset.grid.length - 1), reason: reason);
        expect(b, inInclusiveRange(0, preset.grid.length - 1), reason: reason);
        wired..add(a)..add(b);
      }
      expect(
        wired.length,
        preset.grid.length,
        reason: '$reason has a star on no edge',
      );
    }
  });

  test('shapes normalize into the 0..1 box, keeping their point order', () {
    for (final preset in starsShapePresets) {
      final shape = preset.shape;
      expect(shape.points, hasLength(preset.grid.length), reason: preset.id);
      expect(shape.edges, preset.edges, reason: preset.id);
      for (final p in shape.points) {
        expect(p.dx, inInclusiveRange(0, 1), reason: preset.id);
        expect(p.dy, inInclusiveRange(0, 1), reason: preset.id);
      }
    }
  });

  test('presetById and presetForIconSlug resolve back to the same preset', () {
    for (final preset in starsShapePresets) {
      expect(presetById(preset.id), same(preset));
      expect(presetForIconSlug(preset.iconSlug), same(preset));
    }
    expect(presetById(null), isNull);
    expect(presetById('nothing-like-this'), isNull);
    // An unknown slug still has to produce a shape — that's the whole point
    // of the fallback — and always the same one.
    expect(
      presetForIconSlug('retired_slug'),
      same(presetForIconSlug('retired_slug')),
    );
  });

  test('every suggested icon exists, and suggestions cover every area', () {
    for (final area in LifeArea.values) {
      final suggested = suggestedIconsByArea[area.suggestedIconsKey];
      expect(suggested, isNotNull, reason: area.name);
      expect(suggested, isNotEmpty, reason: area.name);
      for (final slug in suggested!) {
        expect(availableIconSlugs, contains(slug), reason: '$slug (${area.name})');
      }
    }
  });
}
