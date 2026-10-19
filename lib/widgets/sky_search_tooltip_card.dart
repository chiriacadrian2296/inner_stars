import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../utils/entity_insights.dart';
import '../screens/light_screen.dart' show openEntityStatistics;
import '../screens/today_habits_screen.dart' show openTodayHabits;
import '../l10n/strings_scope.dart';
import 'entity_flip_card.dart';
import 'entity_insights_scope.dart';

import 'search_result_card.dart';

/// Outer width for the chosen frame, preserving the shared card's content width.
double galaxyTooltipWidth(
  BuildContext context, {
  double framePadding = galaxyTooltipPadding,
}) => math.min(464, MediaQuery.sizeOf(context).width - 28) + framePadding * 2;

const galaxyTooltipPadding = 3.0;

/// A map shares one drawer controller, but each card keeps its own identity.
class SkyTooltipMenuScope extends InheritedWidget {
  const SkyTooltipMenuScope({
    super.key,
    required this.controller,
    required this.menuId,
    this.showVisual = true,
    this.onCardTap,
    this.focused = true,
    this.onView,
    this.onFly,
    required super.child,
  });

  final SearchCardMenuController controller;
  final bool showVisual;
  final VoidCallback? onCardTap;
  final bool focused;
  final VoidCallback? onView;
  final VoidCallback? onFly;
  final Object menuId;

  static SkyTooltipMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkyTooltipMenuScope>();

  @override
  bool updateShouldNotify(SkyTooltipMenuScope oldWidget) =>
      controller != oldWidget.controller ||
      menuId != oldWidget.menuId ||
      onCardTap != oldWidget.onCardTap ||
      focused != oldWidget.focused ||
      onView != oldWidget.onView ||
      onFly != oldWidget.onFly ||
      showVisual != oldWidget.showVisual;
}

/// Galaxy tooltips below this open with their drawer closed while [closed]
/// is true — the "today" fly-through, which shows one star after another
/// and keeps each card compact.
class GalaxyTooltipStartsClosed extends InheritedWidget {
  const GalaxyTooltipStartsClosed({
    super.key,
    required this.closed,
    required super.child,
  });

  final bool closed;

  static bool of(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<GalaxyTooltipStartsClosed>()
          ?.closed ??
      false;

  @override
  bool updateShouldNotify(GalaxyTooltipStartsClosed oldWidget) =>
      closed != oldWidget.closed;
}

/// Adapts Sky's shared result card to the floating tooltip surface.
class SkySearchTooltipCard extends StatefulWidget {
  const SkySearchTooltipCard({
    super.key,
    required this.menuId,
    required this.visual,
    required this.content,
    required this.actions,
    required this.onTap,
    this.baseBodyHeight = SearchResultCard.defaultBodyHeight,
    this.fillVisualHeight = false,
    this.centerVisual = false,
    this.entity,
  });

  final Object menuId;
  final Widget visual;
  final Widget content;
  final List<SearchCardAction> actions;
  final VoidCallback onTap;

  /// Taller than the default when the content has a second row of badges.
  final double baseBodyHeight;

  /// The visual takes the card's whole height (see `SearchResultCard`).
  final bool fillVisualHeight;

  /// The visual is centred between the card's edge and the text.
  final bool centerVisual;
  final InsightEntity? entity;
  @override
  State<SkySearchTooltipCard> createState() => _SkySearchTooltipCardState();
}

class _SkySearchTooltipCardState extends State<SkySearchTooltipCard> {
  final _localMenuController = SearchCardMenuController();
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _openDrawerAfterLayout();
  }

  @override
  void didUpdateWidget(covariant SkySearchTooltipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuId != widget.menuId) {
      _flipped = false;
      _localMenuController.closeAll();
      _openDrawerAfterLayout();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SkyTooltipMenuScope.maybeOf(context);
    if (scope == null || scope.focused) return;
    _flipped = false;
    if (scope.controller.isOpen(scope.menuId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = SkyTooltipMenuScope.maybeOf(context);
        if (current != null &&
            !current.focused &&
            current.controller.isOpen(current.menuId)) {
          current.controller.closeAll();
        }
      });
    }
  }

  /// A Galaxy tooltip opens with its drawer open. Tooltips on a
  /// constellation's own map (which share one controller through
  /// [SkyTooltipMenuScope]) and the "today" fly-through's (see
  /// [GalaxyTooltipStartsClosed]) start closed.
  void _openDrawerAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          SkyTooltipMenuScope.maybeOf(context) != null ||
          GalaxyTooltipStartsClosed.of(context)) {
        return;
      }
      _localMenuController.open(widget.menuId);
    });
  }

  @override
  void dispose() {
    _localMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SkyTooltipMenuScope.maybeOf(context);
    final card = _buildCard(context);
    final inactive = scope?.focused == false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: inactive ? scope?.onCardTap ?? widget.onTap : null,
      child: AbsorbPointer(absorbing: inactive, child: card),
    );
  }

  Widget _buildCard(BuildContext context) {
    final scope = SkyTooltipMenuScope.maybeOf(context);
    final menuController = scope?.controller ?? _localMenuController;
    final menuId = scope?.menuId ?? widget.menuId;
    final bodyHeight =
        widget.baseBodyHeight + (scope?.showVisual == false ? 24 : 0);
    final entity = widget.entity;
    final hasInsights =
        entity != null && EntityInsightsScope.maybeOf(context) != null;
    final actions = [...widget.actions];
    if (scope?.onView != null) {
      actions.insert(
        0,
        SearchCardAction(
          icon: Icons.open_in_new_rounded,
          label: context.strings.starQuickLookViewAction,
          onTap: scope!.onView!,
          group: -1,
        ),
      );
    }
    if (scope?.onFly != null) {
      actions.add(
        SearchCardAction(
          icon: Icons.navigation,
          label: context.strings.actionFly,
          onTap: scope!.onFly!,
          group: 3,
        ),
      );
    }
    if (hasInsights && entity.aggregate) {
      // Right after "add", in its own group: the goals and habits of this
      // area or constellation.
      final afterAdd = actions.indexWhere((action) => action.group >= 1);
      actions.insert(
        afterAdd < 0 ? actions.length : afterAdd,
        SearchCardAction(
          icon: Icons.checklist_rounded,
          label: context.strings.manageActivities,
          onTap: () => openTodayHabits(context, entity),
        ),
      );
    }
    if (hasInsights) {
      final insertion = actions.indexWhere((action) => action.group >= 2);
      actions.insert(
        insertion < 0 ? actions.length : insertion,
        SearchCardAction(
          icon: Icons.bar_chart,
          label: context.strings.statsTitle,
          group: 2,
          onTap: () => openEntityStatistics(context, entity),
        ),
      );
    }
    final front = SizedBox(
      width: double.infinity,
      child: SearchResultCard(
        menuId: menuId,
        menuController: menuController,
        visual: widget.visual,
        showVisual: scope?.showVisual ?? true,
        content: widget.content,
        actions: actions,
        onTap: scope?.onCardTap ?? widget.onTap,
        baseBodyHeight: bodyHeight,
        fillVisualHeight: widget.fillVisualHeight,
        centerVisual: widget.centerVisual,
        // Keep an explicitly opened drawer open after an action.
        preserveMenuOnAction: true,
        groupSeparators: false,
        toggleAtBottom: true,
      ),
    );
    if (entity == null || EntityInsightsScope.maybeOf(context) == null) {
      return front;
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final openHeight =
        bodyHeight + (textScale > 1 ? (textScale - 1) * 66 : 0) + 50;
    final maxHeight = math.max(
      100.0,
      MediaQuery.sizeOf(context).height -
          MediaQuery.paddingOf(context).vertical -
          48,
    );
    // The 50 below the body is the drawer: counted only while it is open, so
    // a closed drawer leaves no empty (and shadowed) strip under the card.
    return AnimatedBuilder(
      animation: menuController,
      builder: (context, _) {
        final drawerOpen = menuController.isOpen(menuId);
        // The back keeps the front's height (its body scrolls), so turning a
        // tooltip over never makes it grow or jump above its anchor.
        final height = (drawerOpen ? openHeight : openHeight - 50)
            .clamp(0.0, maxHeight)
            .toDouble();
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
          height: height,
          child: EntityFlipCard(
            key: ValueKey(widget.menuId),
            entity: entity,
            front: front,
            flipped: _flipped,
            axis: Axis.horizontal,
            holdHeight: openHeight - 50,
            buttonStyle: FlipButtonStyle.tooltip,
            onFlip: () => setState(() => _flipped = !_flipped),
          ),
        );
      },
    );
  }
}
