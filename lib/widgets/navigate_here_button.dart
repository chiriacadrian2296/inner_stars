import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small "take me there" trigger shown wherever the caller can jump the
/// Sky's sky camera to something (the search popup opened from
/// [NebulaScreen], and the star reader) — omitted everywhere else, such as
/// the plain Sky tab, where there's no 3D camera to move.
///
/// The Sky's own "white on navy" look — [SkyScreen]'s quick-access mini
/// menu buttons ([_QuickAccessButton]) and the guided tours' Skip/Back/Next
/// buttons share the identical navy-disc-white-border-white-icon
/// combination — rather than a bespoke treatment of its own, so every
/// "take me there" trigger in the app (cards, tooltips, the star reader)
/// reads as one recognizable control regardless of where it's tapped from.
class NavigateHereButton extends StatelessWidget {
  const NavigateHereButton({
    super.key,
    required this.onTap,
    this.tooltip,
    this.size = 34,
    this.iconSize = 16,
  });

  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = Material(
      color: colors.nightPanel,
      shape: CircleBorder(side: BorderSide(color: Colors.white, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.navigation, size: iconSize, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
