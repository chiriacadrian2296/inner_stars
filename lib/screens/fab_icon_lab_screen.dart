import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/icon_with_new_badge.dart';

/// Lab for choosing the icon of Sky's add button: every candidate drawn as a
/// stand-in for that button (navy disc, gold rim, gold glyph), side by side.
class FabIconLabScreen extends StatelessWidget {
  const FabIconLabScreen({super.key});

  static const _candidates = <(String, IconData)>[
    ('rocket_launch', Icons.rocket_launch),
    ('bolt', Icons.bolt),
    ('filter_none', Icons.filter_none),
    ('photo_filter', Icons.photo_filter),
    ('auto_awesome_motion', Icons.auto_awesome_motion),
    ('gradient', Icons.gradient),
    ('burst_mode', Icons.burst_mode),
    ('filter_b_and_w', Icons.filter_b_and_w),
    ('local_activity', Icons.local_activity),
    ('local_police', Icons.local_police),
    ('web_asset + NEW', Icons.web_asset),
    ('featured_play_list', Icons.featured_play_list),
    ('call_to_action', Icons.call_to_action),
    ('video_label', Icons.video_label),
    ('art_track', Icons.art_track),
    ('star_half', Icons.star_half),
    ('edit_note', Icons.edit_note),
    ('post_add', Icons.post_add),
    ('brightness_5', Icons.brightness_5),
    ('brightness_medium', Icons.brightness_medium),
    ('light_mode', Icons.light_mode),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.night,
      appBar: AppBar(title: const Text('FAB icon lab')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              for (final (name, icon) in _candidates)
                _Candidate(
                  name: name,
                  icon: icon,
                  withNew: name.contains('NEW'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.name,
    required this.icon,
    required this.withNew,
  });

  final String name;
  final IconData icon;

  /// Draws a small "NEW" under the glyph, as the create buttons do.
  final bool withNew;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          // Same look as the Sky add button: navy, gold rim, gold glyph.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.night,
              border: Border.all(color: colors.gold, width: 2),
            ),
            child: Center(
              child: withNew
                  ? IconWithNewBadge(icon: icon, size: 24, color: colors.gold)
                  : Icon(icon, color: colors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
