import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_style.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/theme/app_typography.dart';
import 'package:inner_stars/widgets/app_choice_chip.dart';
import 'package:inner_stars/widgets/app_toggle_chip.dart';
import 'package:inner_stars/widgets/pill_action_button.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('action pills use intrinsic width and center their content', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SaveActionButton(
              key: const Key('save'),
              icon: Icons.check_rounded,
              label: 'Salva',
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            PillActionButton(
              key: const Key('delete'),
              icon: Icons.delete_outline,
              label: 'Elimina',
              danger: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final save = find.byKey(const Key('save'));
    final delete = find.byKey(const Key('delete'));
    expect(tester.getSize(save).height, 48);
    expect(tester.getSize(delete).height, 48);
    expect(tester.getSize(save).width, lessThan(196));
    expect(tester.getSize(delete).width, lessThan(196));
    expect(tester.getSize(save).width, isNot(tester.getSize(delete).width));

    void expectContentCentered(Finder button) {
      final iconRect = tester.getRect(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
      final textRect = tester.getRect(
        find.descendant(of: button, matching: find.byType(Text)),
      );
      final contentCenter = (iconRect.left + textRect.right) / 2;
      expect(contentCenter, closeTo(tester.getCenter(button).dx, 0.5));
    }

    expectContentCentered(save);
    expectContentCentered(delete);
  });

  testWidgets('disabled toggle keeps semantics and cannot change', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const AppToggleChip(label: 'Filtro', value: false, onChanged: null)),
    );
    expect(find.bySemanticsLabel('Filtro'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    await tester.tap(find.text('Filtro'));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('choice chip exposes selection and uses a 48px target', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => AppChoiceChip(
            label: 'Area',
            selected: selected,
            onPressed: () => setState(() => selected = !selected),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(AppChoiceChip),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      48,
    );
    expect(find.bySemanticsLabel('Area'), findsOneWidget);
    await tester.tap(find.byType(AppChoiceChip));
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('semantic typography follows the active palette', (tester) async {
    late AppTypography typography;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            typography = context.typography;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(typography.utilityPageTitle.color, AppColors.dark.text);
    expect(typography.compactSectionLabel.color, AppColors.dark.muted);
  });

  test('field state precedence covers error and disabled', () {
    expect(
      fieldStateOf(hasValue: true, focused: true, enabled: false),
      FieldState.disabled,
    );
    expect(
      fieldStateOf(hasValue: true, focused: true, hasError: true),
      FieldState.error,
    );
  });
}
