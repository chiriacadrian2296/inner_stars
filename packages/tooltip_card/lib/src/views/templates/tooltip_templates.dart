part of '../views.dart';

/// A collection of pre-built card templates for [TooltipCard.flyoutContent]
/// or [TooltipCard.builder].
///
/// These templates provide professionally designed layouts for common use cases
/// like informational tips, action confirmations, profiles, and menus.
class TooltipTemplate {
  /// Internal constructor to prevent instantiation
  const TooltipTemplate._();

  /// Creates a simple informational card with an icon, title, and message.
  ///
  /// Useful for onboarding tips or feature explanations.
  static Widget info({
    required String title,
    required String content,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onClose,
    Widget? action,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final effectiveIconColor = iconColor ?? colorScheme.primary;

        return IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: effectiveIconColor, size: 20),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (onClose != null)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: onClose,
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            content,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.4,
                            ),
                          ),
                          if (action != null) ...[
                            const SizedBox(height: 12),
                            action,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Creates an action card with primary and optional secondary buttons.
  ///
  /// Useful for confirmations, quick actions, or choices.
  static Widget action({
    required String title,
    required String content,
    required Widget primaryAction,
    Widget? secondaryAction,
    IconData? icon,
    Color? iconColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final effectiveIconColor = iconColor ?? colorScheme.primary;

        return IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: effectiveIconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            content,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Container(
                color: colorScheme.surface.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (secondaryAction != null) ...[
                      secondaryAction,
                      const SizedBox(width: 8),
                    ],
                    primaryAction,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Creates a profile card with avatar, name, subtitle, and stats/actions.
  static Widget profile({
    required String name,
    required String email,
    required ImageProvider avatar,
    Widget? action,
    List<Widget>? bottomActions,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return IntrinsicWidth(
          child: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundImage: avatar),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      ?action,
                    ],
                  ),
                ),
                if (bottomActions != null && bottomActions.isNotEmpty) ...[
                  const Divider(height: 1),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: bottomActions,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Creates a simple menu list.
  ///
  /// Each item can be a [ListTile] or specific widget.
  static Widget menu({required List<Widget> items, Color? backgroundColor}) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  /// Creates a rich content card with an optional header image.
  static Widget rich({
    required String title,
    required String content,
    ImageProvider? image,
    Widget? primaryAction,
    Widget? secondaryAction,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8), // Assuming defaults
                  ),
                  child: Image(
                    image: image,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (primaryAction != null || secondaryAction != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (secondaryAction != null) ...[
                        secondaryAction,
                        const SizedBox(width: 8),
                      ],
                      ?primaryAction,
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Creates a step-by-step tutorial card.
  ///
  /// Features navigation buttons and a progress indicator.
  static Widget tutorial({
    required String title,
    required String content,
    required int currentStep,
    required int totalSteps,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onSkip,
    ImageProvider? image,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: Image(
                    image: image,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step $currentStep of $totalSteps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (onSkip != null)
                          GestureDetector(
                            onTap: onSkip,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (onPrevious != null)
                      TextButton(
                        onPressed: onPrevious,
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    FilledButton(
                      onPressed: onNext,
                      child: Text(
                        currentStep == totalSteps ? 'Finish' : 'Next',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Creates an onboarding checklist card.
  ///
  /// Displays a list of tasks with a progress bar.
  static Widget checklist({
    required String title,
    required List<Widget> items,
    required double progress,
    VoidCallback? onContinue,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final percent = (progress * 100).toInt();

        return SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: items,
                ),
              ),
              if (onContinue != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onContinue,
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Creates a card with illustrated content.
  ///
  /// Layouts text sections on the start side and an image on the end side.
  /// Direction-aware (RTL support).
  static Widget illustrated({
    required List<TooltipSection> sections,
    ImageProvider? image,
    double imageWidth = 120,
    double maxWidth = 400,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textDirection = Directionality.of(context);
        final isRtl = textDirection == TextDirection.rtl;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: image != null ? imageWidth : 0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections
                        .map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Opacity(
                              opacity: section.isDisabled ? 0.38 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (section.title != null) ...[
                                    Text(
                                      section.title!,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (section.content != null)
                                    Text(
                                      section.content!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                            height: 1.5,
                                          ),
                                    ),
                                  if (section.paragraphs != null)
                                    ...section.paragraphs!.map((paragraph) {
                                      final style = theme.textTheme.bodyMedium
                                          ?.copyWith(height: 1.5);
                                      TextStyle? finalStyle;

                                      switch (paragraph.type) {
                                        case TooltipParagraphType.primary:
                                          finalStyle = style?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          );
                                          break;
                                        case TooltipParagraphType.disable:
                                          finalStyle = style?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.38),
                                          );
                                          break;
                                        case TooltipParagraphType.focus:
                                          finalStyle = style?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            backgroundColor: colorScheme
                                                .surfaceContainerHighest,
                                          );
                                          break;
                                        case TooltipParagraphType.normal:
                                          finalStyle = style?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                          );
                                          break;
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsetsDirectional.only(
                                                        end: 8,
                                                      ),
                                                  child: Container(
                                                    width: 4,
                                                    height: 4,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          finalStyle?.color ??
                                                          colorScheme.onSurface,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              TextSpan(text: paragraph.text),
                                            ],
                                          ),
                                          style: finalStyle,
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (image != null)
                Positioned.directional(
                  textDirection: textDirection,
                  top: 0,
                  bottom: 0,
                  end: 0,
                  width: imageWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.horizontal(
                      right: isRtl ? Radius.zero : const Radius.circular(8),
                      left: isRtl ? const Radius.circular(8) : Radius.zero,
                    ),
                    child: Image(image: image, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A section of content for [TooltipTemplate.illustrated].
class TooltipSection {
  const TooltipSection({
    this.title,
    this.content,
    this.paragraphs,
    this.isDisabled = false,
  });

  /// The title of the section.
  final String? title;

  /// Single text content (legacy/simple usage).
  final String? content;

  /// Multiple paragraphs with specific types.
  final List<TooltipParagraph>? paragraphs;

  /// Whether the section is disabled (greyed out).
  final bool isDisabled;
}

/// Types of paragraphs supported in [TooltipTemplate].
enum TooltipParagraphType {
  /// Prominent, colored text (e.g. Primary Color).
  primary,

  /// Standard readable text.
  normal,

  /// Greyed out or disabled text.
  disable,

  /// Highlighted or focused text (e.g. background highlight or bold).
  focus,
}

/// A paragraph of text with a specific semantic type.
class TooltipParagraph {
  const TooltipParagraph({
    required this.text,
    this.type = TooltipParagraphType.normal,
  });

  final String text;
  final TooltipParagraphType type;
}
