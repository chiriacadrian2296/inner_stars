import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';

/// A feature sketched into the menu ahead of the real thing existing yet —
/// [ShootingStarsScreen] and [FriendsScreen] are both just this with their
/// own icon, title and body. It deliberately has no app bar: the title is
/// part of the page content, like the other immersive destinations.
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
