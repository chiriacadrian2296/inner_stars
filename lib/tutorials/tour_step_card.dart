import 'package:flutter/widgets.dart';
import 'package:hint_kit/hint_kit.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/press_scale.dart';

/// Replaces every tour step's default [TourStepCard] — same layout (title,
/// description, progress label, Skip/Back/Next), but with the app's own
/// gold-on-navy button treatment instead of hint_kit's own barely-there
/// transparent/thin-border buttons, which read as too subtle against the
/// gold card background. Pass as `HintTarget(contentBuilder: appTourStepCard, ...)`.
///
/// `contentBuilder` gets no [ResolvedHintTheme] of its own (only
/// [TourStepInfo]), so this re-resolves it the same way [HintTarget] does
/// internally — via [TourScope.of]'s own `theme`, not `Theme.of(context)`
/// alone — to keep the title/description text matching the card's real
/// background exactly as the default card would.
Widget appTourStepCard(BuildContext context, TourStepInfo info) {
  final theme = HintThemeData.resolve(context, TourScope.of(context).theme);
  return _AppTourStepCard(info: info, theme: theme);
}

class _AppTourStepCard extends StatelessWidget {
  const _AppTourStepCard({
    required this.info,
    required this.theme,
    this.showSkip = true,
  });

  final TourStepInfo info;
  final ResolvedHintTheme theme;

  /// Off for [appTourStepCardNoSkip] — see its own doc comment.
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    final title = info.title;
    final description = info.description;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: theme.titleStyle),
          const SizedBox(height: 4),
        ],
        if (description != null) Text(description, style: theme.messageStyle),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            // No step-count label ("13/15") here on purpose — a long tour
            // (the sky-navigation one runs to 15) read as daunting shown
            // as a countdown before the user had even started.
            if (showSkip && !info.isLast)
              AppTourButton(
                label: info.labels.skip,
                onPressed: info.controller.skip,
              ),
            if (!info.isFirst)
              AppTourButton(
                label: info.labels.back,
                onPressed: info.controller.previous,
              ),
            // The one action every step actually wants taken — bolder
            // weight only, since the shared white/navy treatment no longer
            // has a shade ladder to set it apart with.
            AppTourButton(
              label: info.labels.advance(isLast: info.isLast),
              onPressed: info.controller.next,
              emphasised: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// Same visual treatment as [appTourStepCard], but with no buttons at all
/// — no Skip, no Back, no Next. For a step that only advances when the
/// user performs the real gesture it describes (see `SkyHintTarget`, and
/// the sky-navigation tour's own FAB steps), *any* button here would be a
/// way to bypass actually doing it, which defeats the point: the
/// sky-navigation tour deliberately gives every one of its steps no exit
/// but the real gesture. Pass as
/// `HintTarget(contentBuilder: appTourGestureStepCard, ...)`.
Widget appTourGestureStepCard(BuildContext context, TourStepInfo info) {
  final theme = HintThemeData.resolve(context, TourScope.of(context).theme);
  return _AppTourGestureStepCard(info: info, theme: theme);
}

class _AppTourGestureStepCard extends StatelessWidget {
  const _AppTourGestureStepCard({required this.info, required this.theme});

  final TourStepInfo info;
  final ResolvedHintTheme theme;

  @override
  Widget build(BuildContext context) {
    final title = info.title;
    final description = info.description;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: theme.titleStyle),
          const SizedBox(height: 4),
        ],
        if (description != null) Text(description, style: theme.messageStyle),
      ],
    );
  }
}

/// Same visual treatment as [appTourStepCard], but with no Skip button —
/// Back and Next stay. For the sky-navigation tour's own purely
/// informational steps (the quick-access menu's five button explanations):
/// there is no real gesture to wait for there (the buttons themselves stay
/// deliberately inert until the tour finishes), so Next has to remain the
/// way through, but the tour still shouldn't offer a way out early. Pass
/// as `HintTarget(contentBuilder: appTourStepCardNoSkip, ...)`.
Widget appTourStepCardNoSkip(BuildContext context, TourStepInfo info) {
  final theme = HintThemeData.resolve(context, TourScope.of(context).theme);
  return _AppTourStepCard(info: info, theme: theme, showSkip: false);
}

/// The sky-navigation tour's own opening card — title, description, and
/// one button (Start), no progress label, no Skip/Back. Every other step
/// in that tour only ever advances on a real gesture or (for the
/// quick-access hints) Next/Back; this is the one deliberate exception,
/// since there is nothing yet on screen to point at or gesture toward —
/// see `sky_screen.dart`'s own order-1 `HintTarget` for the rest of what
/// makes this step different (no scrim, centered). Pass as
/// `HintTarget(contentBuilder: appTourWelcomeCard, ...)`.
Widget appTourWelcomeCard(BuildContext context, TourStepInfo info) {
  final theme = HintThemeData.resolve(context, TourScope.of(context).theme);
  return _AppTourWelcomeCard(info: info, theme: theme);
}

class _AppTourWelcomeCard extends StatelessWidget {
  const _AppTourWelcomeCard({required this.info, required this.theme});

  final TourStepInfo info;
  final ResolvedHintTheme theme;

  @override
  Widget build(BuildContext context) {
    final title = info.title;
    final description = info.description;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: theme.titleStyle),
          const SizedBox(height: 4),
        ],
        if (description != null) Text(description, style: theme.messageStyle),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: AppTourButton(
            label: context.strings.skyTourWelcomeStartAction,
            onPressed: info.controller.next,
            emphasised: true,
          ),
        ),
      ],
    );
  }
}

/// One Skip/Back/Next control — a solid white pill with dark navy text,
/// rather than hint_kit's own default of a translucent fill only on the
/// emphasised button and a bare outline on the rest. Public (not the usual
/// leading-underscore private class every other widget in this file is)
/// so [TourGestureConfirmStep]'s own "Try" button can reuse the exact same
/// look instead of duplicating it.
class AppTourButton extends StatelessWidget {
  const AppTourButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: PressScale(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.dark.text,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.dark.night,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
