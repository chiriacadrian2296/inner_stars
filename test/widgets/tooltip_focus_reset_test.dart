import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/entity_insights.dart';
import 'package:inner_stars/widgets/entity_flip_card.dart';
import 'package:inner_stars/widgets/entity_insights_scope.dart';
import 'package:inner_stars/widgets/search_result_card.dart';
import 'package:inner_stars/widgets/sky_search_tooltip_card.dart';

void main() {
  testWidgets(
    'inactive tooltip selects first and resets drawer and flip on blur',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final insights = EntityInsightsController(
        projects: ProjectRepository(prefs),
        stars: StarRepository(prefs),
        habits: HabitRepository(prefs),
        completions: HabitCompletionRepository(prefs),
        shapes: StarsShapeRepository(prefs),
      );
      final focus = ValueNotifier<int?>(null);
      final menus = SearchCardMenuController();
      addTearDown(focus.dispose);
      addTearDown(menus.dispose);
      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: EntityInsightsScope(
            controller: insights,
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(
                body: ValueListenableBuilder<int?>(
                  valueListenable: focus,
                  builder: (context, selected, _) => Column(
                    children: [
                      for (final id in [1, 2])
                        SizedBox(
                          width: 360,
                          child: SkyTooltipMenuScope(
                            menuId: id,
                            controller: menus,
                            focused: selected == id,
                            onCardTap: () => focus.value = id,
                            child: SkySearchTooltipCard(
                              key: ValueKey('card-$id'),
                              menuId: id,
                              entity: InsightEntity.star(id.toString()),
                              baseBodyHeight: 118,
                              visual: const SizedBox.shrink(),
                              content: Text('Card $id'),
                              actions: [
                                SearchCardAction(
                                  icon: Icons.edit,
                                  label: 'Modifica',
                                  onTap: () {},
                                ),
                              ],
                              onTap: () => focus.value = id,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder control(int id, IconData icon) => find.descendant(
        of: find.byKey(ValueKey('card-$id')),
        matching: find.byIcon(icon),
      );
      Finder toggle(int id) => find.descendant(
        of: find.byKey(ValueKey('card-$id')),
        matching: find.byKey(const Key('search-card-quick-menu-toggle')),
      );
      bool flipped(int id) => tester
          .widget<EntityFlipCard>(
            find.descendant(
              of: find.byKey(ValueKey('card-$id')),
              matching: find.byType(EntityFlipCard),
            ),
          )
          .flipped;
      await tester.tapAt(tester.getCenter(toggle(1)));
      await tester.pumpAndSettle();
      expect(focus.value, 1);
      expect(menus.openId, isNull);
      await tester.tap(toggle(1));
      await tester.pumpAndSettle();
      expect(menus.openId, 1);
      Finder firstSurface() => find.descendant(
        of: find.byKey(const ValueKey('card-1')),
        matching: find.byKey(const Key('search-result-card-surface')),
      );
      focus.value = 2;
      await tester.pump();
      await tester
          .pump(); // Begin the close tween after the deferred controller reset.
      await tester.pump(const Duration(milliseconds: 100));
      final closingHeight = tester.getSize(firstSurface()).height;
      expect(closingHeight, greaterThan(118));
      expect(closingHeight, lessThan(168));
      await tester.pumpAndSettle();
      expect(tester.getSize(firstSurface()).height, 118);
      focus.value = 1;
      await tester.pumpAndSettle();
      await tester.tap(toggle(1));
      await tester.pumpAndSettle();
      await tester.tap(control(1, Icons.flip));
      await tester.pumpAndSettle();
      expect(flipped(1), isTrue);
      final flipTween = find
          .descendant(
            of: find.descendant(
              of: find.byKey(const ValueKey('card-1')),
              matching: find.byType(EntityFlipCard),
            ),
            matching: find.byType(TweenAnimationBuilder<double>),
          )
          .first;
      final flipState = tester.state(flipTween);
      await tester.tapAt(tester.getCenter(control(2, Icons.flip)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(identical(tester.state(flipTween), flipState), isTrue);
      final rotation = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.descendant(
                    of: find.byKey(const ValueKey('card-1')),
                    matching: find.byType(EntityFlipCard),
                  ),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      expect(rotation.entry(1, 1), greaterThan(0));
      expect(rotation.entry(1, 1), lessThan(1));
      await tester.pumpAndSettle();
      expect(focus.value, 2);
      expect(flipped(1), isFalse);
      expect(flipped(2), isFalse);
      expect(menus.openId, isNull);
      await tester.tap(control(2, Icons.flip));
      await tester.pumpAndSettle();
      expect(flipped(2), isTrue);
      focus.value = null;
      await tester.pumpAndSettle();
      expect(flipped(2), isFalse);
      focus.value = 1;
      await tester.pumpAndSettle();
      expect(flipped(1), isFalse);
      expect(menus.openId, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      insights.dispose();
    },
  );
}
