import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../screens/light_screen.dart' show openEntityStatistics;
import '../screens/today_habits_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/entity_insights.dart';
import 'entity_insight_content.dart';
import 'entity_insights_scope.dart';

/// The two categories of card with a flip button. Each uses one button for
/// both faces; the styles may diverge between categories.
enum FlipButtonStyle {
  /// Sky grid cards: a small round button, scaled with the card.
  grid,

  /// Galaxy tooltips: half of the card's right edge, matching the drawer
  /// toggle below it.
  tooltip,
}

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
    final grid = buttonStyle == FlipButtonStyle.grid;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grid cards are drawn at the reference tile width and scaled, like
        // their front, so the flip button and the back follow the grid size.
        final scale = grid
            ? (constraints.maxWidth / _gridReferenceWidth).clamp(0.4, 4.0)
            : 1.0;
        Widget back = Stack(
          fit: StackFit.expand,
          children: [
            // A tap or a hold anywhere on the card (not on a button) turns it
            // back face up.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onFlip,
              onLongPress: onFlip,
              child: _InsightBack(data: data, grid: grid),
            ),
            _FlipButton(
              style: buttonStyle,
              bodyHeight: holdHeight,
              tooltip: context.strings.insightReturn,
              onTap: onFlip,
            ),
          ],
        );
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
      },
    );
  }
}

class _InsightBack extends StatelessWidget {
  const _InsightBack({required this.data, required this.grid});
  final EntityInsights data;

  /// Grid cards: padded like the card face, with small round actions grouped
  /// at the bottom. Tooltips use labelled pills with the flip button's colours.
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final actions = [
      (
        icon: Icons.bar_chart,
        label: strings.statsTitle,
        onTap: () => openEntityStatistics(context, data.entity),
      ),
      if (data.entity.aggregate)
        (
          icon: Icons.checklist_rounded,
          label: strings.manageHabits,
          onTap: () => openTodayHabits(context, data.entity),
        ),
    ];
    return Material(
      color: colors.nightPanel,
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: grid
              ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
              : const EdgeInsets.fromLTRB(12, 0, 12, 6),
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
                            fontSize: grid ? 12 : 13,
                            height: 1,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
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
                  child: EntityInsightMetrics(
                    data: data,
                    compact: true,
                    tooltip: !grid,
                  ),
                ),
              ),
              // As much space above the buttons as below them.
              if (grid) const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    if (grid)
                      _RoundAction(
                        icon: actions[i].icon,
                        label: actions[i].label,
                        onTap: actions[i].onTap,
                      )
                    else
                      Expanded(
                        child: _TooltipAction(
                          icon: actions[i].icon,
                          label: actions[i].label,
                          onTap: actions[i].onTap,
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid card's action: round and icon only (the label is the tooltip), the
/// size of the flip button.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
            width: 24,
            height: 24,
            child: Icon(icon, size: 14, color: colors.muted),
          ),
        ),
      ),
    );
  }
}

/// A labelled counterpart to the tooltip's round flip button.
class _TooltipAction extends StatelessWidget {
  const _TooltipAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.muted,
        backgroundColor: colors.night,
        side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

/// The flip button, shared by both faces of a card.
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
    Widget circle(double size, double iconSize) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.night,
        shape: BoxShape.circle,
        border: Border.all(color: colors.nightBorder, width: kBorderWidth),
      ),
      child: Icon(Icons.flip, size: iconSize, color: colors.muted),
    );
    // An InkWell (not a bare GestureDetector) so the button can take keyboard
    // focus and be activated with Enter or Space.
    Widget tappable(Widget child) => Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: child,
        ),
      ),
    );
    if (style == FlipButtonStyle.grid) {
      return Positioned(
        top: 8 * scale,
        right: 8 * scale,
        child: tappable(circle(24 * scale, 14 * scale)),
      );
    }
    // A 28 circle in the top-right of the card's upper half, mirroring the
    // drawer toggle in the lower half. The whole half-height strip is its
    // tap zone.
    return Positioned(
      top: 0,
      right: 0,
      width: 48,
      height: (bodyHeight ?? 110) / 2,
      child: tappable(
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: circle(28, 16),
          ),
        ),
      ),
    );
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
        // Keep the thumb in its own gutter, outside the summary badges.
        padding: const EdgeInsets.only(right: 9),
        child: widget.child,
      ),
    );
  }
}

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
