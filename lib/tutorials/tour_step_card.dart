import 'package:flutter/widgets.dart';
import 'package:hint_kit/hint_kit.dart';

import '../theme/app_colors.dart';

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
  const _AppTourStepCard({required this.info, required this.theme});

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
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (info.length > 1)
              Text(
                info.labels.progress(info.step, info.length),
                style: theme.messageStyle,
              ),
            // Darkest, least prominent — the way out, not a real choice.
            if (!info.isLast)
              _AppTourButton(
                label: info.labels.skip,
                onPressed: info.controller.skip,
                background: AppColors.dark.night,
              ),
            // A shade up from Skip — still secondary, but a real step back.
            if (!info.isFirst)
              _AppTourButton(
                label: info.labels.back,
                onPressed: info.controller.previous,
                background: AppColors.dark.nightPanel,
              ),
            // Lightest/most prominent navy — this is the one action every
            // step actually wants taken.
            _AppTourButton(
              label: info.labels.advance(isLast: info.isLast),
              onPressed: info.controller.next,
              background: AppColors.dark.nightBorder,
              emphasised: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// One Skip/Back/Next control — a solid navy pill (shade set by [background])
/// with gold text, rather than hint_kit's own default of a translucent fill
/// only on the emphasised button and a bare outline on the rest.
class _AppTourButton extends StatelessWidget {
  const _AppTourButton({
    required this.label,
    required this.onPressed,
    required this.background,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Color background;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.dark.gold,
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
