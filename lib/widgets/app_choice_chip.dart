import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';

/// Canonical selectable surface for filters and mutually exclusive choices.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.leading,
    this.expand = false,
    this.dense = false,
  });

  /// Smaller footprint for tool panels with many options.
  final bool dense;

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: icon == null && leading == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (icon != null || leading != null) ...[
          leading ??
              Icon(
                icon,
                size: 16,
                color: iconColor ?? (selected ? colors.gold : colors.muted),
              ),
          const SizedBox(width: 8),
        ],
        if (expand)
          Expanded(child: _label(context))
        else
          Flexible(child: _label(context)),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            constraints: BoxConstraints(minHeight: dense ? 32 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 14,
              vertical: dense ? 5 : 12,
            ),
            decoration: selectableDecoration(colors, selected: selected),
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    final colors = context.colors;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // An expanded text-only choice still reads as a centered button.
      // Choices with a leading icon keep their label aligned beside it
      // instead.
      textAlign: expand && (icon != null || leading != null)
          ? TextAlign.start
          : TextAlign.center,
      style: context.typography.controlLabel.copyWith(
        fontSize: dense ? 12 : null,
        color: selected ? colors.text : colors.muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
