import 'package:flutter/material.dart';

import 'search_result_card.dart';

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
  });

  final Object menuId;
  final Widget visual;
  final Widget content;
  final List<SearchCardAction> actions;
  final VoidCallback onTap;

  /// Taller than the default when the content has a second row of badges.
  final double baseBodyHeight;

  @override
  State<SkySearchTooltipCard> createState() => _SkySearchTooltipCardState();
}

class _SkySearchTooltipCardState extends State<SkySearchTooltipCard> {
  final _menuController = SearchCardMenuController();

  @override
  void initState() {
    super.initState();
    _openDrawerAfterLayout();
  }

  @override
  void didUpdateWidget(covariant SkySearchTooltipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuId != widget.menuId) _openDrawerAfterLayout();
  }

  void _openDrawerAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menuController.open(widget.menuId);
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SearchResultCard(
        menuId: widget.menuId,
        menuController: _menuController,
        visual: widget.visual,
        content: widget.content,
        actions: widget.actions,
        onTap: widget.onTap,
        baseBodyHeight: widget.baseBodyHeight,
        // The tooltip's drawer stays open after an action: it's open for as
        // long as the tooltip is.
        preserveMenuOnAction: true,
      ),
    );
  }
}
