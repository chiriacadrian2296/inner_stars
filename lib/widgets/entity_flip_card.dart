import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../screens/entity_stats_screen.dart';
import '../screens/today_habits_screen.dart';
import '../theme/app_colors.dart';
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
  });
  final InsightEntity entity;
  final Widget front;
  final bool flipped;
  final VoidCallback onFlip;

  /// Vertical axis = Y rotation; horizontal axis = X rotation.
  final Axis axis;

  /// Tooltips limit the hold gesture to their body, above the action drawer.
  final double? holdHeight;

  @override
  Widget build(BuildContext context) {
    final controller = EntityInsightsScope.maybeOf(context);
    if (controller == null) return front;
    final data = controller.read(entity);
    final back = _InsightBack(data: data, onReturn: onFlip);
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
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: context.colors.nightPanel.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              child: IconButton(
                tooltip: context.strings.insightFlip,
                icon: Icon(Icons.flip, size: 18, color: context.colors.text),
                onPressed: onFlip,
              ),
            ),
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
  const _InsightBack({required this.data, required this.onReturn});
  final EntityInsights data;
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.nightPanel,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                    IconButton(
                      tooltip: context.strings.insightReturn,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.flip, size: 18),
                      onPressed: onReturn,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: EntityInsightMetrics(data: data, compact: true),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _BackAction(
                      icon: Icons.bar_chart,
                      label: context.strings.statsTitle,
                      showLabel: constraints.maxWidth > 300,
                      onTap: () => openEntityStatistics(context, data.entity),
                    ),
                  ),
                  if (data.entity.aggregate)
                    Expanded(
                      child: _BackAction(
                        icon: Icons.checklist_rounded,
                        label: context.strings.manageHabits,
                        showLabel: constraints.maxWidth > 300,
                        onTap: () => openTodayHabits(context, data.entity),
                      ),
                    ),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showLabel;
  @override
  Widget build(BuildContext context) => showLabel
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
