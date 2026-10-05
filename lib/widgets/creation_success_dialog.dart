import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// Shown right after creating or reigniting any star (lit, unlit, or a
/// pulsar), or creating a whole new constellation — a small, deliberate
/// "that worked" moment rather than just dropping the user back on the sky
/// with no acknowledgement. [message] is the one thing that changes per kind
/// (see `SkyScreen`'s own call sites); everything else about this popup —
/// the eyebrow and the three actions stay the same
/// regardless of what was just made.
///
/// Every action closes this popup first, then runs its own callback:
/// [onOpen] opens the new thing's single-item view, [onTakeMeThere] flies
/// the camera there with the same feedback an actual hold gets (see
/// `SkyScreen._flyToWithHoldFeedback`), and [onShare] hands it to the OS
/// share sheet the same way a lit star's own tooltip already does (see
/// `SkyScreen._shareQuickLookStar`) — never left stacked on top of any of
/// them.
class CreationSuccessDialog extends StatelessWidget {
  const CreationSuccessDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.onOpen,
    required this.onTakeMeThere,
    required this.onShare,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback onOpen;
  final VoidCallback onTakeMeThere;
  final VoidCallback onShare;

  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String message,
    required VoidCallback onOpen,
    required VoidCallback onTakeMeThere,
    required VoidCallback onShare,
  }) {
    return showAppDialog<void>(
      context: context,
      builder: (_) => CreationSuccessDialog(
        icon: icon,
        iconColor: iconColor,
        message: message,
        onOpen: onOpen,
        onTakeMeThere: onTakeMeThere,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    }

    return AppDialog(
      backgroundColor: colors.night,
      title: StaggeredEntrance(
        index: 0,
        child: Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.creationSuccessEyebrow),
              const SizedBox(width: 8),
              Icon(icon, color: iconColor, size: 22),
            ],
          ),
        ),
      ),
      content: StaggeredEntrance(
        index: 1,
        child: Text(message),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        StaggeredEntrance(
          index: 2,
          axis: Axis.horizontal,
          child: TextButton.icon(
            onPressed: () => closeThen(onOpen),
            icon: Icon(Icons.open_in_new, size: 18, color: colors.gold),
            label: AppButtonLabel(
              strings.creationSuccessOpenAction,
              color: colors.gold,
            ),
          ),
        ),
        StaggeredEntrance(
          index: 3,
          axis: Axis.horizontal,
          child: TextButton.icon(
            onPressed: () => closeThen(onTakeMeThere),
            icon: Icon(Icons.navigation, size: 18, color: colors.gold),
            label: AppButtonLabel(
              strings.creationSuccessFlyAction,
              color: colors.gold,
            ),
          ),
        ),
        StaggeredEntrance(
          index: 4,
          axis: Axis.horizontal,
          child: TextButton.icon(
            onPressed: () => closeThen(onShare),
            icon: Icon(Icons.share_outlined, size: 18, color: colors.gold),
            label: AppButtonLabel(
              strings.starQuickLookShareAction,
              color: colors.gold,
            ),
          ),
        ),
      ],
    );
  }
}
