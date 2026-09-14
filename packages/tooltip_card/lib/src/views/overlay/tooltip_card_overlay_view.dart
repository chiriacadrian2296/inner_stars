part of '../views.dart';

/// Overlay panel view. Geometry reading and widget composition live here,
/// while lifecycle decisions remain in the controllers.
class TooltipCardOverlayView extends StatelessWidget {
  const TooltipCardOverlayView({
    super.key,
    required this.overlay,
    required this.targetKey,
    required this.contentBuilder,
    required this.viewModel,
    required this.preferredSide,
    required this.viewportMargin,
    required this.fitToViewport,
    required this.autoFlipIfZeroSpace,
    required this.wrapContentInScrollView,
    required this.offset,
    required this.animationType,
    required this.fade,
    required this.scale,
    required this.slide,
    required this.resolvedSide,
    required this.resolvedBeakPosition,
    required this.onResolvedPlacement,
    required this.onPanelHoverChanged,
    required this.onClose,
  });

  final OverlayState overlay;
  final GlobalKey targetKey;
  final Widget Function(BuildContext context) contentBuilder;
  final TooltipCardViewModel viewModel;
  final TooltipCardPlacementSide preferredSide;
  final EdgeInsetsDirectional viewportMargin;
  final bool fitToViewport;
  final bool autoFlipIfZeroSpace;
  final bool wrapContentInScrollView;
  final Offset offset;
  final TooltipCardAnimation animationType;
  final Animation<double> fade;
  final Animation<double> scale;
  final Animation<Offset> slide;
  final TooltipCardPlacementSide resolvedSide;
  final double resolvedBeakPosition;
  final void Function(TooltipCardPlacementSide side, double beakPosition)
  onResolvedPlacement;
  final ValueChanged<bool> onPanelHoverChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || targetBox == null || !targetBox.hasSize) {
      return const SizedBox.shrink();
    }

    final targetTopLeft = targetBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final targetRect = targetTopLeft & targetBox.size;

    final scopedContext = targetKey.currentContext ?? context;
    Widget content = contentBuilder(scopedContext);
    if (wrapContentInScrollView) {
      content = SingleChildScrollView(primary: false, child: content);
    }

    return CustomSingleChildLayout(
      delegate: TooltipCardPositionDelegate(
        overlaySize: overlayBox.size,
        targetRect: targetRect,
        awaySpace: viewModel.awaySpace,
        preferredSide: preferredSide,
        textDirection: Directionality.of(context),
        viewportMargin: viewportMargin,
        fitToViewport: fitToViewport,
        autoFlipIfZeroSpace: autoFlipIfZeroSpace,
        userConstraints: viewModel.constraints,
        borderRadius: viewModel.borderRadius,
        beakSize: viewModel.beakSize,
        beakInset: viewModel.beakInset,
        offset: offset,
        onResolvedPlacement: onResolvedPlacement,
      ),
      child: MouseRegion(
        onEnter: (_) => onPanelHoverChanged(true),
        onExit: (_) => onPanelHoverChanged(false),
        child: Semantics(
          container: true,
          label: 'Tooltip panel',
          child: BeakedTooltipCardPanel(
            fade: fade,
            scale: scale,
            slide: slide,
            animation: animationType,
            onEscape: onClose,
            elevation: viewModel.elevation,
            backgroundColor: viewModel.backgroundColor,
            borderRadius: viewModel.borderRadius,
            padding: viewModel.padding,
            constraints: viewModel.constraints,
            beakEnabled: viewModel.beakEnabled,
            beakSize: viewModel.beakSize,
            beakInset: viewModel.beakInset,
            beakColor: viewModel.beakColor,
            beakPosition: resolvedBeakPosition,
            side: resolvedSide,
            textDirection: Directionality.of(context),
            borderColor: viewModel.borderColor,
            borderWidth: viewModel.borderWidth,
            shadows: viewModel.shadows,
            child: content,
          ),
        ),
      ),
    );
  }
}
