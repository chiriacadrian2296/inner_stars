import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

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
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    constraints: constraints,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    shape: shape,
    clipBehavior: clipBehavior,
    elevation: elevation,
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? Duration.zero : kMotionBase,
      reverseDuration: reduceMotion ? Duration.zero : kMotionFast,
      curve: kMotionEnter,
      reverseCurve: kMotionExit,
    ),
  );
}
