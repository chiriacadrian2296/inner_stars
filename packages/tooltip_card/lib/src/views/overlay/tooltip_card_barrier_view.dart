part of '../views.dart';

/// Barrier view displayed behind a TooltipCard overlay.
class TooltipCardBarrierView extends StatelessWidget {
  const TooltipCardBarrierView({
    super.key,
    required this.fade,
    required this.modal,
    required this.dismissible,
    required this.color,
    required this.blur,
    required this.onDismiss,
  });

  final Animation<double> fade;
  final bool modal;
  final bool dismissible;
  final Color color;
  final double blur;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: modal ? 'Modal barrier' : 'Dismissible overlay',
      button: dismissible,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: fade,
          builder: (context, _) {
            Widget barrier = Container(
              color: modal
                  ? color.withValues(alpha: color.a * fade.value)
                  : Colors.transparent,
            );

            if (modal && blur > 0) {
              barrier = BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blur * fade.value,
                  sigmaY: blur * fade.value,
                  tileMode: TileMode.clamp,
                ),
                child: barrier,
              );
            }

            if (dismissible) {
              barrier = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: barrier,
              );
            } else if (modal) {
              barrier = AbsorbPointer(child: barrier);
            }

            return SizedBox.expand(child: barrier);
          },
        ),
      ),
    );
  }
}
