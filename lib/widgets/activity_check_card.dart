import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';

/// The compact activity row shared by statistics and daily management.
class ActivityCheckCard extends StatelessWidget {
  const ActivityCheckCard({
    super.key,
    required this.icon,
    required this.title,
    required this.lit,
    this.actionLit,
    this.subtitle,
    this.onTap,
    this.figures,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool lit;
  final bool? actionLit;
  final VoidCallback? onTap;
  final Widget? figures;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceMd,
              vertical: kSpaceMd - 2,
            ),
            child: Row(
              children: [
                Icon(icon, color: lit ? colors.gold : colors.muted, size: 22),
                const SizedBox(width: kSpaceSm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: lit ? colors.text : colors.muted,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.supporting.copyWith(
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (figures != null) ...[
                  const SizedBox(width: kSpaceSm + 2),
                  figures!,
                ],
                if (actionIcon != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: actionLabel,
                    onPressed: onAction,
                    icon: Icon(
                      actionIcon,
                      color: (actionLit ?? lit) ? colors.gold : colors.muted,
                    ),
                  ),
                ] else if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: colors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
