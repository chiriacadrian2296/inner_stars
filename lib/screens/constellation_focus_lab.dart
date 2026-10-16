import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/search_result_card.dart';
import '../widgets/sky_search_tooltip_card.dart';
import '../widgets/star_glyph.dart';
import '../models/star_kind.dart';

/// A lab-only atlas: the shape and one shared Galaxy card have separate space.
class ConstellationFocusLab extends StatefulWidget {
  const ConstellationFocusLab({
    super.key,
    required this.stars,
    required this.edges,
    required this.cardBuilder,
  });

  final List<ConstellationStar> stars;
  final List<(int, int)> edges;
  final Widget Function(BuildContext, ConstellationStar) cardBuilder;

  @override
  State<ConstellationFocusLab> createState() => _ConstellationFocusLabState();
}

class _ConstellationFocusLabState extends State<ConstellationFocusLab> {
  int _selected = 0;
  final _menus = SearchCardMenuController();

  void _select(int index) {
    _menus.closeAll();
    setState(() => _selected = index);
  }

  @override
  void dispose() {
    _menus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stars.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final star = widget.stars[_selected];
    // Graph edges address the slot-ordered stars, excluding orbiting habits.
    final slots = widget.stars.where((s) => s.slotSequence != null).toList()
      ..sort((a, b) => a.slotSequence!.compareTo(b.slotSequence!));
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final xs = widget.stars.map((s) => s.position.dx);
              final ys = widget.stars.map((s) => s.position.dy);
              final bounds = Rect.fromLTRB(
                xs.reduce(math.min),
                ys.reduce(math.min),
                xs.reduce(math.max),
                ys.reduce(math.max),
              );
              final scale = math.min(
                math.max(1, constraints.maxWidth - 88) /
                    math.max(0.01, bounds.width),
                math.max(1, constraints.maxHeight - 64) /
                    math.max(0.01, bounds.height),
              );
              Offset point(ConstellationStar s) =>
                  (s.position - bounds.center) * scale +
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
              final points = widget.stars.map(point).toList();
              final hitSizes = [
                for (var i = 0; i < points.length; i++)
                  math.min(
                    48.0,
                    [
                      for (var j = 0; j < points.length; j++)
                        if (i != j) (points[i] - points[j]).distance * 0.9,
                      48.0,
                    ].reduce(math.min),
                  ),
              ];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _AtlasLines([
                          for (final (a, b) in widget.edges)
                            if (a < slots.length && b < slots.length)
                              (
                                point(slots[a]),
                                point(slots[b]),
                                identical(slots[a], star) ||
                                    identical(slots[b], star),
                              ),
                        ]),
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.stars.length; i++)
                    Positioned(
                      left: points[i].dx - hitSizes[i] / 2,
                      top: points[i].dy - hitSizes[i] / 2,
                      width: hitSizes[i],
                      height: hitSizes[i],
                      child: Semantics(
                        selected: i == _selected,
                        button: true,
                        label: widget.stars[i].label.isEmpty
                            ? 'Opportunità'
                            : widget.stars[i].label,
                        child: GestureDetector(
                          key: ValueKey('atlas-node-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(i),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: math.min(
                                i == _selected ? 36.0 : 26.0,
                                hitSizes[i] * 0.8,
                              ),
                              height: math.min(
                                i == _selected ? 36.0 : 26.0,
                                hitSizes[i] * 0.8,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.night,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: i == _selected ? 1 : 0.4,
                                  ),
                                  width: i == _selected ? 1.5 : 0.7,
                                ),
                                boxShadow: i == _selected
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 18,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                widget.stars[i].kind.icon,
                                size: math.min(
                                  i == _selected ? 21.0 : 16.0,
                                  hitSizes[i] * 0.55,
                                ),
                                color: starKindColor(
                                  widget.stars[i].kind,
                                  colors,
                                  lit: widget.stars[i].lit,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Precedente',
              onPressed: () => _select(
                (_selected - 1 + widget.stars.length) % widget.stars.length,
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_selected + 1} / ${widget.stars.length}',
              style: TextStyle(color: colors.muted),
            ),
            IconButton(
              tooltip: 'Successiva',
              onPressed: () => _select((_selected + 1) % widget.stars.length),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Flexible(
          flex: 0,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 464),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.night,
                      borderRadius: BorderRadius.circular(kRadiusCard + 3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: SkyTooltipMenuScope(
                        controller: _menus,
                        menuId: (star.entityId, star.slotSequence),
                        showVisual: false,
                        child: widget.cardBuilder(context, star),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AtlasLines extends CustomPainter {
  const _AtlasLines(this.segments);
  final List<(Offset, Offset, bool)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, selected) in segments) {
      if (selected) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = 1.2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Colors.white.withValues(alpha: selected ? 0.85 : 0.28)
          ..strokeWidth = selected ? 1.2 : 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_AtlasLines oldDelegate) =>
      oldDelegate.segments != segments;
}
