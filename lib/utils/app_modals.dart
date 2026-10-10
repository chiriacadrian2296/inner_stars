import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_style.dart';
import 'responsive.dart';

/// Material 3's desktop width for modal bottom sheets. Fixed sheets use a
/// custom route, so they need to opt into the same cap explicitly.
const double _kFixedSheetMaxWidth = 640;

/// Room reserved on each side of a wide-screen sheet so its scrollbar can
/// sit just outside the sheet's edge (thumb ~8px plus a small gap) instead of
/// inside it. Both sides, so the sheet itself stays centered.
const double _kSheetScrollbarGutter = 14;

enum AppConfirmationTone { standard, destructive }

/// Canonical heading for bottom sheets: same scale as dialog titles, with
/// gold distinguishing a sheet from a blocking popup.
class AppSheetTitle extends StatelessWidget {
  const AppSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.gold,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// A destination inside a functional sheet: visually related to filter
/// surfaces, but without pretending that an action is a selected value.
class AppSheetAction extends StatelessWidget {
  const AppSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
    this.uppercase = true,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;

  /// Off to show [label] as written instead of in capitals.
  final bool uppercase;

  /// Draws the row as the current choice.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: selectableDecoration(colors, selected: selected),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? colors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButtonLabel(
                    label,
                    uppercase: uppercase,
                    color: colors.text,
                    fontSize: 12,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One confirmation contract for every entry point that performs the same
/// action. Labels keep their localized casing; color communicates function:
/// cancel is neutral, while a destructive confirmation is always red.
Future<bool> showAppConfirmation({
  required BuildContext context,
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  AppConfirmationTone tone = AppConfirmationTone.standard,
}) async {
  final colors = context.colors;
  final result = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: colors.muted),
          child: AppButtonLabel(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: tone == AppConfirmationTone.destructive
                ? colors.danger
                : colors.gold,
          ),
          child: AppButtonLabel(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shared dialog shell. Purpose-specific dialogs keep their own content and
/// actions, while width, spacing, scrolling and action alignment stay stable.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.scrollable = false,
    this.actionsAlignment = MainAxisAlignment.end,
    this.actionsOverflowAlignment = OverflowBarAlignment.end,
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool scrollable;
  final MainAxisAlignment actionsAlignment;
  final OverflowBarAlignment actionsOverflowAlignment;
  final EdgeInsetsGeometry actionsPadding;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon,
      title: title == null
          ? null
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: title!,
            ),
      content: content,
      actions: actions,
      backgroundColor: backgroundColor,
      scrollable: scrollable,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: EdgeInsets.fromLTRB(24, icon == null ? 24 : 8, 24, 0),
      contentPadding: EdgeInsets.fromLTRB(24, title == null ? 24 : 16, 24, 0),
      actionsPadding: actionsPadding,
      actionsAlignment: actionsAlignment,
      actionsOverflowAlignment: actionsOverflowAlignment,
      actionsOverflowButtonSpacing: 8,
    );
  }
}

/// Common chrome for custom bottom-sheet bodies. The caller owns only the
/// content and optional footer; keyboard/safe-area handling stays with
/// [showAppSheet].
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.showHandle = true,
  });

  final Widget title;
  final Widget child;
  final Widget? footer;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(alignment: Alignment.centerLeft, child: title),
          ),
          Flexible(child: child),
          if (footer != null) ...[
            Divider(height: 1, color: divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// [showDialog] with the app's fade-and-scale entrance, so every dialog
/// arrives the same way. Same contract as `showDialog` for the arguments
/// the app actually uses.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  // `showDialog` carries a screen's local themes (the per-area theme, for
  // one) up to the root navigator; `showModal` doesn't, so do it here.
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );
  return showModal<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    configuration: FadeScaleTransitionConfiguration(
      barrierDismissible: barrierDismissible,
      transitionDuration: reduceMotion ? Duration.zero : kMotionBase,
      reverseTransitionDuration: reduceMotion ? Duration.zero : kMotionFast,
    ),
    builder: (context) => themes.wrap(builder(context)),
  );
}

/// [showModalBottomSheet] with the app's shared slide timing. Forwards the
/// arguments the app's sheets use; the sheet look itself still comes from
/// `bottomSheetTheme` in `buildAppTheme`.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool enableDrag = true,
  bool isDismissible = true,
  bool showDragHandle = false,
  bool useRootNavigator = false,
  ShapeBorder? shape,
  Clip? clipBehavior,
  double? elevation,
  bool outsideScrollbar = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final openingMediaQuery = MediaQuery.of(context);
  final sheetTheme = Theme.of(context).bottomSheetTheme;

  // On a wide mouse-driven screen the sheet is a narrower centered panel;
  // there its scrollbar goes just outside the panel's edge. The route's own
  // sheet surface is then made invisible and widened by the gutters, and
  // [_OutsideScrollbarFrame] repaints the real surface inside them.
  final baseConstraints = constraints ?? sheetTheme.constraints;
  final baseMaxWidth = baseConstraints?.maxWidth ?? 640;
  final outside =
      outsideScrollbar &&
      !isTouchOnlyMobile &&
      baseMaxWidth.isFinite &&
      MediaQuery.sizeOf(context).width >=
          baseMaxWidth + 2 * _kSheetScrollbarGutter;
  final routeConstraints = !outside
      ? constraints
      : (baseConstraints ?? const BoxConstraints()).copyWith(
          maxWidth: baseMaxWidth + 2 * _kSheetScrollbarGutter,
        );

  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final routeMediaQuery = MediaQuery.of(sheetContext);
      final fixedMediaQuery = openingMediaQuery.copyWith(
        padding: routeMediaQuery.padding,
        viewPadding: routeMediaQuery.viewPadding,
        systemGestureInsets: routeMediaQuery.systemGestureInsets,
        viewInsets: EdgeInsets.zero,
      );
      final content = MediaQuery(
        data: fixedMediaQuery,
        child: Builder(builder: builder),
      );
      if (!outside) return content;
      return _OutsideScrollbarFrame(
        color: backgroundColor ?? sheetTheme.backgroundColor,
        elevation: elevation ?? sheetTheme.elevation ?? 1,
        shape: shape ?? sheetTheme.shape,
        clipBehavior: clipBehavior ?? sheetTheme.clipBehavior ?? Clip.none,
        child: content,
      );
    },
    backgroundColor: outside ? Colors.transparent : backgroundColor,
    barrierColor: barrierColor,
    constraints: routeConstraints,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    shape: outside ? const RoundedRectangleBorder() : shape,
    clipBehavior: outside ? Clip.none : clipBehavior,
    elevation: outside ? 0 : elevation,
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? Duration.zero : kMotionBase,
      reverseDuration: reduceMotion ? Duration.zero : kMotionFast,
      curve: kMotionEnter,
      reverseCurve: kMotionExit,
    ),
  );
}

/// A bottom-aligned modal whose geometry never reacts to the keyboard.
/// The keyboard is allowed to cover its lower portion instead of resizing
/// or translating it. Used by searchable pickers with controls anchored at
/// the bottom of a fixed-height sheet.
Future<T?> showFixedAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  final openingMediaQuery = MediaQuery.of(context);
  // A caller below a SafeArea can expose zero bottom padding even though the
  // device navigation area still exists. Fixed sheets live at the root of the
  // route, so restore that physical inset before their own SafeArea is built.
  final viewMediaQuery = MediaQueryData.fromView(
    View.of(context),
    platformData: openingMediaQuery,
  );
  final bottomViewPadding = viewMediaQuery.viewPadding.bottom;
  final mediaQuery = openingMediaQuery.copyWith(
    padding: openingMediaQuery.padding.copyWith(
      top: 0,
      bottom: bottomViewPadding,
    ),
    viewPadding: openingMediaQuery.viewPadding.copyWith(
      top: 0,
      bottom: bottomViewPadding,
    ),
    viewInsets: EdgeInsets.zero,
    disableAnimations: true,
  );
  final theme = Theme.of(context);
  final sheetTheme = theme.bottomSheetTheme;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final outside =
      !isTouchOnlyMobile &&
      mediaQuery.size.width >=
          _kFixedSheetMaxWidth + 2 * _kSheetScrollbarGutter;

  final sheetBody = ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _kFixedSheetMaxWidth),
    child: SizedBox(
      width: mediaQuery.size.width,
      child: Builder(builder: builder),
    ),
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: reduceMotion ? Duration.zero : kMotionBase,
    pageBuilder: (routeContext, _, _) => MediaQuery(
      data: mediaQuery,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: outside
            ? _OutsideScrollbarFrame(
                color: sheetTheme.backgroundColor ?? Colors.transparent,
                elevation: sheetTheme.elevation ?? 0,
                shape: sheetTheme.shape,
                clipBehavior: Clip.antiAlias,
                child: sheetBody,
              )
            : Material(
                color: sheetTheme.backgroundColor ?? Colors.transparent,
                elevation: sheetTheme.elevation ?? 0,
                shape: sheetTheme.shape,
                clipBehavior: Clip.antiAlias,
                child: sheetBody,
              ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: kMotionEnter)),
          child: child,
        ),
  );
}

/// Wide-screen sheet surface whose scrollbar sits just outside its edge.
///
/// Draws the sheet surface itself (the route's own one is made invisible and
/// [_kSheetScrollbarGutter] wider each side by the caller), and owns the
/// [ScrollController] its content scrolls with: it is handed down as the
/// [PrimaryScrollController], so any vertical scroll view inside that doesn't
/// bring its own controller picks it up with no change at the call site. The
/// thumb ([_OutsideScrollThumb]) is drawn in the right-hand gutter, over the
/// same vertical span as the scroll view. Scroll views that do bring their own controller
/// keep their normal in-sheet scrollbar.
class _OutsideScrollbarFrame extends StatefulWidget {
  const _OutsideScrollbarFrame({
    required this.color,
    required this.elevation,
    required this.shape,
    required this.clipBehavior,
    required this.child,
  });

  final Color? color;
  final double elevation;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final Widget child;

  @override
  State<_OutsideScrollbarFrame> createState() => _OutsideScrollbarFrameState();
}

class _OutsideScrollbarFrameState extends State<_OutsideScrollbarFrame> {
  final _controller = ScrollController();
  final _surfaceKey = GlobalKey();

  /// Where the sheet's scroll view sits inside the frame, so the outside
  /// track runs alongside the scrollable part (below the title, above the
  /// footer) exactly as an in-sheet scrollbar would, not the whole sheet.
  EdgeInsets _trackInsets = EdgeInsets.zero;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    var next = EdgeInsets.zero;
    if (_controller.hasClients) {
      final surface = _surfaceKey.currentContext?.findRenderObject();
      final viewport = _controller.positions.first.context.storageContext
          .findRenderObject();
      if (surface is RenderBox &&
          viewport is RenderBox &&
          surface.attached &&
          viewport.attached &&
          surface.hasSize &&
          viewport.hasSize) {
        final top = viewport.localToGlobal(Offset.zero, ancestor: surface).dy;
        final bottom = surface.size.height - top - viewport.size.height;
        next = EdgeInsets.only(
          top: top < 0 ? 0 : top,
          bottom: bottom < 0 ? 0 : bottom,
        );
      }
    }
    if (next != _trackInsets) setState(() => _trackInsets = next);
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      // Desktop and web don't hand the primary controller to scroll views on
      // their own; this sheet needs them to.
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: ScrollConfiguration(
        behavior: _OutsideScrollbarBehavior(_controller),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                // Content or viewport size changed: re-align the track.
                _scheduleMeasure();
                if (mounted) setState(() {});
                return false;
              },
              child: Padding(
                key: _surfaceKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: _kSheetScrollbarGutter,
                ),
                child: Material(
                  color: widget.color,
                  elevation: widget.elevation,
                  shape: widget.shape,
                  clipBehavior: widget.clipBehavior,
                  surfaceTintColor: Colors.transparent,
                  child: widget.child,
                ),
              ),
            ),
            // Same vertical span as the scroll view itself, in the right-hand
            // gutter.
            Positioned(
              top: _trackInsets.top,
              bottom: _trackInsets.bottom,
              right: 0,
              width: _kSheetScrollbarGutter,
              child: _OutsideScrollThumb(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

/// The thumb of [_OutsideScrollbarFrame]: drawn and dragged by hand rather
/// than with [Scrollbar], whose track length is tied to the scroll view's own
/// box and so can't be shifted down to run alongside it from outside.
class _OutsideScrollThumb extends StatefulWidget {
  const _OutsideScrollThumb({required this.controller});

  final ScrollController controller;

  @override
  State<_OutsideScrollThumb> createState() => _OutsideScrollThumbState();
}

class _OutsideScrollThumbState extends State<_OutsideScrollThumb> {
  static const _thickness = 8.0;
  static const _minLength = 32.0;

  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasClients) return const SizedBox.shrink();
        final position = widget.controller.positions.first;
        if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final track = constraints.maxHeight;
            final max = position.maxScrollExtent;
            final viewport = position.viewportDimension;
            final length = (track * viewport / (viewport + max))
                .clamp(_minLength, track)
                .toDouble();
            final travel = track - length;
            final top = max <= 0
                ? 0.0
                : (position.pixels.clamp(0.0, max) / max) * travel;
            final colors = context.colors;
            return Stack(
              children: [
                Positioned(
                  top: top,
                  right: 0,
                  width: _thickness,
                  height: length,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovering = true),
                    onExit: (_) => setState(() => _hovering = false),
                    child: GestureDetector(
                      onVerticalDragStart: (_) =>
                          setState(() => _dragging = true),
                      onVerticalDragEnd: (_) =>
                          setState(() => _dragging = false),
                      onVerticalDragCancel: () =>
                          setState(() => _dragging = false),
                      onVerticalDragUpdate: (details) {
                        if (travel <= 0) return;
                        widget.controller.jumpTo(
                          (position.pixels + details.delta.dy * max / travel)
                              .clamp(0.0, max),
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _hovering || _dragging
                              ? colors.nightBorder
                              : colors.nightPanel,
                          borderRadius: BorderRadius.circular(_thickness / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The platform scrollbar for every scroll view except the one driven by
/// [owner], whose scrollbar [_OutsideScrollbarFrame] already draws outside
/// the sheet — so it doesn't get a second one inside.
class _OutsideScrollbarBehavior extends MaterialScrollBehavior {
  const _OutsideScrollbarBehavior(this.owner);

  final ScrollController owner;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (identical(details.controller, owner)) return child;
    return super.buildScrollbar(context, child, details);
  }
}
