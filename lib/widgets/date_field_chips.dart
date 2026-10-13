import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/sky_date_field.dart';
import '../theme/app_motion.dart';
import '../utils/app_modals.dart';
import 'app_choice_chip.dart';

/// The "Date Type" section shared by every sheet that filters or sorts by a
/// date: a sheet-style title, then one chip per [fields] entry sharing the
/// row's full width — the same look as the week/month/year chips of the
/// date-range sheet. Renders nothing when there is nothing to choose
/// between.
///
/// [visible] shows or hides the section with an animation: the space it
/// takes opens or closes (so the sheet around it rises or falls with it)
/// while the title and chips rise in one after another, or sink out the
/// same way.
class DateFieldChips extends StatefulWidget {
  const DateFieldChips({
    super.key,
    required this.fields,
    required this.selected,
    required this.onChanged,
    this.visible = true,
  });

  final List<SkyDateField> fields;
  final SkyDateField selected;
  final ValueChanged<SkyDateField> onChanged;
  final bool visible;

  @override
  State<DateFieldChips> createState() => _DateFieldChipsState();
}

class _DateFieldChipsState extends State<DateFieldChips>
    with SingleTickerProviderStateMixin {
  // Fraction of the run each piece waits for its turn, and how much of the
  // run it takes to move; the title is piece 0, the chips follow.
  static const _stagger = 0.12;
  static const _span = 0.5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(DateFieldChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Rises [child] from below into place when its turn comes in the run
  /// (piece [index]); played backwards it sinks out the same way.
  Widget _piece(int index, Widget child) {
    final start = (index * _stagger).clamp(0.0, 1.0 - _span);
    final progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, start + _span, curve: kMotionEnter),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(progress),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.length < 2) return const SizedBox.shrink();
    final strings = context.strings;
    return IgnorePointer(
      ignoring: !widget.visible,
      child: SizeTransition(
        alignment: Alignment.topCenter,
        sizeFactor: CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _piece(0, AppSheetTitle(strings.dateFieldSectionTitle)),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < widget.fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _piece(
                        i + 1,
                        AppChoiceChip(
                          label: widget.fields[i].label(strings),
                          selected: widget.fields[i] == widget.selected,
                          onPressed: () => widget.onChanged(widget.fields[i]),
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
