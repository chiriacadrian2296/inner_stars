import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_style.dart';

/// Bigger than the app's own default button padding (22h/14v, see
/// `app_theme.dart`'s `elevatedButtonTheme`) — shared by all three
/// functions below so every button in this section reads as the same
/// chunkier size, deliberately, rather than each button here sizing to its
/// own label's width like the rest of the app does.
const EdgeInsets _kNightlightButtonPadding = EdgeInsets.symmetric(
  horizontal: 32,
  vertical: 20,
);

/// The Nightlight section's own "white on navy" look for its primary,
/// filled buttons — plain white text on a navy fill with a white ring,
/// instead of the app's usual gold-on-navy. This section is deliberately
/// styled a bit outside the rest of the app (see
/// `nightlight_gate_screen.dart`'s own doc comment), the same "white on
/// navy" pattern already used informally elsewhere (e.g.
/// `navigate_here_button.dart`). [kBorderWidthActive] matches the app's own
/// "active" border weight so these don't read as thinner just for being a
/// different color. [colors.nightBorder] — a lighter navy — rather than
/// [colors.night]: on the gate screen's two stacked options this is the
/// top/primary one, [nightlightOutlinedButtonStyle]'s darker fill the one
/// below it, so the pair reads as a deliberate light-to-dark step rather
/// than two arbitrarily-different navies. Solid rather than transparent so
/// the animated starfield behind it never shows through. [elevation]/
/// [shadowColor] are overridden to plain and transparent — the app theme's
/// own `ElevatedButtonThemeData` default (see `app_theme.dart`) casts a
/// gold shadow meant for the app's usual gold-filled buttons, which read as
/// a stray gold glow around this section's own white-on-navy ones.
ButtonStyle nightlightButtonStyle(AppColors colors) => ElevatedButton.styleFrom(
  backgroundColor: colors.nightBorder,
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white, width: kBorderWidthActive),
  elevation: 0,
  shadowColor: Colors.transparent,
  padding: _kNightlightButtonPadding,
);

/// The same look, outlined rather than filled and with a darker navy fill
/// — for the section's secondary actions (see [nightlightButtonStyle]'s own
/// doc comment for why [colors.night] specifically).
ButtonStyle nightlightOutlinedButtonStyle(AppColors colors) =>
    OutlinedButton.styleFrom(
      backgroundColor: colors.night,
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white, width: kBorderWidthActive),
      padding: _kNightlightButtonPadding,
    );

/// ...and for a plain text button (the breathing screen's skip action) —
/// still a solid fill and a white ring rather than the app's usual bare
/// text, for the same reason as the other two.
ButtonStyle nightlightTextButtonStyle(AppColors colors) => TextButton.styleFrom(
  backgroundColor: colors.nightPanel,
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white, width: kBorderWidthActive),
  padding: _kNightlightButtonPadding,
);
