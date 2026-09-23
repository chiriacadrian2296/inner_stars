import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'audio/audio_service.dart';
import 'data/apk_prompt_prefs.dart';
import 'data/app_lock_repository.dart';
import 'data/area_vision_repository.dart';
import 'data/audio_settings_repository.dart';
import 'data/biometric_auth_service.dart';
import 'data/custom_constellation_repository.dart';
import 'data/habit_completion_repository.dart';
import 'data/habit_repository.dart';
import 'data/legacy_constellation_migration.dart';
import 'data/onboarding_prefs.dart';
import 'data/project_repository.dart';
import 'data/reflection_answer_repository.dart';
import 'data/star_repository.dart';
import 'debug/seed_data.dart';
import 'l10n/strings_scope.dart';
import 'notifications/reminder_service.dart';
import 'models/star_kind.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sky_screen.dart';
import 'screens/star_form_screen.dart';
import 'settings/settings_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'tutorials/tour_storage.dart';
import 'widgets/apk_download_prompt.dart';
import 'widgets/app_lock_gate.dart';

/// Parks the old first-launch onboarding and the Sky menu's "Metaphor"
/// guide, both superseded by `hint_kit`-driven live tutorials pointing at
/// the real UI (see `lib/tutorials/`). Left in place rather than deleted —
/// their written content is still a source to draw each tour's copy from.
/// See the TRB entry for this. Flip back on to restore the old flow
/// exactly as it was.
const _kShowOnboarding = false;

void main() {
  // Explicit opt-in to edge-to-edge (mandatory on Android 15+ regardless):
  // without it, the system nav/status bars are drawn as their own opaque
  // strip rather than transparent overlays on top of the app, so the
  // SystemUiOverlayStyle colors set below have nothing to actually show —
  // Android just paints its own default (white) behind them instead.
  //
  // Debug builds swap in Marionette's own binding instead of the plain
  // Flutter one — it's a superset that also exposes the widget tree/
  // tap/scroll/screenshot surface an MCP-connected agent drives, wired
  // in only for `kDebugMode` so it never ships in a release build.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Portrait-only: the Sky's own overlay controls are laid out for a tall
  // window, and a phone turned sideways has nowhere near the height they
  // assume. Simplest fix for that whole class of problem is to never let a
  // phone get turned sideways in the first place. No-op on web/desktop,
  // which don't rotate the app this way regardless.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const InnerStarsApp());
}

class InnerStarsApp extends StatefulWidget {
  const InnerStarsApp({super.key});

  @override
  State<InnerStarsApp> createState() => _InnerStarsAppState();
}

class _InnerStarsAppState extends State<InnerStarsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  SettingsController? _settings;
  AppLockRepository? _appLockRepository;
  BiometricAuthService? _biometricAuthService;
  StarRepository? _starRepository;
  ProjectRepository? _projectRepository;
  HabitRepository? _habitRepository;
  HabitCompletionRepository? _habitCompletionRepository;
  StarsShapeRepository? _starsShapeRepository;
  AreaVisionRepository? _areaVisionRepository;
  ReflectionAnswerRepository? _reflectionAnswerRepository;
  AudioSettingsRepository? _audioSettingsRepository;
  AudioService? _audioService;
  ReminderService? _reminderService;
  TourStorage? _tourStorage;

  /// Set only if [_load] throws. A blank splash that silently never
  /// finishes loading (see [build]) is indistinguishable from a hang — this
  /// at least surfaces what broke, directly on screen, without needing a
  /// debugger or logcat attached.
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await SettingsController.create();
      settings.addListener(() => setState(() {}));
      final appLockRepository = await AppLockRepository.create();
      final biometricAuthService = BiometricAuthService();
      final starRepository = await StarRepository.create();
      final projectRepository = await ProjectRepository.create();
      final habitRepository = await HabitRepository.create();
      final habitCompletionRepository =
          await HabitCompletionRepository.create();
      final starsShapeRepository = await StarsShapeRepository.create();
      final areaVisionRepository = await AreaVisionRepository.create();
      final reflectionAnswerRepository =
          await ReflectionAnswerRepository.create();
      final audioSettingsRepository = await AudioSettingsRepository.create();
      final audioService = await AudioService.create(audioSettingsRepository);
      final onboardingPrefs = await OnboardingPrefs.create();
      final apkPromptPrefs = await ApkPromptPrefs.create();
      final tourStorage = await PrefsTourStorage.create(
        enabled: () => settings.tutorialsEnabled,
      );

      // Debug builds only, and only for a genuinely empty install — the
      // same seeding "Settings > Seed sample data" already does by hand
      // (see `SettingsScreen._seedSampleData`), just run automatically so
      // there's always something to explore without reaching for that
      // button first. Matters most for the web: `flutter run -d chrome`
      // opens a brand-new, disposable browser profile on every single
      // launch, so without this every fresh web debug session would start
      // from zero projects (and, on the Sky, zero constellations)
      // regardless of what was seeded last time.
      if (kDebugMode && projectRepository.getAll().isEmpty) {
        await seedSampleData(
          starRepository: starRepository,
          projectRepository: projectRepository,
          habitRepository: habitRepository,
          habitCompletionRepository: habitCompletionRepository,
          languageCode: settings.locale,
        );
      }

      // Idempotent — safe (and cheap once everything's migrated) to run on
      // every launch. Must finish before setState reveals the app below, so
      // every Project any screen reads already has its starsShapeId.
      await backfillMissingConstellations(
        projectRepository: projectRepository,
        starsShapeRepository: starsShapeRepository,
      );
      // Wired here (not per-screen) since a second `initialize()` call from
      // another ReminderService instance would silently steal this tap
      // callback out from under the app-level navigation handler.
      final reminderService = await ReminderService.create(
        onNotificationTap: (_) => _openAddStarFromNotification(),
      );

      // scheduleUpcoming only ever arms the next few days (see its own doc
      // comment) — without topping it up again here on every launch, a
      // reminder that was enabled once would silently stop firing for
      // anyone who doesn't happen to revisit the Settings screen.
      if (settings.reminderEnabled) {
        final strings = stringsForLocale(settings.locale);
        await reminderService.scheduleUpcoming(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
          title: strings.reminderNotificationTitle,
          bodies: strings.reminderNotificationBodies,
        );
      }

      setState(() {
        _settings = settings;
        _appLockRepository = appLockRepository;
        _biometricAuthService = biometricAuthService;
        _starRepository = starRepository;
        _projectRepository = projectRepository;
        _habitRepository = habitRepository;
        _habitCompletionRepository = habitCompletionRepository;
        _starsShapeRepository = starsShapeRepository;
        _areaVisionRepository = areaVisionRepository;
        _reflectionAnswerRepository = reflectionAnswerRepository;
        _audioSettingsRepository = audioSettingsRepository;
        _audioService = audioService;
        _reminderService = reminderService;
        _tourStorage = tourStorage;
      });

      if (await reminderService.launchedFromNotification()) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openAddStarFromNotification(),
        );
      } else if (_kShowOnboarding && !onboardingPrefs.hasSeenOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showOnboarding(onboardingPrefs),
        );
      }

      // Android browsers only: the site isn't installable as a PWA anymore
      // (see web/index.html), so this is where someone opening it on a
      // phone is pointed at the real app instead. `defaultTargetPlatform`
      // reads the browser's own OS on web, so desktop and iOS never see it.
      if (kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !apkPromptPrefs.dismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigatorContext = _navigatorKey.currentContext;
          if (navigatorContext == null) return;
          showApkDownloadPrompt(navigatorContext, apkPromptPrefs);
        });
      }
    } catch (error) {
      setState(() => _loadError = error);
    }
  }

  /// Pushed once, the first time the app is ever opened (see the
  /// `!onboardingPrefs.hasSeenOnboarding` check in [_load]) — but however it
  /// closes (finished, skipped, or just backed out of), that's the signal to
  /// mark it seen, so it never auto-shows again regardless of how the user
  /// left it.
  Future<void> _showOnboarding(OnboardingPrefs prefs) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
    await prefs.setSeenOnboarding(true);
  }

  Future<void> _openAddStarFromNotification() async {
    final starRepository = _starRepository;
    final projectRepository = _projectRepository;
    final starsShapeRepository = _starsShapeRepository;
    final navigator = _navigatorKey.currentState;
    if (starRepository == null ||
        projectRepository == null ||
        starsShapeRepository == null ||
        navigator == null) {
      return;
    }

    final result = await navigator.push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          projectRepository: projectRepository,
          starsShapeRepository: starsShapeRepository,
        ),
      ),
    );
    if (result is! StarFormResult) return;

    // The reminder is a nudge to light a star, but the form it opens can
    // create any kind — a pulsar chosen here belongs to the habit
    // repository, which this shortcut doesn't hold, so it's simply not
    // offered a path it can't finish.
    if (result.kind == StarKind.pulsar) return;
    await starRepository.add(
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      targetDate: result.targetDate,
      achievedDate: result.achievedDate,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final appLockRepository = _appLockRepository;
    final biometricAuthService = _biometricAuthService;
    final starRepository = _starRepository;
    final projectRepository = _projectRepository;
    final habitRepository = _habitRepository;
    final habitCompletionRepository = _habitCompletionRepository;
    final starsShapeRepository = _starsShapeRepository;
    final areaVisionRepository = _areaVisionRepository;
    final reflectionAnswerRepository = _reflectionAnswerRepository;
    final audioSettingsRepository = _audioSettingsRepository;
    final audioService = _audioService;
    final reminderService = _reminderService;
    final tourStorage = _tourStorage;
    final loadError = _loadError;
    if (loadError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xFF0D1220),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '$loadError',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (settings == null ||
        appLockRepository == null ||
        biometricAuthService == null ||
        starRepository == null ||
        projectRepository == null ||
        habitRepository == null ||
        habitCompletionRepository == null ||
        starsShapeRepository == null ||
        areaVisionRepository == null ||
        reflectionAnswerRepository == null ||
        audioSettingsRepository == null ||
        audioService == null ||
        reminderService == null ||
        tourStorage == null) {
      // Nothing is known yet — a neutral, static splash rather than
      // guessing defaults that might flash-swap once everything loads.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(color: Color(0xFF0D1220)),
      );
    }

    final strings = stringsForLocale(settings.locale);

    // Above the MaterialApp, not inside its builder — a `hint_kit` tour is
    // meant to be able to cross routes (see `TourScope`'s own doc comment),
    // which only works if it sits above the Navigator rather than below it.
    // `tourLengths` declares each tour's step count up front (see
    // `lib/tutorials/`), so a card never reads "1 of 2" and grows to "3 of
    // 5" as a cross-route tour's later targets mount — add an entry here
    // whenever a new tour is built.
    return TourScope(
      storage: tourStorage,
      tourLengths: const {
        'sky-navigation': 15,
        'star-form': 14,
        'search-stars': 6,
        'light-your-sky': 4,
        'constellation-form': 11,
        'supernova-vision': 4,
      },
      labels: TourLabels(
        skip: strings.tourSkipAction,
        back: strings.tourBackAction,
        next: strings.tourNextAction,
        done: strings.tourDoneAction,
        progress: strings.tourProgressLabel,
      ),
      // A step whose target lives behind a branch the user didn't take
      // (e.g. a star-kind-specific field, or a filter sheet's kind
      // section, only shown in some modes) would otherwise wait forever —
      // this is the safety valve: give up on it and move on rather than
      // stranding the tour.
      stepTimeout: const Duration(seconds: 8),
      // The app's own navy-and-white card, rather than hint_kit's own
      // neutral default — reads as unmistakably *this app's* own chrome,
      // and stands out hard against the dimmed sky behind it. Static
      // `AppColors.dark` rather than `context.colors`: there is no light
      // mode to switch on (see `AppColors`'s own doc comment), and this
      // sits above the `MaterialApp`/`Theme` that would resolve it anyway.
      // `pulseColor` is a local addition to this app's own hint_kit fork
      // (see `packages/hint_kit`) — upstream always draws the pulse ring in
      // the scrim's own dim colour, which never reads as an attention cue.
      theme: HintThemeData(
        scrimOpacity: 0.75,
        backgroundColor: AppColors.dark.nightPanel,
        foregroundColor: AppColors.dark.text,
        pulseColor: AppColors.dark.text,
        // A thin white edge on the card itself — separate from the pulse
        // ring on the target — and a few extra px between the card and
        // whatever it's pointing at (upstream default is just
        // `arrowSize.height + 4` = 11), so the card doesn't feel like it's
        // touching the target it's describing.
        borderColor: AppColors.dark.text,
        borderWidth: 1.5,
        gap: 18,
      ),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Inner Stars',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: Locale(settings.locale),
        supportedLocales: const [Locale('en'), Locale('it'), Locale('ro')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            StringsScope(strings: strings, child: child!),
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          // Android draws its own status/navigation bars over the app by
          // default with a plain white background regardless of the app's
          // theme — without this, the back/home/recents bar (and the status
          // bar) stay white instead of matching the app's always-dark look.
          // Fully transparent (not colors.night) rather than an explicit
          // opaque color: Android 15+ ignores an app-requested
          // systemNavigationBarColor outright under mandatory edge-to-edge,
          // so the only reliable way to get a dark bar there is to make it
          // transparent and let the app's own (already-dark) Scaffold
          // background — which edge-to-edge extends behind the bar
          // automatically — show through.
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          // Gates everything behind an optional PIN/fingerprint lock —
          // above SkyScreen so a locked launch never reveals a frame of
          // real content first, and re-checked on every background/resume
          // (see AppLockGate's own doc comment for the lifecycle rule).
          child: AppLockGate(
            appLockRepository: appLockRepository,
            biometricAuthService: biometricAuthService,
            child: SkyScreen(
              settings: settings,
              appLockRepository: appLockRepository,
              biometricAuthService: biometricAuthService,
              starRepository: starRepository,
              projectRepository: projectRepository,
              habitRepository: habitRepository,
              habitCompletionRepository: habitCompletionRepository,
              starsShapeRepository: starsShapeRepository,
              areaVisionRepository: areaVisionRepository,
              reflectionAnswerRepository: reflectionAnswerRepository,
              audioSettingsRepository: audioSettingsRepository,
              audioService: audioService,
              reminderService: reminderService,
            ),
          ),
        ),
      ),
    );
  }
}
