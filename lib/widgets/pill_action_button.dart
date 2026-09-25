import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// A small gold pill for a secondary action — undo/redo, or a destructive
/// one like delete. Originally local to the constellation shape editor
/// (`_EditorActionButton`), promoted here so every save/delete pairing in
/// the app (the shape editor, the star form, ...) shares the exact same
/// look instead of each screen growing its own button shape — see
/// [SaveActionButton]'s own doc comment for the primary-action half of
/// that pairing.
class PillActionButton extends StatelessWidget {
  const PillActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// True for the destructive one of a pair (delete) — swaps the usual
  /// gold fill for [AppColors.dangerBackground] and the icon/text for
  /// [AppColors.danger] itself, so it reads as "this one does something
  /// you can't undo" rather than blending in as just another enabled
  /// action.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final foreground = !enabled
        ? colors.muted
        : (danger ? colors.danger : colors.onGold);

    return Material(
      color: enabled
          ? (danger ? colors.dangerBackground : colors.gold)
          : colors.nightBorder,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary "save" action at the bottom of a form — save a constellation
/// shape, save a star, create a project. One shared widget so every save
/// button in the app is literally the same button: dark and flat while
/// [lit] is false, gold and glowing the moment it's true — you light it
/// the same way you light a star, same philosophy `AppActionDisc` (now
/// parked, see that file's own doc comment) already had, just carried over
/// to this pill shape instead of a round FAB so it reads as one family with
/// [PillActionButton]'s delete/undo/redo pills rather than a visually
/// unrelated control.
///
/// [onPressed] stays callable even while [lit] is false (same reasoning as
/// `AppActionDisc`) so a screen can use the tap to explain *why* it can't
/// save yet, rather than the button sitting there inert.
class SaveActionButton extends StatelessWidget {
  const SaveActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.lit = true,
    this.icon = Icons.check,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool lit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = lit ? colors.onGold : colors.muted;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusPill),
        boxShadow: lit ? goldGlow(colors, strength: 1.1, size: 56) : null,
      ),
      child: Material(
        color: lit ? colors.gold : colors.nightBorder,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
