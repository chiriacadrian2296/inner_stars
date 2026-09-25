import 'package:flutter/material.dart';

import '../data/constellation_shape.dart';
import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_style.dart';
import 'constellation_editor_painter.dart';
import 'star_glyph.dart';

class SearchCardMenuController extends ChangeNotifier {
  Object? _openId;

  bool isOpen(Object id) => _openId == id;

  void toggle(Object id) {
    _openId = _openId == id ? null : id;
    notifyListeners();
  }

  void closeAll() {
    if (_openId == null) return;
    _openId = null;
    notifyListeners();
  }
}

class SearchCardAction {
  const SearchCardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.menuId,
    required this.menuController,
    required this.visual,
    required this.content,
    required this.actions,
    required this.onTap,
  });

  static const visualSize = 88.0;
  static const _bodyHeight = 88.0;
  static const _drawerHeight = 68.0;
  static const _drawerUnderlap = 18.0;
  static const _toggleZoneWidth = 44.0;

  final Object menuId;
  final SearchCardMenuController menuController;
  final Widget visual;
  final Widget content;
  final List<SearchCardAction> actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final bodyHeight = textScale <= 1
        ? _bodyHeight
        : _bodyHeight + (textScale - 1) * 58;
    const drawerReveal = _drawerHeight - _drawerUnderlap;
    double ease(double t) => Curves.easeOutCubic.transform(t);

    return AnimatedBuilder(
      animation: menuController,
      builder: (context, _) {
        final isMenuOpen = menuController.isOpen(menuId);
        return TweenAnimationBuilder<double>(
          tween: Tween(end: isMenuOpen ? 1 : 0),
          duration: motionDuration(context, const Duration(milliseconds: 300)),
          // [progress] stays linear: the drawer eases itself out below, while
          // the quick-choice buttons cascade across the raw value.
          builder: (context, progress, _) => SizedBox(
            key: const Key('search-result-card-surface'),
            height: bodyHeight + drawerReveal * ease(progress),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: bodyHeight - _drawerUnderlap,
                  height: _drawerHeight,
                  child: Transform.translate(
                    offset: Offset(0, -drawerReveal * (1 - ease(progress))),
                    child: Opacity(
                      opacity: ease(progress),
                      child: _SearchQuickMenu(
                        actions: actions,
                        onActionSelected: menuController.closeAll,
                        progress: progress,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: bodyHeight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        menuController.closeAll();
                        onTap();
                      },
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      child: Ink(
                        key: const Key('search-result-card-body'),
                        decoration: BoxDecoration(
                          color: colors.nightPanel,
                          borderRadius: BorderRadius.circular(kRadiusCard),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(kRadiusCard),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                width: visualSize,
                                height: visualSize,
                                child: visual,
                              ),
                              Positioned(
                                left: visualSize,
                                top: 0,
                                right: 0,
                                height: bodyHeight,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    3,
                                    40,
                                    3,
                                  ),
                                  child: content,
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        kRadiusCard,
                                      ),
                                      border: Border.all(
                                        color: colors.nightBorder,
                                        width: kBorderWidth,
                                      ),
                                    ),
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
                // The toggle is small by design, so its tap zone is the whole
                // right-hand strip of the card, full body height.
                Positioned(
                  right: 0,
                  top: 0,
                  width: _toggleZoneWidth,
                  height: bodyHeight,
                  child: GestureDetector(
                    key: const Key('search-card-quick-menu-toggle-zone'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => menuController.toggle(menuId),
                    child: Center(
                      child: _SearchQuickMenuToggle(
                        isOpen: isMenuOpen,
                        onTap: () => menuController.toggle(menuId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SearchCardTextContent extends StatelessWidget {
  const SearchCardTextContent({
    super.key,
    required this.title,
    required this.primary,
    this.eyebrow,
    this.eyebrowColor,
    this.breadcrumb,
    this.description,
    this.descriptionMatched = false,
  });

  final String? eyebrow;
  final Color? eyebrowColor;
  final String title;
  final String? breadcrumb;
  final String? description;
  final bool descriptionMatched;
  final String primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: eyebrowColor ?? colors.accentDim,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        if (breadcrumb != null) ...[
          const SizedBox(height: 3),
          Text(
            breadcrumb!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
        ],
        if (description != null) ...[
          const SizedBox(height: 5),
          Text(
            descriptionMatched ? '“${description!}”' : description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontStyle: descriptionMatched ? FontStyle.italic : null,
              color: descriptionMatched ? colors.gold : colors.muted,
            ),
          ),
        ],
        if (!descriptionMatched) ...[
          const SizedBox(height: 6),
          Text(
            primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colors.gold,
            ),
          ),
        ],
      ],
    );
  }
}

class SearchArtworkVisual extends StatelessWidget {
  const SearchArtworkVisual({
    super.key,
    this.asset,
    required this.fallbackIcon,
  });

  final String? asset;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (asset == null) return SearchMissingVisual(icon: fallbackIcon);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SearchMissingVisual(icon: fallbackIcon),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                colors.nightPanel.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SearchConstellationVisual extends StatelessWidget {
  const SearchConstellationVisual({super.key, required this.shape});

  final ConstellationShape? shape;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = this.shape;
    if (shape == null || shape.points.isEmpty) {
      return const SearchMissingVisual(icon: Icons.insights);
    }
    return ColoredBox(
      color: colors.night.withValues(alpha: 0.48),
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          painter: ConstellationEditorPainter(
            points: _centeredShapePoints(
              shape.points,
              constraints.biggest,
              inset: 10,
            ),
            edges: shape.edges,
            highlightedIndex: null,
            pointColor: colors.text,
            highlightColor: colors.gold,
            lineColor: colors.muted.withValues(alpha: 0.6),
            pointRadius: 2.5,
          ),
        ),
      ),
    );
  }
}

class SearchStarVisual extends StatelessWidget {
  const SearchStarVisual({
    super.key,
    required this.kind,
    this.pulsarLit = true,
    this.pulsarBothStates = false,
  });

  final StarKind kind;
  final bool pulsarLit;

  /// For a pulsar shown as a *kind* rather than as one particular habit
  /// (the star form's tile): a pulsar can be burning or dark, so it's drawn
  /// half gold and half blue — icon and glow alike — instead of committing
  /// to one. Ignored for every other kind.
  final bool pulsarBothStates;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = starKindColor(kind, colors, lit: pulsarLit);
    final both = pulsarBothStates && kind == StarKind.pulsar;
    final burning = starKindColor(StarKind.pulsar, colors);
    final dark = starKindColor(StarKind.pulsar, colors, lit: false);
    // The glow fades all the way to nothing by the time it reaches the
    // nearest edge of the box (a radius of half the shorter side), so the box
    // never cuts it off: it used to stop at a faint flat tint that showed as
    // a hard-edged rectangle around it.
    RadialGradient glow(Color c, {Alignment center = Alignment.center}) =>
        RadialGradient(
          center: center,
          colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0)],
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: both ? null : glow(color),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (both) ...[
            // Two half-strength glows side by side, gold on the left and
            // blue on the right.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(burning, center: const Alignment(-0.25, 0)),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(dark, center: const Alignment(0.25, 0)),
                ),
              ),
            ),
          ],
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (both ? colors.text : color).withValues(alpha: 0.16),
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.night.withValues(alpha: 0.34),
            ),
          ),
          if (both)
            // Left half gold, right half blue, with a hard edge down the
            // middle.
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [burning, burning, dark, dark],
                stops: const [0, 0.5, 0.5, 1],
              ).createShader(bounds),
              child: Icon(kind.icon, size: 36, color: Colors.white),
            )
          else if (kind == StarKind.pulsar)
            Icon(kind.icon, size: 36, color: color)
          else if (kind == StarKind.dead)
            Icon(kind.icon, size: 34, color: color)
          else if (kind == StarKind.nascent)
            Icon(kind.icon, size: 30, color: color)
          else
            StarGlyph(kind: kind, size: 34),
        ],
      ),
    );
  }
}

class SearchMissingVisual extends StatelessWidget {
  const SearchMissingVisual({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.night.withValues(alpha: 0.48),
      child: Center(
        child: Icon(
          icon,
          size: 30,
          color: colors.muted.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _SearchQuickMenuToggle extends StatelessWidget {
  const _SearchQuickMenuToggle({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = isOpen
        ? context.strings.searchCardMenuCloseAction
        : context.strings.searchCardMenuOpenAction;
    return Semantics(
      button: true,
      expanded: isOpen,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          key: const Key('search-card-quick-menu-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: motionDuration(context, kMotionBase),
            curve: kMotionEnter,
            width: 20,
            height: 48,
            decoration: BoxDecoration(
              color: isOpen ? AppColors.dark.gold : colors.night,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.dark.gold,
                width: 1,
              ),
            ),
            child: AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: motionDuration(context, kMotionBase),
              curve: kMotionEnter,
              child: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: isOpen ? colors.night : AppColors.dark.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchQuickMenu extends StatelessWidget {
  const _SearchQuickMenu({
    required this.actions,
    required this.onActionSelected,
    required this.progress,
  });

  final List<SearchCardAction> actions;
  final VoidCallback onActionSelected;

  /// How far the drawer is open, 0 to 1 and linear (closing runs it back
  /// down). The menu stays mounted while closed, so its buttons are driven by
  /// this instead of a one-shot entrance: they cascade across, one after
  /// another, every time it opens.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('search-card-quick-menu'),
      decoration: BoxDecoration(
        color: AppColors.dark.gold,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 5),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++)
              Expanded(
                child: _cascadeIn(
                  context,
                  index: i,
                  child: _SearchQuickMenuAction(
                    action: actions[i],
                    onActionSelected: onActionSelected,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fades and slides the [index]-th button in from above, starting a little
  /// after the one before it.
  Widget _cascadeIn(
    BuildContext context, {
    required int index,
    required Widget child,
  }) {
    const stagger = 0.2;
    final span = (1 - (actions.length - 1) * stagger).clamp(0.4, 1.0);
    final t = ((progress - index * stagger) / span).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: FractionalTranslation(
        translation: Offset(0, -0.4 * (1 - eased)),
        child: child,
      ),
    );
  }
}

class _SearchQuickMenuAction extends StatelessWidget {
  const _SearchQuickMenuAction({
    required this.action,
    required this.onActionSelected,
  });

  final SearchCardAction action;
  final VoidCallback onActionSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = context.colors.night;
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: () {
          onActionSelected();
          action.onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 17, color: foreground),
            const SizedBox(height: 2),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Offset> _centeredShapePoints(
  List<Offset> points,
  Size size, {
  double inset = 0,
}) {
  if (points.isEmpty || size.isEmpty) return const [];
  var minX = points.first.dx;
  var maxX = points.first.dx;
  var minY = points.first.dy;
  var maxY = points.first.dy;
  for (final point in points.skip(1)) {
    if (point.dx < minX) minX = point.dx;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dy > maxY) maxY = point.dy;
  }
  final shapeWidth = (maxX - minX).abs();
  final shapeHeight = (maxY - minY).abs();
  final availableWidth = (size.width - inset * 2).clamp(1.0, double.infinity);
  final availableHeight = (size.height - inset * 2).clamp(1.0, double.infinity);
  final scaleX = shapeWidth == 0
      ? double.infinity
      : availableWidth / shapeWidth;
  final scaleY = shapeHeight == 0
      ? double.infinity
      : availableHeight / shapeHeight;
  final finiteScales = [scaleX, scaleY].where((value) => value.isFinite);
  final scale = finiteScales.isEmpty
      ? 1.0
      : finiteScales.reduce((a, b) => a < b ? a : b);
  final shapeCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  final canvasCenter = Offset(size.width / 2, size.height / 2);
  return [
    for (final point in points) canvasCenter + (point - shapeCenter) * scale,
  ];
}
