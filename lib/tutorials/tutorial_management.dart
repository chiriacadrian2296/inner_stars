import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../l10n/strings_scope.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/staggered_entrance.dart';

/// Every `hint_kit` tour name currently built — see `lib/tutorials/`. Kept
/// in one place so [_replayAllTours] has a single list to update whenever a
/// new tour is added.
const List<String> kAllTourNames = [
  'sky-navigation',
  'star-form',
  'search-stars',
  'light-your-sky',
  'constellation-form',
  'supernova-vision',
];

/// The Sky's "Tutorials" popup — an on/off switch for every guided tour in
/// the app, plus a reset button, opened from a dedicated button on the Sky
/// itself (same pattern as the Sound Lab button).
///
/// Moved here from Settings (see the project's own history): the switch is
/// the actual fix for "tutorials fire once and then I have to reset to see
/// them again" — with `PrefsTourStorage` gating on
/// [SettingsController.tutorialsEnabled], leaving it off means no tour ever
/// auto-starts, and turning it back on lets every not-yet-seen tour run
/// normally the next time its screen opens. The reset button stays useful
/// on top of that for one specific case: forcing `sky-navigation` to run
/// again to check the *home* screen's own tour, which can't be previewed by
/// just reopening a screen the way every other tour can (`SkyScreen` never
/// gets pushed again, so its `initState` never reruns) — see [_replayAllTours].
Future<void> showTutorialManagementDialog(
  BuildContext context, {
  required SettingsController settings,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => _TutorialManagementDialog(settings: settings),
  );
}

class _TutorialManagementDialog extends StatelessWidget {
  const _TutorialManagementDialog({required this.settings});

  final SettingsController settings;

  Future<void> _replayAllTours(BuildContext context) async {
    final strings = context.strings;
    final tour = Tour.read(context);
    final storage = tour.storage;
    for (final name in kAllTourNames) {
      await storage.reset(name);
    }
    // `force: true` — without it this would silently no-op whenever
    // `tutorialsEnabled` is off, since `PrefsTourStorage.isCompleted`
    // treats every tour as already-completed in that state on purpose.
    // Forcing is exactly right here: this button's whole job is "show me
    // sky-navigation right now regardless of the switch above".
    unawaited(tour.start('sky-navigation', force: true));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.replayToursResult)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggeredEntrance(
                index: 0,
                child: Text(
                  strings.tutorialsManagementTitle,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredEntrance(
                index: 1,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  child: Container(
                    decoration: panelDecoration(colors),
                    child: SwitchListTile(
                      value: settings.tutorialsEnabled,
                      onChanged: (value) => settings.setTutorialsEnabled(value),
                      title: Text(
                        strings.tutorialsEnabledLabel,
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                      subtitle: Text(
                        strings.tutorialsEnabledDescription,
                        style: TextStyle(color: colors.muted, fontSize: 12.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredEntrance(
                index: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _replayAllTours(context),
                    icon: Icon(Icons.refresh, size: 18, color: colors.gold),
                    label: Text(
                      strings.replayToursAction,
                      style: TextStyle(color: colors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              StaggeredEntrance(
                index: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      strings.gotIt,
                      style: TextStyle(color: colors.muted),
                    ),
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
