import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'audio/audio_service.dart';
import 'data/area_vision_repository.dart';
import 'data/audio_settings_repository.dart';
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
import 'theme/app_theme.dart';

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
  runApp(const VictoryStarsApp());
}

class VictoryStarsApp extends StatefulWidget {
  const VictoryStarsApp({super.key});

  @override
  State<VictoryStarsApp> createState() => _VictoryStarsAppState();
}

class _VictoryStarsAppState extends State<VictoryStarsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  SettingsController? _settings;
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
      final starRepository = await StarRepository.create();
      final projectRepository = await ProjectRepository.create();
      final habitRepository = await HabitRepository.create();
      final habitCompletionRepository =
          await HabitCompletionRepository.create();
      final starsShapeRepository =
          await StarsShapeRepository.create();
      final areaVisionRepository = await AreaVisionRepository.create();
      final reflectionAnswerRepository =
          await ReflectionAnswerRepository.create();
      final audioSettingsRepository = await AudioSettingsRepository.create();
      final audioService = await AudioService.create(audioSettingsRepository);
      final onboardingPrefs = await OnboardingPrefs.create();

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
      });

      if (await reminderService.launchedFromNotification()) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openAddStarFromNotification(),
        );
      } else if (!onboardingPrefs.hasSeenOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showOnboarding(onboardingPrefs),
        );
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
        starRepository == null ||
        projectRepository == null ||
        habitRepository == null ||
        habitCompletionRepository == null ||
        starsShapeRepository == null ||
        areaVisionRepository == null ||
        reflectionAnswerRepository == null ||
        audioSettingsRepository == null ||
        audioService == null ||
        reminderService == null) {
      // Nothing is known yet — a neutral, static splash rather than
      // guessing defaults that might flash-swap once everything loads.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(color: Color(0xFF0D1220)),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Victory Stars',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(settings.locale),
      supportedLocales: const [Locale('en'), Locale('it'), Locale('ro')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => StringsScope(
        strings: stringsForLocale(settings.locale),
        child: child!,
      ),
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
        child: SkyScreen(
          settings: settings,
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
    );
  }
}
