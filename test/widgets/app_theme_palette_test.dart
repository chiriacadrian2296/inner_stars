import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  test('all Material accent roles use the shared gold palette', () {
    final scheme = buildAppTheme().colorScheme;
    for (final color in [
      scheme.primary,
      scheme.primaryContainer,
      scheme.primaryFixed,
      scheme.primaryFixedDim,
      scheme.secondary,
      scheme.secondaryContainer,
      scheme.secondaryFixed,
      scheme.secondaryFixedDim,
      scheme.tertiary,
      scheme.tertiaryContainer,
      scheme.tertiaryFixed,
      scheme.tertiaryFixedDim,
    ]) {
      expect(color, AppColors.dark.gold);
    }
  });

  testWidgets('unstyled selected Material chips inherit gold with dark text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              ChoiceChip(
                label: const Text('Choice'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Filter'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in ['Choice', 'Filter']) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(RawChip),
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: chip, matching: find.byType(Ink)).first,
      );
      expect((ink.decoration as ShapeDecoration).color, AppColors.dark.gold);
      expect(
        DefaultTextStyle.of(tester.element(find.text(label))).style.color,
        AppColors.dark.onGold,
      );
    }
  });
}
