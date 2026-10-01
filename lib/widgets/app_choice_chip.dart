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
    this.showCheck = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final bool showCheck;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: icon == null && !showCheck
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (icon != null) ...[
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
        if (showCheck) ...[
          const SizedBox(width: 8),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: selected ? colors.gold : colors.muted,
          ),
        ],
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
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      textAlign: expand ? TextAlign.start : TextAlign.center,
      style: context.typography.controlLabel.copyWith(
        color: selected ? colors.text : colors.muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
