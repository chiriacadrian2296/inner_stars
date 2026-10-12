import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/action_group_dot.dart';
import 'package:inner_stars/widgets/grouped_action_layout.dart';
import 'package:inner_stars/widgets/reader_action_bar.dart';
import 'package:inner_stars/widgets/reader_entry_content.dart';

void main() {
  testWidgets('reader bar puts one dot between each pair of groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ReaderActionBar(
            entrance: const ReaderEntrance(
              animate: false,
              axis: Axis.vertical,
              reverse: false,
              lead: 0,
            ),
            actions: [
              ReaderAction(icon: Icons.bolt, label: 'a', onTap: () {}),
              ReaderAction(
                icon: Icons.share,
                label: 'b',
                onTap: () {},
                group: 1,
              ),
              ReaderAction(
                icon: Icons.edit,
                label: 'c',
                onTap: () {},
                group: 2,
              ),
              ReaderAction(
                icon: Icons.delete,
                label: 'd',
                onTap: () {},
                group: 2,
              ),
            ],
          ),
        ),
      ),
    );
    final layout = tester.renderObject<RenderGroupedActions>(
      find.byType(GroupedActionLayout),
    );
    expect(layout.separators, hasLength(2));
    expect(
      layout.separators.every((dot) => dot.size == const Size(4, 4)),
      isTrue,
    );
    expect(find.byType(ActionGroupDot), findsNWidgets(2));
  });

  testWidgets('dot lays out at the full dock gap and at a Wrap extra', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(children: [ActionGroupDot(), ActionGroupDot(width: 2)]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ActionGroupDot).first).width, 18);
  });

  testWidgets('dots fade in after the buttons without drifting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ReaderActionBar(
            entrance: const ReaderEntrance(
              animate: true,
              axis: Axis.vertical,
              reverse: false,
              lead: 0,
            ),
            actions: [
              ReaderAction(
                icon: Icons.share,
                label: 'Share',
                group: 1,
                onTap: () {},
              ),
              ReaderAction(
                icon: Icons.edit,
                label: 'Edit',
                group: 2,
                onTap: () {},
              ),
              ReaderAction(
                icon: Icons.navigation,
                label: 'Fly',
                group: 3,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final dotFade = find
        .ancestor(
          of: find.byType(ActionGroupDot).first,
          matching: find.byType(FadeTransition),
        )
        .first;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<FadeTransition>(dotFade).opacity.value, 0);
    final buttonFade = find
        .ancestor(
          of: find.byType(ReaderActionButton).first,
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(
      tester.widget<FadeTransition>(buttonFade).opacity.value,
      greaterThan(0),
    );
    final dotSlide = find
        .ancestor(
          of: find.byType(ActionGroupDot).first,
          matching: find.byType(SlideTransition),
        )
        .first;
    expect(
      tester.widget<SlideTransition>(dotSlide).position.value,
      Offset.zero,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(dotFade).opacity.value, 1);
  });
}
