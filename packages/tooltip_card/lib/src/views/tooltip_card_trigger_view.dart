part of 'views.dart';

/// Trigger view responsible only for translating Flutter input events into
/// controller commands.
class TooltipCardTriggerView extends StatelessWidget {
  const TooltipCardTriggerView({
    super.key,
    required this.targetKey,
    required this.child,
    required this.triggers,
    required this.isOpen,
    required this.onToggle,
    required this.onOpen,
    required this.onClose,
    required this.onHoverChanged,
  });

  final GlobalKey targetKey;
  final Widget child;
  final Set<WhenContentVisible> triggers;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<bool> onHoverChanged;

  bool get _usesHover => triggers.contains(WhenContentVisible.hoverButton);

  @override
  Widget build(BuildContext context) {
    final trigger = Semantics(
      button: true,
      enabled: true,
      expanded: isOpen,
      label: 'Tooltip trigger, ${isOpen ? 'expanded' : 'collapsed'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: triggers.contains(WhenContentVisible.pressButton)
            ? onToggle
            : null,
        onDoubleTap: triggers.contains(WhenContentVisible.doubleTapButton)
            ? onToggle
            : null,
        onSecondaryTap:
            triggers.contains(WhenContentVisible.secondaryTapButton)
            ? onToggle
            : null,
        onLongPress: triggers.contains(WhenContentVisible.longPressButton)
            ? onToggle
            : null,
        onLongPressUp:
            triggers.contains(WhenContentVisible.longPressUpButton)
            ? onToggle
            : null,
        onForcePressStart:
            triggers.contains(WhenContentVisible.forcePressButton)
            ? (_) => onToggle()
            : null,
        child: Focus(
          onKeyEvent: (node, event) {
            if (isOpen && event.logicalKey == LogicalKeyboardKey.escape) {
              onClose();
              return KeyEventResult.handled;
            }
            if (!isOpen &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              onOpen();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: child,
        ),
      ),
    );

    if (!_usesHover) {
      return SizedBox(key: targetKey, child: trigger);
    }

    return MouseRegion(
      key: targetKey,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: trigger,
    );
  }
}
