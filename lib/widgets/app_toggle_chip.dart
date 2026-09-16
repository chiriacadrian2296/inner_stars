import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// A labelled on/off pill — "All supernovas", "All kinds".
///
/// There used to be two of these, hand-drawn: each painted its own little
/// track and thumb out of `AnimatedContainer`s, with different colors,
/// different track fills and different thumb colors from each other *and*
/// from every real [Switch] in the app. This one wraps a real [Switch], so
/// it inherits the app's single switch theme and can never drift from it
/// again — the pill around it is the only thing this widget actually draws.
///
/// The pill itself lights when on, the same way every other chosen surface
/// does (see [selectableDecoration]).
class AppToggleChip extends StatelessWidget {
  const AppToggleChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.labelColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Overrides the label's color. The one caller that passes this is the
  /// reflection screen, which sits on the Nightlight gradient rather than
  /// on the app's night panel — see [AppColors.nightlightMuted]. Everywhere
  /// else leaves it null and gets the standard treatment.
  final Color? labelColor;

  // Big enough to always resolve to a stadium at this height.
  static const _pillRadius = 999.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Container(
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: selectableDecoration(
            colors,
            selected: value,
            radius: _pillRadius,
            glowSize: 32,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: labelColor ?? colors.text,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 6),
              // Shrunk to sit comfortably inside a pill rather than
              // dominating it; the colors are the theme's, untouched.
              Transform.scale(
                scale: 0.8,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
