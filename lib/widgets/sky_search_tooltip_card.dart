import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../utils/entity_insights.dart';
import '../screens/entity_stats_screen.dart';
import '../l10n/strings_scope.dart';
import 'entity_flip_card.dart';
import 'entity_insights_scope.dart';

import 'search_result_card.dart';

/// Galaxy's outer tooltip width, including its 8 px frame on each side.
double galaxyTooltipWidth(BuildContext context) =>
    math.min(480, MediaQuery.sizeOf(context).width - 12);

const galaxyTooltipPadding = 8.0;

/// A map shares one drawer controller, but each card keeps its own identity.
class SkyTooltipMenuScope extends InheritedWidget {
  const SkyTooltipMenuScope({
    super.key,
    required this.controller,
    required this.menuId,
    this.showVisual = true,
    required super.child,
  });

  final SearchCardMenuController controller;
  final bool showVisual;
  final Object menuId;

  static SkyTooltipMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkyTooltipMenuScope>();

  @override
  bool updateShouldNotify(SkyTooltipMenuScope oldWidget) =>
      controller != oldWidget.controller ||
      menuId != oldWidget.menuId ||
      showVisual != oldWidget.showVisual;
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
  void didUpdateWidget(covariant SkySearchTooltipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuId != widget.menuId) {
      _flipped = false;
      _localMenuController.closeAll();
    }
  }

  @override
  void dispose() {
    _localMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SkyTooltipMenuScope.maybeOf(context);
    final menuController = scope?.controller ?? _localMenuController;
    final menuId = scope?.menuId ?? widget.menuId;
    final entity = widget.entity;
    final hasInsights =
        entity != null && EntityInsightsScope.maybeOf(context) != null;
    final actions = [...widget.actions];
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
        onTap: widget.onTap,
        baseBodyHeight: widget.baseBodyHeight,
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
        widget.baseBodyHeight + (textScale > 1 ? (textScale - 1) * 66 : 0) + 50;
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
        final frontHeight = drawerOpen ? openHeight : openHeight - 50;
        final height = (_flipped ? math.max(openHeight, 280.0) : frontHeight)
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
