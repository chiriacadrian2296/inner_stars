import '../data/moodboard_repository.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_lock_repository.dart';
import '../data/area_vision_repository.dart';
import '../data/audio_settings_repository.dart';
import '../data/biometric_auth_service.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/legacy_constellation_migration.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../debug/seed_data.dart';
import '../l10n/strings_scope.dart';
import '../notifications/reminder_service.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/apk_download_prompt.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import 'onboarding_screen.dart';
import 'pin_setup_screen.dart';

/// Parks this screen's "Replay onboarding" debug button — see
/// `main.dart`'s own `_kShowOnboarding` doc comment for why. Left wired up
/// (`OnboardingScreen` and the `_push` call are both untouched), just not
/// drawn.
const _kShowOnboarding = false;

/// Settings, opened from the Sky's own side menu — the drawer carries only
/// one entry for it, everything else here is a section of this one page.
/// Profile & Account, Customization, Passkey and Social are all sketched
/// in ahead of the systems behind them existing (see [_PlaceholderPanel]);
/// Language and the daily reminder are the two that actually work today.
/// A short "about" card (name, version, tagline) closes out the page's own
/// content, with a dev tools section (seed/reset data, onboarding replay
/// — shown in every build, not just debug ones) beneath it. The metaphor guide
/// and onboarding replay live in the menu's own Info section instead —
/// places to *go*, unlike "about", which is a fact about the app rather
/// than a page with anything to do on it. Reads/writes through
/// [SettingsController], which persists each change immediately.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.appLockRepository,
    required this.biometricAuthService,
    required this.starRepository,
    required this.projectRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.audioSettingsRepository,
    required this.reminderService,
  });

  final SettingsController settings;
  final AppLockRepository appLockRepository;
  final BiometricAuthService biometricAuthService;
  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  // Kept only for the reset-all-data action's own `.clear()` call — the
  // sound section itself moved to `SoundLabScreen`.
  final AudioSettingsRepository audioSettingsRepository;
  final ReminderService reminderService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.biometricAuthService.isAvailable().then((available) {
      if (mounted) setState(() => _biometricAvailable = available);
    });
  }

  Future<void> _setAppLockEnabled(bool enabled) async {
    if (enabled) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            appLockRepository: widget.appLockRepository,
            biometricAuthService: widget.biometricAuthService,
          ),
        ),
      );
      if (created == true && mounted) setState(() {});
      return;
    }

    // Turning it off needs the same proof of identity turning it on would
    // have needed to change — otherwise anyone picking up an unlocked
    // phone could switch it off in a few taps.
    final verified = await _verifyIdentity();
    if (!verified) return;
    await widget.appLockRepository.disable();
    if (mounted) setState(() {});
  }

  Future<void> _setBiometricEnabled(bool value) async {
    await widget.appLockRepository.setBiometricEnabled(value);
    if (mounted) setState(() {});
  }

  Future<void> _changePin() async {
    final verified = await _verifyIdentity();
    if (!verified || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          appLockRepository: widget.appLockRepository,
          biometricAuthService: widget.biometricAuthService,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// PIN (via [PinSetupScreen] in "verify current" mode), with a
  /// biometric shortcut first when one's enabled — the same proof asked
  /// for disabling the lock or changing its PIN.
  Future<bool> _verifyIdentity() async {
    if (widget.appLockRepository.biometricEnabled) {
      final strings = context.strings;
      final ok = await widget.biometricAuthService.authenticate(
        reason: strings.appLockBiometricReason,
        title: strings.appLockBiometricReason,
        cancelLabel: strings.cancel,
      );
      if (ok) return true;
    }
    if (!mounted) return false;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          appLockRepository: widget.appLockRepository,
          biometricAuthService: widget.biometricAuthService,
          requireCurrentPin: true,
          verifyOnly: true,
        ),
      ),
    );
    return verified == true;
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    final strings = context.strings;

    if (enabled) {
      final granted = await widget.reminderService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.notificationPermissionDenied)),
          );
        }
        return;
      }
      // Best-effort: sends the user to the system settings screen for the
      // "Alarms & reminders" permission so the reminder can fire at the
      // exact minute instead of an OS-batched approximation. There's no
      // callback for whether they actually granted it — scheduleUpcoming
      // below re-checks and adapts either way.
      await widget.reminderService.requestExactAlarmPermission();
      await widget.settings.setReminder(
        enabled: true,
        hour: widget.settings.reminderHour,
        minute: widget.settings.reminderMinute,
      );
      await widget.reminderService.scheduleUpcoming(
        hour: widget.settings.reminderHour,
        minute: widget.settings.reminderMinute,
        title: strings.reminderNotificationTitle,
        bodies: strings.reminderNotificationBodies,
      );
    } else {
      await widget.settings.setReminder(
        enabled: false,
        hour: widget.settings.reminderHour,
        minute: widget.settings.reminderMinute,
      );
      await widget.reminderService.cancel();
    }
    if (mounted) setState(() {});
  }

  Future<void> _setShowGrid(bool value) async {
    await widget.settings.setShowGrid(value);
    if (mounted) setState(() {});
  }

  Future<void> _pickReminderTime() async {
    final strings = context.strings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: widget.settings.reminderHour,
        minute: widget.settings.reminderMinute,
      ),
    );
    if (picked == null) return;

    await widget.settings.setReminder(
      enabled: true,
      hour: picked.hour,
      minute: picked.minute,
    );
    await widget.reminderService.scheduleUpcoming(
      hour: picked.hour,
      minute: picked.minute,
      title: strings.reminderNotificationTitle,
      bodies: strings.reminderNotificationBodies,
    );
    if (mounted) setState(() {});
  }

  Future<void> _sendTestNotification() async {
    final strings = context.strings;

    // The reminder toggle being on doesn't guarantee the permission still
    // holds — Android can auto-revoke an unused permission, or the user can
    // turn it off again in system settings, without the app finding out.
    // Re-checking here (same as _setReminderEnabled does) is what actually
    // makes this button reliable instead of silently doing nothing.
    final granted = await widget.reminderService.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.notificationPermissionDenied)),
        );
      }
      return;
    }

    final bodies = strings.reminderNotificationBodies;
    final body = bodies[DateTime.now().millisecondsSinceEpoch % bodies.length];

    // No in-app confirmation on top of the notification itself — the
    // notification appearing already is the confirmation.
    await widget.reminderService.showNow(
      title: strings.reminderNotificationTitle,
      body: body,
    );
  }

  Future<void> _seedSampleData() async {
    final strings = context.strings;
    await seedSampleData(
      starRepository: widget.starRepository,
      projectRepository: widget.projectRepository,
      habitRepository: widget.habitRepository,
      habitCompletionRepository: widget.habitCompletionRepository,
      languageCode: widget.settings.locale,
    );
    // seedSampleData still creates projects the old way (iconSlug only) —
    // this backfills them with a real constellation immediately, instead of
    // leaving them shapeless until the next app launch.
    await backfillMissingConstellations(
      projectRepository: widget.projectRepository,
      starsShapeRepository: widget.starsShapeRepository,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.seedSampleDataResult(winsPerSeedTap))),
      );
    }
  }

  Future<void> _resetAllData() async {
    final colors = context.colors;
    final strings = context.strings;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.resetAllDataConfirmTitle),
        content: Text(strings.resetAllDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(strings.deleteEverything),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.starRepository.clear();
    await widget.projectRepository.clear();
    await widget.habitRepository.clear();
    await widget.habitCompletionRepository.clear();
    await widget.starsShapeRepository.clear();
    await (await MoodboardRepository.create()).clear();
    await widget.areaVisionRepository.clear();
    await widget.reflectionAnswerRepository.clear();
    await widget.audioSettingsRepository.clear();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.allDataCleared)));
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          // The scrollable itself spans the full window width (so its
          // auto-attached Scrollbar sits at the true page edge on wide
          // viewports); only its content is capped/centered.
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          strings.settingsEyebrow,
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
                      strings.settingsTitle,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 1,
                    child: _SectionLabel(strings.profileSection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 1,
                    child: _PlaceholderPanel(
                      icon: Icons.person_outline,
                      body: strings.profilePlaceholderBody,
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 2,
                    child: _SectionLabel(strings.languageSection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 2,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'en',
                          label: StaggeredEntrance(
                            index: 0,
                            axis: Axis.horizontal,
                            child: Text(strings.languageEnglish),
                          ),
                        ),
                        ButtonSegment(
                          value: 'it',
                          label: StaggeredEntrance(
                            index: 1,
                            axis: Axis.horizontal,
                            child: Text(strings.languageItalian),
                          ),
                        ),
                        ButtonSegment(
                          value: 'ro',
                          label: StaggeredEntrance(
                            index: 2,
                            axis: Axis.horizontal,
                            child: Text(strings.languageRomanian),
                          ),
                        ),
                      ],
                      selected: {widget.settings.locale},
                      onSelectionChanged: (selection) => setState(() {
                        widget.settings.setLocale(selection.first);
                      }),
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 3,
                    child: _SectionLabel(strings.reminderSection),
                  ),
                  const SizedBox(height: 4),
                  StaggeredEntrance(
                    index: 3,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      child: Container(
                        decoration: panelDecoration(colors),
                        child: Column(
                          children: [
                            StaggeredEntrance(
                              index: 0,
                              child: SwitchListTile(
                                value: widget.settings.reminderEnabled,
                                onChanged: _setReminderEnabled,
                                title: Text(
                                  strings.reminderToggleLabel,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.settings.reminderEnabled) ...[
                              StaggeredEntrance(
                                index: 1,
                                child: ListTile(
                                  onTap: _pickReminderTime,
                                  title: Text(
                                    strings.reminderTimeLabel,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Text(
                                    TimeOfDay(
                                      hour: widget.settings.reminderHour,
                                      minute: widget.settings.reminderMinute,
                                    ).format(context),
                                    style: TextStyle(
                                      color: colors.gold,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              StaggeredEntrance(
                                index: 2,
                                child: ListTile(
                                  onTap: _sendTestNotification,
                                  title: Text(
                                    strings.testNotificationButton,
                                    style: TextStyle(
                                      color: colors.gold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  leading: Icon(
                                    Icons.notifications_active_outlined,
                                    color: colors.gold,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 4,
                    child: _SectionLabel(strings.skyGridSection),
                  ),
                  const SizedBox(height: 4),
                  StaggeredEntrance(
                    index: 4,
                    child: Material(
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
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 5,
                    child: _SectionLabel(strings.appLockSection),
                  ),
                  const SizedBox(height: 4),
                  StaggeredEntrance(
                    index: 5,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      child: Container(
                        decoration: panelDecoration(colors),
                        child: Column(
                          children: [
                            StaggeredEntrance(
                              index: 0,
                              child: SwitchListTile(
                                value: widget.appLockRepository.isEnabled,
                                onChanged: _setAppLockEnabled,
                                title: Text(
                                  strings.appLockToggleLabel,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.appLockRepository.isEnabled) ...[
                              if (_biometricAvailable)
                                StaggeredEntrance(
                                index: 1,
                                child: SwitchListTile(
                                    value:
                                        widget.appLockRepository.biometricEnabled,
                                    onChanged: _setBiometricEnabled,
                                    title: Text(
                                      strings.appLockBiometricToggleLabel,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ),
                              StaggeredEntrance(
                                index: 2,
                                child: ListTile(
                                  onTap: _changePin,
                                  title: Text(
                                    strings.appLockChangePinLabel,
                                    style: TextStyle(
                                      color: colors.gold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  leading: Icon(
                                    Icons.password_outlined,
                                    color: colors.gold,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 6,
                    child: _SectionLabel(strings.customizationSection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 6,
                    child: _PlaceholderPanel(
                      icon: Icons.palette_outlined,
                      body: strings.customizationPlaceholderBody,
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 7,
                    child: _SectionLabel(strings.passkeySection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 7,
                    child: _PlaceholderPanel(
                      icon: Icons.key_outlined,
                      body: strings.passkeyPlaceholderBody,
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 8,
                    child: _SectionLabel(strings.socialSection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 8,
                    child: _PlaceholderPanel(
                      icon: Icons.groups_outlined,
                      body: strings.socialPlaceholderBody,
                    ),
                  ),
                  const SizedBox(height: 28),

                  StaggeredEntrance(
                    index: 9,
                    child: _SectionLabel(strings.aboutSection),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntrance(
                    index: 9,
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.data?.version;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: panelDecoration(colors),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StaggeredEntrance(
                                index: 0,
                                child: Text(
                                  'Inner Stars',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontFamily: kFontBranding,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (version != null) ...[
                                const SizedBox(height: 4),
                                StaggeredEntrance(
                                  index: 1,
                                  child: Text(
                                    strings.aboutVersion(version),
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              StaggeredEntrance(
                                index: 2,
                                child: Text(
                                  strings.aboutTagline,
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              // Web only: this build IS the browser tab
                              // someone's looking at, and the "Install"
                              // prompt Chrome/Safari offer here installs
                              // *this* (a PWA), not the real Android app —
                              // easy to mistake for one another. Points at
                              // the actual .apk instead of trying to
                              // suppress that prompt, so both stay available
                              // rather than this fix breaking PWA install
                              // for whoever actually wants it.
                              if (kIsWeb) ...[
                                const SizedBox(height: 14),
                                Divider(color: colors.nightBorder, height: 1),
                                const SizedBox(height: 14),
                                StaggeredEntrance(
                                  index: 3,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.android,
                                        color: colors.gold,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          strings.downloadApkBannerBody,
                                          style: TextStyle(
                                            color: colors.muted,
                                            fontSize: 13,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StaggeredEntrance(
                                  index: 4,
                                  child: OutlinedButton.icon(
                                    onPressed: openApkDownload,
                                    icon: const Icon(Icons.download, size: 18),
                                    label: Text(strings.downloadApkAction),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Dev tooling (seed/reset data) — shown in every build,
                  // debug and release alike, so it stays available for
                  // hands-on testing on a release install too, not just in
                  // a debug build. Each button carries its own panel
                  // background (see [_debugButtonStyle]) so it reads as
                  // tappable rather than as a stray line of text; each is
                  // [Expanded] so together they fill the row edge to edge
                  // instead of leaving empty space beside them.
                  ...[
                    const SizedBox(height: 28),
                    StaggeredEntrance(
                      index: 10,
                      child: _SectionLabel(strings.dataSection),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StaggeredEntrance(
                            index: 10,
                            axis: Axis.horizontal,
                            child: TextButton.icon(
                              onPressed: _seedSampleData,
                              style: _debugButtonStyle(colors, colors.muted),
                              icon: Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: colors.muted,
                              ),
                              label: Text(
                                strings.seedSampleData,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StaggeredEntrance(
                            index: 11,
                            axis: Axis.horizontal,
                            child: TextButton.icon(
                              onPressed: _resetAllData,
                              style: _debugButtonStyle(colors, colors.danger),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: colors.danger,
                              ),
                              label: Text(
                                strings.resetAllData,
                                style: TextStyle(
                                  color: colors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_kShowOnboarding) ...[
                      const SizedBox(height: 8),
                      // Onboarding replay lived in the menu's own Info
                      // section briefly; moved back here — a dev/QA aid for
                      // checking the flow still works, not something a
                      // regular user goes looking for on purpose.
                      StaggeredEntrance(
                        index: 11,
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _push(const OnboardingScreen()),
                            style: _debugButtonStyle(colors, colors.muted),
                            icon: Icon(
                              Icons.play_circle_outline,
                              size: 16,
                              color: colors.muted,
                            ),
                            label: Text(
                              strings.menuOnboarding,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
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

/// A debug-tools button's own panel background — same nightPanel/nightBorder
/// language every other field/tile in the app uses, so these read as
/// tappable buttons rather than as a stray, unstyled line of text sitting
/// on the page. [foreground] carries through as the button's own text/icon
/// color (set independently at each call site), so only the background and
/// border are decided here.
ButtonStyle _debugButtonStyle(AppColors colors, Color foreground) {
  return TextButton.styleFrom(
    foregroundColor: foreground,
    backgroundColor: colors.nightPanel,
    side: BorderSide(color: colors.nightBorder),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusField),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

/// A settings section sketched in ahead of the system behind it existing —
/// Profile & Account, Customization, Passkey and Social all render as one
/// of these today: an icon and a line explaining what will live here once
/// it's built, in the same panel language as every working section around
/// it, so a placeholder reads as "not yet" rather than as a mistake.
class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.icon, required this.body});

  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(colors),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredEntrance(
            index: 0,
            axis: Axis.horizontal,
            child: Icon(icon, color: colors.muted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StaggeredEntrance(
              index: 1,
              axis: Axis.horizontal,
              child: Text(
                body,
                style: TextStyle(color: colors.muted, fontSize: 13, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
