import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'sky_tooltip_header.dart';
import 'staggered_entrance.dart';

/// Shown right after creating any star (lit, unlit, or a pulsar) or a
/// whole new constellation — a small, deliberate "that worked" moment
/// rather than just dropping the user back on the sky with no
/// acknowledgement. [message] is the one thing that changes per kind
/// (see `SkyScreen`'s own call sites); everything else about this popup —
/// the eyebrow, the two actions, the close button — stays the same
/// regardless of what was just made.
///
/// Both actions close this popup first, then run their own callback —
/// [onTakeMeThere] flies the camera there with the same feedback an
/// actual hold gets (see `SkyScreen._flyToWithHoldFeedback`), [onShare]
/// hands the new thing to the OS share sheet the same way a lit star's
/// own tooltip already does (see `SkyScreen._shareQuickLookStar`) — never
/// left stacked on top of either.
class CreationSuccessDialog extends StatelessWidget {
  const CreationSuccessDialog({
    super.key,
    required this.icon,
    required this.message,
    required this.onTakeMeThere,
    required this.onShare,
  });

  final IconData icon;
  final String message;
  final VoidCallback onTakeMeThere;
  final VoidCallback onShare;

  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    required String message,
    required VoidCallback onTakeMeThere,
    required VoidCallback onShare,
  }) {
    return showAppDialog<void>(
      context: context,
      builder: (_) => CreationSuccessDialog(
        icon: icon,
        message: message,
        onTakeMeThere: onTakeMeThere,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Dialog(
      backgroundColor: colors.nightPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredEntrance(
              index: 0,
              child: SkyTooltipHeader(
                icon: icon,
                iconColor: colors.gold,
                iconSize: 22,
                title: strings.creationSuccessEyebrow,
                titleColor: colors.text,
                titleFontSize: 17,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 14),
            StaggeredEntrance(
              index: 1,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: StaggeredEntrance(
                      index: 2,
                      axis: Axis.horizontal,
                      child: _CreationSuccessAction(
                        icon: Icons.navigation,
                        label: strings.takeMeThereAction,
                        color: colors.gold,
                        onTap: () {
                          Navigator.of(context).pop();
                          onTakeMeThere();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StaggeredEntrance(
                      index: 3,
                      axis: Axis.horizontal,
                      child: _CreationSuccessAction(
                        icon: Icons.share_outlined,
                        label: strings.starQuickLookShareAction,
                        color: colors.muted,
                        onTap: () {
                          Navigator.of(context).pop();
                          onShare();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two footer buttons — same "icon above a short label" shape
/// [SkyStarTooltip]'s own `_TooltipAction` uses, just sized for a two-wide
/// row instead of that one's up-to-four.
class _CreationSuccessAction extends StatelessWidget {
  const _CreationSuccessAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusField),
        side: BorderSide(color: colors.nightBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
