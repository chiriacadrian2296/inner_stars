import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';

/// A feature sketched into the menu ahead of the real thing existing yet —
/// [ShootingStarsScreen] and [FriendsScreen] are both just this with their
/// own icon, title and body. Same header shape as every other standalone
/// screen ([MetaphorScreen], [AreaDetailScreen]): back button, then an
/// eyebrow ([AppStrings.comingSoonBadge], shared across every placeholder)
/// over the real title, so a placeholder never reads as a dead end — it
/// reads as a page that just hasn't been built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.arrow_back, color: colors.muted),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.comingSoonBadge,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                            color: colors.accentDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  StaggeredEntrance(
                    index: 0,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  StaggeredEntrance(
                    index: 1,
                    child: Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.gold.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: colors.gold.withValues(alpha: 0.4),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 38, color: colors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggeredEntrance(
                    index: 2,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
