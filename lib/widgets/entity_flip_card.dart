import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../screens/entity_stats_screen.dart';
import '../screens/today_habits_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/entity_insights.dart';
import 'entity_insight_content.dart';
import 'entity_insights_scope.dart';

/// Presentation only: the repositories and summary never run in animation frames.
class EntityFlipCard extends StatelessWidget {
  const EntityFlipCard({
    super.key,
    required this.entity,
    required this.front,
    required this.flipped,
    required this.onFlip,
    this.axis = Axis.vertical,
    this.holdHeight,
    this.buttonStyle = FlipButtonStyle.grid,
  });
  final InsightEntity entity;
  final Widget front;
  final bool flipped;
  final VoidCallback onFlip;

  /// Vertical axis = Y rotation; horizontal axis = X rotation.
  final Axis axis;

  /// Tooltips limit the hold gesture to their body, above the action drawer.
  final double? holdHeight;

  /// Which category of card this is; the front and back share one button.
  final FlipButtonStyle buttonStyle;

  @override
  Widget build(BuildContext context) {
    final controller = EntityInsightsScope.maybeOf(context);
    if (controller == null) return front;
    final data = controller.read(entity);
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        data,
        buttonStyle == FlipButtonStyle.grid
            ? (constraints.maxWidth / _gridReferenceWidth).clamp(0.4, 4.0)
            : 1.0,
      ),
    );
  }

  Widget _build(BuildContext context, EntityInsights data, double scale) {
    final grid = buttonStyle == FlipButtonStyle.grid;
    Widget back = Stack(
      fit: StackFit.expand,
      children: [
        // A tap or a hold anywhere on the card (not on a button) turns it
        // back face up.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onFlip,
          onLongPress: onFlip,
          child: _InsightBack(
            data: data,
            styled: buttonStyle == FlipButtonStyle.grid,
          ),
        ),
        _FlipButton(
          style: buttonStyle,
          bodyHeight: holdHeight,
          tooltip: context.strings.insightReturn,
          onTap: onFlip,
        ),
      ],
    );
    // Grid cards lay the back out at the reference tile width and scale it,
    // like the front, so it follows the grid size.
    if (grid) back = _ScaledFill(scale: scale, child: back);
    final frontFace = GestureDetector(
      onLongPressStart: (details) {
        if (holdHeight == null || details.localPosition.dy < holdHeight!) {
          onFlip();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          front,
          _FlipButton(
            style: buttonStyle,
            bodyHeight: holdHeight,
            scale: scale,
            tooltip: context.strings.insightFlip,
            onTap: onFlip,
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: flipped ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        builder: (context, value, _) {
          final showBack = value >= 0.5;
          final angle = math.pi * value - (showBack ? math.pi : 0);
          final transform = Matrix4.identity()..setEntry(3, 2, 0.001);
          if (axis == Axis.vertical) {
            transform.rotateY(angle);
          } else {
            transform.rotateX(angle);
          }
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: IgnorePointer(
              ignoring: value > 0 && value < 1,
              child: showBack ? back : frontFace,
            ),
          );
        },
      ),
    );
  }
}

class _InsightBack extends StatelessWidget {
  const _InsightBack({required this.data, required this.styled});
  final EntityInsights data;

  /// Grid cards: the bottom actions match the flip button's style.
  final bool styled;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.nightPanel,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          // Grid cards use the same 12 all round as the card face.
          padding: styled
              ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
              : const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: insightTitle(context, data),
                        child: Text(
                          insightTitle(context, data),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1,
                            fontWeight: FontWeight.bold,
                            color: context.colors.text,
                          ),
                        ),
                      ),
                    ),
                    // Room for the flip button drawn over this corner.
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: _BarScroll(
                  child: EntityInsightMetrics(data: data, compact: true),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wrap(
                    styled,
                    _BackAction(
                      styled: styled,
                      icon: Icons.bar_chart,
                      label: context.strings.statsTitle,
                      showLabel: constraints.maxWidth > 300,
                      onTap: () => openEntityStatistics(context, data.entity),
                    ),
                  ),
                  if (data.entity.aggregate) ...[
                    if (styled) const SizedBox(width: 8),
                    _wrap(
                      styled,
                      _BackAction(
                        styled: styled,
                        icon: Icons.checklist_rounded,
                        label: context.strings.manageHabits,
                        showLabel: constraints.maxWidth > 300,
                        onTap: () => openTodayHabits(context, data.entity),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _BackAction extends StatelessWidget {
  const _BackAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.showLabel,
    this.styled = false,
  });
  final bool styled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showLabel;
  @override
  Widget build(BuildContext context) {
    if (!styled) return _plain(context);
    final colors = context.colors;
    // Round, icon only (the label is the tooltip), like the flip button.
    return Tooltip(
      message: label,
      child: Material(
        color: colors.night,
        shape: CircleBorder(
          side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 18, color: colors.muted),
          ),
        ),
      ),
    );
  }

  Widget _plain(BuildContext context) => showLabel
      ? TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 11)),
        )
      : IconButton(
          tooltip: label,
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.zero,
          onPressed: onTap,
          icon: Icon(icon, size: 20),
        );
}

/// The two categories of card with a flip button. Each uses one button for
/// both faces; the styles may diverge between categories.
enum FlipButtonStyle {
  /// Sky grid cards: a round gold button with a navy glyph.
  grid,

  /// Galaxy tooltips: half of the card's right edge, matching the drawer
  /// toggle below it.
  tooltip,
}

class _FlipButton extends StatelessWidget {
  const _FlipButton({
    this.scale = 1,
    required this.style,
    required this.bodyHeight,
    required this.tooltip,
    required this.onTap,
  });

  final double scale;
  final FlipButtonStyle style;

  /// The card body's height (tooltips only; the button takes its top half).
  final double? bodyHeight;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    switch (style) {
      case FlipButtonStyle.grid:
        return Positioned(
          top: 8 * scale,
          right: 8 * scale,
          child: Tooltip(
            message: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                width: 28 * scale,
                height: 28 * scale,
                decoration: BoxDecoration(
                  color: colors.night,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.nightBorder,
                    width: kBorderWidth,
                  ),
                ),
                child: Icon(Icons.flip, size: 16 * scale, color: colors.muted),
              ),
            ),
          ),
        );
      case FlipButtonStyle.tooltip:
        // A 28 circle (like the grid's) in the top-right of the card's upper
        // half, mirroring the drawer toggle in the lower half. The whole
        // half-height strip is its tap zone.
        final zone = (bodyHeight ?? 110) / 2;
        return Positioned(
          top: 0,
          right: 0,
          width: 48,
          height: zone,
          child: Tooltip(
            message: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.night,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.nightBorder,
                        width: kBorderWidth,
                      ),
                    ),
                    child: Icon(Icons.flip, size: 16, color: colors.muted),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// The back face's scrolling body with a visible scroll bar, coloured like
/// the buttons' background so it shows that there is more to scroll.
class _BarScroll extends StatefulWidget {
  const _BarScroll({required this.child});

  final Widget child;

  @override
  State<_BarScroll> createState() => _BarScrollState();
}

class _BarScrollState extends State<_BarScroll> {
  final _controller = ScrollController();

  // Shown for a moment when the back opens, so it is clear the body scrolls;
  // then it behaves like the stock scroll bars: hidden, back while scrolling.
  bool _pinned = true;
  Timer? _unpin;

  @override
  void initState() {
    super.initState();
    _unpin = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _pinned = false);
    });
  }

  @override
  void dispose() {
    _unpin?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RawScrollbar(
      controller: _controller,
      thumbVisibility: _pinned,
      thumbColor: colors.night,
      thickness: 5,
      radius: const Radius.circular(3),
      child: SingleChildScrollView(
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}

/// Grid cards keep their bottom buttons close together; tooltips spread them
/// across the row.
Widget _wrap(bool styled, Widget child) =>
    styled ? child : Expanded(child: child);

/// Width of a grid tile on the layout the back was tuned on (the Large size,
/// two cards a row on a phone): the back is drawn at this width and scaled.
const double _gridReferenceWidth = 154;

/// Lays [child] out at the reference size and scales it to fill its box.
class _ScaledFill extends StatelessWidget {
  const _ScaledFill({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: constraints.maxWidth / scale,
          maxWidth: constraints.maxWidth / scale,
          minHeight: constraints.maxHeight / scale,
          maxHeight: constraints.maxHeight / scale,
          child: child,
        ),
      ),
    ),
  );
}
