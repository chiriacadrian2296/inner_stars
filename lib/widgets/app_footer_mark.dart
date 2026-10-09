import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// The app's mark at the foot of a long page: the logo above the name in the
/// branding serif, quiet enough not to compete with the content. It also
/// gives a page a bit of empty room at its end, so the last tiles can be
/// scrolled clear of the floating buttons.
class AppFooterMark extends StatelessWidget {
  const AppFooterMark({super.key});

  /// How far the floating action button sits from the bottom of the screen
  /// (see the Sky explorer's `Positioned`): the mark ends at the same height,
  /// so it lines up with the button.
  static const double bottomRoom = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        28,
        0,
        bottomRoom + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The logo's drawing leaves empty margin inside its box (its shapes
          // fill only ~64% of the height, centred): the box is cut short at
          // the bottom so the name sits right under the drawing.
          Align(
            alignment: Alignment.topCenter,
            heightFactor: 0.82,
            child: SvgPicture.asset(
              'assets/icon/Logo.svg',
              width: 44,
              height: 44,
              colorFilter: ColorFilter.mode(colors.muted, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Inner Stars',
            style: TextStyle(
              color: colors.muted,
              fontFamily: kFontBranding,
              fontSize: 16,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
