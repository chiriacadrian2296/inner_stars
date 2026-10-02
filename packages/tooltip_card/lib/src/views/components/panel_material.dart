part of '../views.dart';

/// Material panel for TooltipCard content.
///
/// The outer decoration owns the flat GeniusLink border and popover shadow;
/// Material remains responsible for clipping, semantics, and optional explicit
/// elevation overrides.
class PanelMaterial extends StatelessWidget {
  const PanelMaterial({
    super.key,
    required this.elevation,
    required this.backgroundColor,
    required this.borderRadius,
    required this.child,
    this.borderColor,
    this.borderWidth = 0,
    this.shadows = const [],
  });

  final double elevation;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final hasBorder = borderColor != null && borderWidth > 0;
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: hasBorder
          ? BorderSide(color: borderColor!, width: borderWidth)
          : BorderSide.none,
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: Material(
          elevation: elevation,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Theme.of(context).shadowColor,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          // Spacing belongs to BeakedPanelWithBeak's public `padding`
          // parameter. Keeping a second, implicit 12 px horizontal / 8 px
          // vertical inset here made an explicitly uniform padding render
          // visibly wider at the sides.
          child: child,
        ),
      ),
    );
  }
}
