import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

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
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: tone == AppConfirmationTone.destructive
                ? colors.danger
                : colors.gold,
          ),
          child: Text(confirmLabel),
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
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool scrollable;

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
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: EdgeInsets.fromLTRB(24, title == null ? 24 : 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowAlignment: OverflowBarAlignment.end,
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
