part of 'views.dart';

/// Structured TooltipCard content using the GeniusLink/SuperCore visual rhythm.
class TooltipCardContent extends StatelessWidget {
  const TooltipCardContent({
    super.key,
    this.icon,
    this.iconColor,
    double? iconSize,
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.content,
    this.primaryAction,
    this.secondaryAction,
    this.tertiaryAction,
    this.onClose,
    this.showCloseButton = true,
    double? maxWidth,
    EdgeInsets? padding,
    double? spacing,
  }) : _iconSize = iconSize,
       _maxWidth = maxWidth,
       _padding = padding,
       _spacing = spacing;

  final Widget? icon;
  final Color? iconColor;
  final double? _iconSize;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? content;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? tertiaryAction;
  final VoidCallback? onClose;
  final bool showCloseButton;
  final double? _maxWidth;
  final EdgeInsets? _padding;
  final double? _spacing;

  double get iconSize => _iconSize ?? TooltipCardConstants.defaultIconSize;
  double get maxWidth => _maxWidth ?? TooltipCardConstants.defaultMaxWidth;
  EdgeInsets get padding =>
      _padding ?? const EdgeInsets.all(TooltipCardSpacing.lg);
  double get spacing => _spacing ?? TooltipCardSpacing.md;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tooltipTheme = theme.extension<TooltipCardThemeData>();

    final effectiveIconColor =
        iconColor ?? tooltipTheme?.iconColor ?? colorScheme.primary;
    final effectiveIconSize =
        _iconSize ??
        tooltipTheme?.iconSize ??
        TooltipCardConstants.defaultIconSize;
    final effectiveMaxWidth =
        _maxWidth ??
        tooltipTheme?.contentMaxWidth ??
        TooltipCardConstants.defaultMaxWidth;
    final effectivePadding =
        _padding ??
        tooltipTheme?.contentPadding ??
        const EdgeInsets.all(TooltipCardSpacing.lg);
    final effectiveSpacing =
        _spacing ?? tooltipTheme?.contentSpacing ?? TooltipCardSpacing.md;
    final effectiveActionSpacing =
        tooltipTheme?.actionSpacing ?? TooltipCardSpacing.sm;
    final effectiveTitleStyle =
        titleStyle ??
        tooltipTheme?.titleStyle ??
        textTheme.titleMedium?.copyWith(
          fontFamily: TooltipCardDesignTokens.bodyFont,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );
    final effectiveSubtitleStyle =
        subtitleStyle ??
        tooltipTheme?.subtitleStyle ??
        textTheme.bodyMedium?.copyWith(
          fontFamily: TooltipCardDesignTokens.bodyFont,
          fontSize: 14,
          height: 1.45,
          color: colorScheme.onSurfaceVariant,
        );
    final effectiveContentStyle =
        tooltipTheme?.contentTextStyle ??
        textTheme.bodyMedium?.copyWith(
          fontFamily: TooltipCardDesignTokens.bodyFont,
          fontSize: 14,
          height: 1.45,
          color: colorScheme.onSurface,
        ) ??
        const TextStyle();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: Padding(
        padding: effectivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: IconTheme(
                      data: IconThemeData(
                        color: effectiveIconColor,
                        size: effectiveIconSize,
                      ),
                      child: icon!,
                    ),
                  ),
                  SizedBox(width: effectiveSpacing),
                ],
                Expanded(child: Text(title, style: effectiveTitleStyle)),
                if (showCloseButton && onClose != null) ...[
                  const SizedBox(width: TooltipCardSpacing.sm),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          TooltipCardDesignTokens.radiusControl,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: TooltipCardSpacing.xs),
              Text(subtitle!, style: effectiveSubtitleStyle),
            ],
            if (content != null) ...[
              SizedBox(height: effectiveSpacing),
              DefaultTextStyle(
                style: effectiveContentStyle,
                child: content!,
              ),
            ],
            if (primaryAction != null ||
                secondaryAction != null ||
                tertiaryAction != null) ...[
              const SizedBox(height: TooltipCardSpacing.lg),
              _buildActions(effectiveActionSpacing),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(double actionSpacing) {
    final actions = <Widget>[];
    if (primaryAction != null) actions.add(Expanded(child: primaryAction!));
    if (secondaryAction != null) {
      if (actions.isNotEmpty) actions.add(SizedBox(width: actionSpacing));
      actions.add(Expanded(child: secondaryAction!));
    }
    if (tertiaryAction != null) {
      if (actions.isNotEmpty) actions.add(SizedBox(width: actionSpacing));
      actions.add(tertiaryAction!);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}
