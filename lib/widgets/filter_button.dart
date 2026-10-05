import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// A filter trigger for the Constellations/Stars views — inline beside the
/// search field on a wide layout, or collected onto FiltersSheet behind
/// FiltersTriggerButton on a narrow one. Opens [showAreaFilterSheet],
/// [showKindFilterSheet], [showDateRangeFilterSheet], or
/// [showSortFilterSheet] depending on [icon]/[onTap]. [label] carries the
/// current state right on the button's
/// own face (a neutral prompt while nothing's narrowed, a summary like "2
/// areas", the actual span "15/06 - 03/07", or "Intensity ↓" once something
/// is), so there's no need to open the sheet just to
/// see what's already set. Gold-highlighted whenever [active], same "lit vs
/// dark" rule as everywhere else that state is shown this way.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.icon,
    required this.active,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final bool active;
  final String label;
  final String tooltip;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: horizontal ? 12 : 4),
            decoration: selectableDecoration(colors, selected: active),
            child: Flex(
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? colors.gold : colors.muted,
                ),
                SizedBox(width: horizontal ? 8 : 0, height: horizontal ? 0 : 2),
                Flexible(
                  child: AppButtonLabel(
                    label,
                    color: active ? colors.text : colors.muted,
                    fontSize: horizontal ? 11 : 9.5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: horizontal ? TextAlign.start : TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
