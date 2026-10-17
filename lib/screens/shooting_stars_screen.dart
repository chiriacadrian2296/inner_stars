import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import 'placeholder_screen.dart';

/// Explains the shooting star now living directly in the Galaxy. The page
/// remains informational; the interaction itself belongs to the sky element.
class ShootingStarsScreen extends StatelessWidget {
  const ShootingStarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return PlaceholderScreen(
      icon: Icons.auto_fix_high,
      title: strings.menuShootingStars,
      body: strings.shootingStarsBody,
    );
  }
}
