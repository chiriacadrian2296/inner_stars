import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_style.dart';

/// The Nightlight section's own "white on navy" look for its filled
/// buttons — plain white text on a navy fill with a white ring, instead of
/// the app's usual gold-on-navy. This section is deliberately styled a bit
/// outside the rest of the app (see `nightlight_gate_screen.dart`'s own doc
/// comment), the same "white on navy" pattern already used informally
/// elsewhere (e.g. `navigate_here_button.dart`). [kBorderWidthActive]
/// matches the app's own "active" border weight so these don't read as
/// thinner just for being a different color.
ButtonStyle nightlightButtonStyle(AppColors colors) => ElevatedButton.styleFrom(
  backgroundColor: colors.nightPanel,
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white, width: kBorderWidthActive),
);

/// The same look, outlined rather than filled — for the section's
/// secondary actions.
ButtonStyle nightlightOutlinedButtonStyle(AppColors colors) =>
    OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white, width: kBorderWidthActive),
    );

/// ...and for a plain text button (the breathing screen's skip action).
ButtonStyle nightlightTextButtonStyle(AppColors colors) =>
    TextButton.styleFrom(foregroundColor: Colors.white);
