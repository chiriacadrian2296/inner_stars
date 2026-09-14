import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../audio/audio_service.dart';
import '../l10n/strings_scope.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tutorial_management.dart' show kAllTourNames;
import '../widgets/responsive_content.dart';
import 'sound_lab_screen.dart';

/// A fast, one-page settings panel reached from the Sky's quick-access mini
/// menu (a plain tap on the menu button — see `_QuickAccessFan` in
/// `sky_screen.dart`). Bundles the handful of things people actually reach
/// for often — the background music, the sky's coordinate grid, whether
/// tutorials fire — in one place, instead of scattered across Sound Lab,
/// Settings and their own dedicated top-right button. Deep audio tuning
/// (per-effect sound pickers, the other three volumes) stays in
/// [SoundLabScreen], linked from here rather than duplicated.
class QuickSettingsScreen extends StatefulWidget {
  const QuickSettingsScreen({
    super.key,
    required this.settings,
    required this.audioService,
  });

  final SettingsController settings;
  final AudioService audioService;

  @override
  State<QuickSettingsScreen> createState() => _QuickSettingsScreenState();
}

class _QuickSettingsScreenState extends State<QuickSettingsScreen> {
  Future<void> _toggleBackgroundPlayback() async {
    if (widget.audioService.backgroundPaused) {
      await widget.audioService.resumeBackground();
    } else {
      await widget.audioService.pauseBackground();
    }
    setState(() {});
  }

  Future<void> _setBackgroundVolume(double volume) async {
    await widget.audioService.setBackgroundVolume(volume);
    setState(() {});
  }

  Future<void> _setShowGrid(bool value) async {
    await widget.settings.setShowGrid(value);
  }

  // Same as `_TutorialManagementDialog._replayAllTours` — resets every
  // tour's own completion so it fires again next time its screen opens,
  // then immediately replays `sky-navigation` (the one tour that can't be
  // previewed just by reopening a screen, since `SkyScreen` never gets
  // pushed again). Kept as its own small copy rather than a shared
  // function: nothing else here needs it, and the whole body is a handful
  // of lines built on `kAllTourNames`, already public for exactly this.
  Future<void> _replayAllTours(BuildContext context) async {
    final strings = context.strings;
    final tour = Tour.read(context);
    final storage = tour.storage;
    for (final name in kAllTourNames) {
      await storage.reset(name);
    }
    unawaited(tour.start('sky-navigation', force: true));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.replayToursResult)));
    }
  }

  void _openSoundLab() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SoundLabScreen(audioService: widget.audioService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final paused = widget.audioService.backgroundPaused;

    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) => Scaffold(
        backgroundColor: colors.night,
        body: SafeArea(
          child: ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: colors.muted),
                    ),
                    Text(
                      strings.quickSettingsEyebrow,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  strings.quickSettingsTitle,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel(strings.quickSettingsAudioSection),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: panelDecoration(colors),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleBackgroundPlayback,
                        tooltip: paused
                            ? strings.playBackgroundTrackAction
                            : strings.pauseBackgroundTrackAction,
                        icon: Icon(
                          paused ? Icons.play_arrow : Icons.pause,
                          color: colors.gold,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: EdgeInsets.zero,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: widget.audioService.backgroundVolume,
                            onChanged: _setBackgroundVolume,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(widget.audioService.backgroundVolume * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _openSoundLab,
                    icon: Icon(Icons.graphic_eq, size: 18, color: colors.gold),
                    label: Text(
                      strings.quickSettingsOpenSoundLabAction,
                      style: TextStyle(color: colors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel(strings.skyGridSection),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  child: Container(
                    decoration: panelDecoration(colors),
                    child: SwitchListTile(
                      value: widget.settings.showGrid,
                      onChanged: _setShowGrid,
                      title: Text(
                        strings.skyGridToggleLabel,
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel(strings.tutorialsManagementTitle),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  child: Container(
                    decoration: panelDecoration(colors),
                    child: SwitchListTile(
                      value: widget.settings.tutorialsEnabled,
                      onChanged: (value) =>
                          widget.settings.setTutorialsEnabled(value),
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _replayAllTours(context),
                    icon: Icon(Icons.refresh, size: 18, color: colors.gold),
                    label: Text(
                      strings.replayToursAction,
                      style: TextStyle(color: colors.gold),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.muted,
      ),
    );
  }
}
