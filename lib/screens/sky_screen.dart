import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hint_kit/hint_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tooltip_card/tooltip_card.dart';

import '../audio/audio_service.dart';
import '../data/area_vision_repository.dart';
import '../data/audio_settings_repository.dart';
import '../data/constellation_layout.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../notifications/reminder_service.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_glow.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/habit_stats.dart';
import '../utils/haptics.dart';
import '../utils/responsive.dart';
import '../utils/star_stats.dart';
import '../widgets/constellation_field.dart';
import '../widgets/constellation_painter.dart';
import '../widgets/nebula_background.dart';
// import '../widgets/sky_decorations.dart'; — the spiral-galaxy take on this
// slot, disabled first in favor of SkyWisps, then SkyBlackHole, then
// SkySupernova below; see the Stack in build().
// import '../widgets/sky_wisps.dart'; — the wispy-nebula take, disabled too.
// import '../widgets/sky_black_hole.dart'; — the lensed-black-hole take,
// disabled too.
import '../widgets/shareable_lit_star_card.dart';
import '../widgets/sky_area_sigils.dart';
import '../widgets/sky_area_tooltip.dart';
import '../widgets/sky_constellation_tooltip.dart';
import '../widgets/sky_menu_drawer.dart';
import '../widgets/sky_navigation_target.dart';
import '../widgets/sky_pulsar_tooltip.dart';
import '../widgets/sky_star_tooltip.dart';
import '../widgets/sky_supernova.dart';
import 'admire_stars_screen.dart';
import 'area_detail_screen.dart';
import 'friends_screen.dart';
import 'sky_search_screen.dart';
import 'metaphor_screen.dart';
import 'pulsar_reader_screen.dart';
import 'new_project_screen.dart';
import 'settings_screen.dart';
import 'sound_lab_screen.dart';
import 'constellation_screen.dart';
import 'shooting_stars_screen.dart';
import 'star_form_screen.dart';
import 'star_reader_screen.dart';
import 'stats_screen.dart';
import 'visions_screen.dart';

/// Shared by the Grid switch pill and [_ZoomSlider] at the bottom of the
/// sky overlay, so the two read as matching controls rather than each
/// sizing to its own content — `Switch`'s own default (bigger) touch
/// target would otherwise make the Grid pill taller than the slider.
/// [_bottomPillRadius] is exactly half [_bottomPillHeight] — a full
/// stadium/pill shape, the fully-rounded end of the range rather than a
/// squared-off rectangle.
const double _bottomPillHeight = 44.0;
const double _bottomPillRadius = 22.0;

/// Shared by every hold-to-activate gesture on this screen — the sky's own
/// hold-to-peek (see `_SkyScreenState._holdDuration`) and the menu button's
/// hold-to-open charge (see `_MenuStarButtonState._chargeDuration`) — so
/// the two read as one consistent gesture across the screen rather than
/// two independently-tuned numbers that happen to be close. Everything
/// else timed off a hold (the charging ring's own animation, the
/// duration-matched vibration) already derives from whichever of those two
/// constants applies, so bumping this one number retunes all of it at
/// once, everywhere, in lockstep.
const kHoldGestureDuration = Duration(milliseconds: 600);

/// The Sky: the app's one and only screen. Every constellation, scattered
/// across a single pannable/zoomable sky over the animated nebula
/// background, with each supernova burning where its own area sits.
/// Everything else in the app opens as a page on top of this one — from
/// the side menu ([SkyMenuDrawer]), from the search popup, or by tapping
/// the sky itself.
///
/// A tap flies the camera to whatever was aimed at — a star, a
/// constellation, or a supernova — and nothing more; a nascent star (an
/// empty slot, not something to peek at) is the one exception, opening
/// its form straight away, same as a pulsar opens its reader straight
/// away. Holding instead of tapping is what actually opens a star's/
/// constellation's/supernova's tooltip, most of the way through the
/// camera's own flight there rather than waiting for it to fully land
/// (see [_openTooltipDuringFlight]) — see [_handleTapUp]/[_handleHold].
class SkyScreen extends StatefulWidget {
  const SkyScreen({
    super.key,
    required this.settings,
    required this.projectRepository,
    required this.starRepository,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.starsShapeRepository,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.audioSettingsRepository,
    required this.audioService,
    required this.reminderService,
  });

  final SettingsController settings;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final StarsShapeRepository starsShapeRepository;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  final AudioSettingsRepository audioSettingsRepository;
  final AudioService audioService;
  final ReminderService reminderService;

  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

/// What [_SkyScreenState._skyTooltipController] is showing — a star's
/// quick-look, a pulsar's, a constellation's, or a supernova's, one per
/// level of the sky the same way the "Light Your Sky" chooser is (see
/// `SkyMenuContent._openLightYourSkyChooser`).
sealed class _SkyTooltip {
  const _SkyTooltip();
}

class _StarTooltip extends _SkyTooltip {
  const _StarTooltip(this.constellation, this.starIndex);
  final PlacedConstellation constellation;
  final int starIndex;
}

/// A pulsar's own tooltip — [habit] rather than an index into
/// [constellation]'s own star list, since (unlike a real star) a pulsar
/// isn't part of the shape at all (see [ConstellationStar.slotSequence]'s
/// own doc comment) and so has no stable slot to re-look-up by; the
/// [Habit] itself is what [PlacedConstellation.habits] already hands
/// back at hit-test time.
class _PulsarTooltip extends _SkyTooltip {
  const _PulsarTooltip(this.constellation, this.habit);
  final PlacedConstellation constellation;
  final Habit habit;
}

class _ConstellationTooltip extends _SkyTooltip {
  const _ConstellationTooltip(this.constellation);
  final PlacedConstellation constellation;
}

class _AreaTooltip extends _SkyTooltip {
  const _AreaTooltip(this.area);
  final LifeArea area;
}

class _SkyScreenState extends State<SkyScreen> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // See kSkyMaxZoom's own doc comment (constellation_field.dart) for why
  // this value, and why it's shared rather than private to this class.
  // Halved along with minZoomWithoutRepeats and the starting _zoom below
  // so the *entire* range sits farther back — max zoom-in isn't as close,
  // max zoom-out isn't as close, and the default view isn't as close
  // either — rather than only widening one end of it.
  static const _maxZoom = kSkyMaxZoom;

  /// The three fly-to zoom levels — one per kind of sky element a tap can
  /// land on, each its own independently tunable number (see
  /// [zoomPercent]'s 0..100 scale) rather than one shared value or a
  /// per-content zoom-to-fit formula, so each can be dialed in on its own.
  /// Ascending, matching the funnel a tap chain actually walks down:
  /// supernova -> constellation -> star, each landing closer than the last.
  ///
  /// [_constellationZoomPercent] doubles as [_starTapMinZoomPercent] (see
  /// its own doc comment) on purpose — arriving at a constellation should
  /// leave its stars individually tappable immediately, not require an
  /// extra manual zoom in first.
  static const _areaZoomPercent = 35.0;
  static const _constellationZoomPercent = 75.0;
  static const _starZoomPercent = 95.0;

  /// How far back one double-tap-to-zoom-out (see [_handleTapUp]'s own
  /// manual double-tap tracking and [_zoomOutOneLevel]) steps: below
  /// [_areaZoomPercent] there's no fourth named level to retreat to, so it
  /// drops all the way to the sky's own default "furthest comfortable"
  /// zoom instead of a fourth magic number.
  static const _zoomOutFloorPercent = 0.0;

  // Only used to seed the inertia glide's initial velocity now (see
  // _handleScaleEnd) — the live drag itself is an exact rotation (see
  // _handleScaleUpdate/SkyCamera.rotatedToAlign), not a scaled pixel
  // delta, so it has no sensitivity constant to tune at all.
  static const _panSensitivity = 0.15;

  /// The camera's own free orientation — see [SkyCamera]: no fixed "up"
  /// reference, so there's no pole to run into no matter which way (or
  /// how many times over) it's turned.
  SkyCamera _camera = SkyCamera.lookingAt(azimuthTurns: 0, elevationTurns: 0);
  // Halved from the original 1.0 default — see _maxZoom's own comment —
  // so the sky already reads as farther away the moment the tab opens,
  // not just once the user zooms out manually.
  double _zoom = 0.5;
  double _zoomAtGestureStart = 1;

  List<PlacedConstellation> _placed = [];
  int _revision = 0;
  ui.FragmentProgram? _flareProgram;

  /// What the sky's tap tooltip (see [_buildSkyTooltip]) is showing right
  /// now, if anything — carried as the [TooltipCardController]'s own
  /// `data` rather than duplicated into separate state fields, so there's
  /// exactly one place ("is a tooltip open, and showing what") that could
  /// ever disagree with what's actually on screen. A listener added in
  /// [initState] calls `setState` on every open/close/data change, since
  /// [_quickLookConstellation]/[_quickLookStar] below are read directly
  /// during `build` (the off-screen share capture, the back-button
  /// handling) the same way plain fields used to be.
  final _skyTooltipController = TooltipCardController<_SkyTooltip>();
  final _quickLookShareKey = GlobalKey();
  bool _sharingQuickLookStar = false;

  /// The `TooltipCard` widget itself (see [_buildSkyTooltipOverlay]),
  /// rebuilt only in [didChangeDependencies] rather than fresh on every
  /// `build()` — see that method's own doc comment for why: `TooltipCard`
  /// reacts to [_skyTooltipController] entirely on its own (that's the
  /// whole point of handing it a controller + a content `builder`
  /// callback), so it never actually needs a new instance for that;
  /// handing it one anyway, every time this screen rebuilds for pan/zoom/
  /// inertia/fly (all of which call `setState` far more often than the
  /// tooltip itself changes), was what caused every tap to leave the sky
  /// stuck — see that comment for the full explanation.
  Widget? _skyTooltipOverlay;

  /// Momentum left over from a drag release, in pan-units (turns) per
  /// second — see [_handleScaleEnd]/[_onInertiaTick]. Google Earth's
  /// space view was the explicit reference for this: flick the sky and it
  /// keeps gliding, decelerating smoothly, rather than stopping dead the
  /// instant the finger lifts.
  Offset _panVelocity = Offset.zero;
  Ticker? _inertiaTicker;
  Duration _lastInertiaTick = Duration.zero;

  /// The camera exactly as it was when the current drag began, and the
  /// world direction under the cursor/finger at that same instant — see
  /// [_handleScaleUpdate], which re-derives the camera fresh from these
  /// two every frame (never by accumulating small steps) so that anchor
  /// point stays glued to the cursor for the entire gesture, regardless
  /// of zoom. Both null between gestures.
  SkyCamera? _dragStartCamera;
  (double, double, double)? _dragAnchorDirection;

  /// Whether each sky-overlay control is currently shown at all — not to
  /// be confused with [SettingsController.showGrid] (that one toggles the
  /// grid *content* drawn on the sky itself, and is a real persisted
  /// setting now, editable from Settings; these toggle the little UI
  /// controls sitting on top of it). Defaulted off for now — a request to
  /// preview the sky with none of its navigation-helper chrome showing —
  /// not a removal: flip these back to `true` to restore them, and
  /// [_showUiControlsMenu] (still fully intact) still flips them at
  /// runtime once its own button is showing again.
  bool _showGridControl = false;
  bool _showZoomControl = false;
  bool _showRotationControl = false;

  /// Same "preview it clean" request as the three above, for the overlay
  /// buttons that never had a toggle of their own: the search pill, the
  /// tune/settings button that opens [_showUiControlsMenu], and — once
  /// the star FAB (see [_MenuStarButton]) gave the menu a second way in —
  /// the drawer button itself too. `static const` rather than instance
  /// state — these aren't meant to be flipped at runtime, only reverted
  /// here in code.
  static const bool _showSearchButton = false;
  static const bool _showUiControlsButton = false;
  static const bool _showDrawerButton = false;

  /// Drives the "take me there" fly-to animation — a single controller
  /// reused across flights rather than rebuilt per tap, so a second tap
  /// mid-flight can redirect it smoothly instead of leaving an orphaned
  /// listener behind. [_flyStartCamera]/[_flyTargetForward] are read by
  /// [_onFlyTick] on every frame; null between flights.
  late final AnimationController _flyController;
  SkyCamera? _flyStartCamera;
  (double, double, double)? _flyTargetForward;
  double _flyStartZoom = 0;
  double _flyTargetZoom = 0;

  /// Extra roll (radians) [_onFlyTick] ramps in on top of the ordinary
  /// [SkyCamera.rotatedToAlignFraction] sweep, reaching its full value
  /// exactly as the flight lands — see [_flyToWorld]'s own
  /// `straightenRoll` for what sets this to something other than the
  /// default 0 (a constellation hold, so its shape lands upright — see
  /// [_holdConstellation]) and, importantly, *what* it's computed
  /// against: the sphere's own curvature means [SkyCamera.rotatedToAlign]
  /// doesn't preserve the *reading* [cameraRollAngle] gives at the
  /// destination (only that the transport itself adds no extra twist of
  /// its own) — the correction has to target the destination's actual
  /// roll, not the roll the flight started with. Every flight that
  /// doesn't ask for straightening explicitly resets this back to 0.
  double _flyRollCorrection = 0;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onFlyTick);
    _holdRingController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
    // Every read of [_quickLookConstellation]/[_quickLookStar] below is a
    // plain synchronous getter over this controller's own `data`, same as
    // when they were separate `setState`-managed fields — this listener
    // is what still makes that work now that they're not: `open`/`close`/
    // `updateData` all notify it, same as any other state change would.
    _skyTooltipController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
    _loadFlareProgram();
    // Opens centered on "Love" rather than the world origin — with a
    // dozen-plus constellations spiraling out from there, landing on empty
    // space by default made the tab feel empty on first open. Leaves
    // _camera at its default origin-facing orientation if no project by
    // that name exists.
    for (final constellation in _placed) {
      if (constellation.project.name == 'Love') {
        _camera = SkyCamera.lookingAt(
          azimuthTurns: constellation.worldPosition.dx,
          elevationTurns: constellation.worldPosition.dy,
        );
        break;
      }
    }
    // The "sky-navigation" tour — see its steps further down in [build]
    // (the invisible full-screen anchor, the menu button, the Sound Lab
    // button). Runs once, ever, same as every other tour (`PrefsTourStorage`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Tour.read(context).start('sky-navigation');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only actually rebuilds [_skyTooltipOverlay] when something it reads
    // (theme, screen size) really changed — see that field's own doc
    // comment. Reading `context.colors`/`MediaQuery.sizeOf` here (rather
    // than in `build`) is what makes this method re-run only for genuine
    // dependency changes instead of on every one of this screen's own
    // frequent `setState` calls.
    _skyTooltipOverlay = _buildSkyTooltipOverlay(context.colors);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdRingArmTimer?.cancel();
    _stopHoldHaptic();
    _flyController.dispose();
    _holdRingController.dispose();
    _inertiaTicker?.dispose();
    _skyTooltipController.dispose();
    super.dispose();
  }

  void _stopInertia() {
    _inertiaTicker?.stop();
    _inertiaTicker?.dispose();
    _inertiaTicker = null;
  }

  /// Turns [_camera] by a raw cursor-derived [delta] — dragging left
  /// looks right, dragging down looks up (see [SkyCamera.rotated]'s own
  /// sign convention for why `delta.dx`/`delta.dy` map straight onto it
  /// with no extra negation). Since [SkyCamera] always rotates around its
  /// *own current* axes rather than fixed world ones, this needs no
  /// pole-crossing compensation the old azimuth/elevation camera did —
  /// there's no pole left to cross.
  void _rotateCamera(Offset delta) {
    _camera = _camera.rotated(
      horizontalTurns: delta.dx,
      verticalTurns: delta.dy,
    );
  }

  /// Starts (or restarts) the coast-to-a-stop glide after a drag release —
  /// see [_handleScaleEnd]. Runs its own ticker rather than reusing the
  /// scale gesture's setState pattern since it needs to keep animating
  /// well after the gesture itself has ended.
  void _startInertia() {
    _stopInertia();
    _lastInertiaTick = Duration.zero;
    _inertiaTicker = createTicker(_onInertiaTick)..start();
  }

  void _onInertiaTick(Duration elapsed) {
    final dt = _lastInertiaTick == Duration.zero
        ? 0.0
        : (elapsed - _lastInertiaTick).inMicroseconds / 1e6;
    _lastInertiaTick = elapsed;
    if (dt <= 0) return;

    setState(() {
      _rotateCamera(_panVelocity * dt);
      // Exponential decay ("friction") — velocityDecayPerSecond is what
      // fraction of the velocity survives after a full second, so this
      // stays frame-rate independent rather than shrinking by a fixed
      // amount per tick.
      const velocityDecayPerSecond = 0.04;
      final decay = math.pow(velocityDecayPerSecond, dt).toDouble();
      _panVelocity *= decay;
    });

    // Stop once velocity is imperceptibly small (turns/second) rather than
    // coasting forever at a value too tiny to ever visibly move anything.
    const minVelocity = 0.0001;
    if (_panVelocity.distanceSquared < minVelocity * minVelocity) {
      _stopInertia();
    }
  }

  Future<void> _loadFlareProgram() async {
    final program = await buildConstellationFlareProgram();
    if (!mounted) return;
    setState(() {
      _flareProgram = program;
      _revision++;
    });
  }

  /// Sorted ascending by id (== creation order, ids are timestamp-based) —
  /// never by `ProjectRepository.getAll()`'s own newest-first order, so a
  /// new project always lands at the end of its own [Project.area]'s
  /// sequence and never shifts an existing constellation's
  /// [constellationWorldPosition] index within that area.
  void _loadData() {
    final projects = widget.projectRepository.getAll().toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final completionsByHabit = <int, List<HabitCompletion>>{};
    for (final completion in widget.habitCompletionRepository.getAll()) {
      completionsByHabit
          .putIfAbsent(completion.habitId, () => [])
          .add(completion);
    }

    // Counts each project's position within its own area's sequence
    // (rather than a single global index) — see [constellationWorldPosition],
    // which clusters a project's constellation around its own area's
    // supernova instead of scattering it across the whole sky.
    final indexByArea = <LifeArea, int>{};
    _placed = [
      for (final project in projects)
        _buildPlaced(
          project,
          indexByArea.update(
            project.area,
            (value) => value + 1,
            ifAbsent: () => 0,
          ),
          completionsByHabit,
        ),
    ];
  }

  PlacedConstellation _buildPlaced(
    Project project,
    int indexInArea,
    Map<int, List<HabitCompletion>> completionsByHabit,
  ) {
    final shape = project.starsShapeId != null
        ? widget.starsShapeRepository
              .getById(project.starsShapeId!)
              ?.shape
        : null;
    final stars = widget.starRepository.getAllForProject(project.id);
    final habits = widget.habitRepository.getAllForProject(project.id);
    final built = buildConstellationRenderStars(
      stars: stars,
      habits: habits,
      shape: shape,
      completionsByHabit: completionsByHabit,
    );

    return PlacedConstellation(
      project: project,
      shape: shape,
      worldPosition: constellationWorldPosition(project.area, indexInArea),
      stars: stars,
      habits: habits,
      renderStars: built.stars,
      edges: built.edges,
    );
  }

  void _refresh() {
    setState(() {
      _loadData();
      _revision++;
    });
  }

  /// [showTooltip] tells the real-star and pulsar branches (the two with
  /// a tooltip at all) whether to open it as the camera flies there (see
  /// [_openTooltipDuringFlight]) — false for a plain tap (see
  /// [_handleTapUp], which only ever flies the camera), true for a hold
  /// (see [_handleHold]). The nascent branch never had a tooltip to begin
  /// with (there's nothing yet to peek at) and still acts on a plain tap
  /// exactly as before, tap or hold alike.
  Future<void> _openStar(
    PlacedConstellation constellation,
    ConstellationStar star, {
    required bool showTooltip,
  }) async {
    // A nascent star isn't something to read — it's an empty slot on the
    // shape, and tapping it is how you give it a meaning.
    if (star.kind == StarKind.nascent) {
      await _configureNascentStar(constellation, star);
      return;
    }
    // Sitting on a slot is what makes a star part of the shape; a pulsar
    // (alive or dead) scatters around it instead and has none. That's the
    // reliable test for which repository this star came from — its kind
    // isn't, since a dead star can be either.
    if (star.slotSequence == null) {
      final habit = constellation.habits.firstWhere(
        (h) => h.id == star.entityId,
      );
      if (showTooltip) {
        _openPulsarQuickLook(constellation, habit, star);
      } else {
        _flyToStar(constellation, star);
      }
      return;
    }

    final index = constellation.stars.indexWhere((s) => s.id == star.entityId);
    if (index == -1) return;
    if (showTooltip) {
      _openStarQuickLook(constellation, index, star);
    } else {
      _flyToStar(constellation, star);
    }
  }

  /// The plain-tap half of [_openStar]'s real-star branch — flies the
  /// camera to [renderStar] (see [_openStarQuickLook]'s own doc comment
  /// for why its exact position, not [SkyStarTarget]'s coarser
  /// constellation-wide one) without ever opening the tooltip.
  void _flyToStar(PlacedConstellation constellation, ConstellationStar renderStar) {
    final size = context.size;
    if (size == null) return;
    final world = starWorldPosition(
      constellation,
      renderStar,
      _camera,
      _zoom,
      size,
    );
    if (world == null) return;
    _flyToWorld(
      world,
      zoomFromPercent(_starZoomPercent).clamp(minZoomWithoutRepeats, _maxZoom),
    );
  }

  /// The hold half — same flight as [_flyToStar], plus the quick-look
  /// tooltip (see [SkyStarTooltip]), opened partway through rather than
  /// waiting for it to land (see [_openTooltipDuringFlight]). The full
  /// [StarReaderScreen] page is still just one tap away from there (see
  /// [_viewQuickLookStar]), not replaced.
  void _openStarQuickLook(
    PlacedConstellation constellation,
    int starIndex,
    ConstellationStar renderStar,
  ) {
    final size = context.size;
    if (size == null) return;
    final world = starWorldPosition(
      constellation,
      renderStar,
      _camera,
      _zoom,
      size,
    );
    if (world == null) return;
    // See [_openTooltipDuringFlight]'s own doc comment for why this
    // doesn't wait for the flight to actually land.
    _openTooltipDuringFlight(
      _flyToWorld(
        world,
        zoomFromPercent(_starZoomPercent)
            .clamp(minZoomWithoutRepeats, _maxZoom),
      ),
      _StarTooltip(constellation, starIndex),
    );
  }

  /// A pulsar's own hold half — same shape as [_openStarQuickLook], just
  /// for a pulsar's tooltip (see [SkyPulsarTooltip]) instead of a real
  /// star's. The full [PulsarReaderScreen] page is still just one tap
  /// away from there (see [_viewQuickLookPulsar]).
  void _openPulsarQuickLook(
    PlacedConstellation constellation,
    Habit habit,
    ConstellationStar renderStar,
  ) {
    final size = context.size;
    if (size == null) return;
    final world = starWorldPosition(
      constellation,
      renderStar,
      _camera,
      _zoom,
      size,
    );
    if (world == null) return;
    _openTooltipDuringFlight(
      _flyToWorld(
        world,
        zoomFromPercent(_starZoomPercent)
            .clamp(minZoomWithoutRepeats, _maxZoom),
      ),
      _PulsarTooltip(constellation, habit),
    );
  }

  void _closeSkyTooltip() => _skyTooltipController.close();

  /// The actual [Star] the quick-look tooltip is showing — re-read from
  /// [_skyTooltipController]'s own data on every access (rather than
  /// cached separately) so an edit/achieve elsewhere that triggers
  /// [_refresh] never leaves the tooltip showing stale content.
  Star? get _quickLookStar {
    final data = _skyTooltipController.data;
    if (data is! _StarTooltip) return null;
    final constellation = data.constellation;
    if (data.starIndex >= constellation.stars.length) return null;
    return constellation.stars[data.starIndex];
  }

  /// The constellation the open tooltip is about — a star's, a pulsar's,
  /// or a constellation's own; null while neither is showing (including
  /// while a supernova's is, which has no single constellation to point
  /// to).
  PlacedConstellation? get _quickLookConstellation => switch (
    _skyTooltipController.data
  ) {
    _StarTooltip(:final constellation) => constellation,
    _PulsarTooltip(:final constellation) => constellation,
    _ConstellationTooltip(:final constellation) => constellation,
    _AreaTooltip() || null => null,
  };

  Future<void> _viewQuickLookStar() async {
    final data = _skyTooltipController.data;
    if (data is! _StarTooltip) return;
    final constellation = data.constellation;
    final index = data.starIndex;
    _closeSkyTooltip();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StarReaderScreen(
          repository: widget.starRepository,
          initialStars: constellation.stars,
          startIndex: index,
          allowEdit: true,
          projectsById: {constellation.project.id: constellation.project},
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          refreshStars: () =>
              widget.starRepository.getAllForProject(constellation.project.id),
        ),
      ),
    );
    _refresh();
  }

  /// Same shape as [_viewQuickLookStar], for a pulsar — the tooltip's own
  /// [SkyPulsarTooltip.onView].
  Future<void> _viewQuickLookPulsar() async {
    final data = _skyTooltipController.data;
    if (data is! _PulsarTooltip) return;
    final constellation = data.constellation;
    final habit = data.habit;
    _closeSkyTooltip();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PulsarReaderScreen(
          habit: habit,
          project: constellation.project,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    _refresh();
  }

  /// Mirrors `StarReaderScreen._editOrResurrectCurrent` exactly (same two
  /// branches, same repository calls) — just reached from the quick-look
  /// panel instead of the full reader page.
  Future<void> _editQuickLookStar() async {
    final constellation = _quickLookConstellation;
    final star = _quickLookStar;
    if (constellation == null || star == null) return;
    // Before the push, not after it returns — the tooltip lives in the
    // root overlay (see [_buildSkyTooltip]'s own `TooltipCard`), which
    // sits *above* routes rather than being covered by them the way the
    // old in-tree quick-look panel was, so leaving it open here left it
    // floating over the edit screen for as long as that stayed open.
    _closeSkyTooltip();

    if (star.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingStar: star,
            contextProject: constellation.project,
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await widget.starRepository.resurrect(
        star.id,
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
      );
      _refresh();
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingStar: star,
          contextProject: constellation.project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    if (result is StarFormDeleteRequested) {
      await widget.starRepository.delete(star.id);
      _refresh();
      return;
    }

    final addResult = result as StarFormResult;
    await widget.starRepository.update(
      id: star.id,
      title: addResult.title,
      description: addResult.description,
      projectId: addResult.projectId,
      targetDate: addResult.targetDate,
      achievedDate: addResult.achievedDate,
      intensity: addResult.intensity,
      photoPath: addResult.photoPath,
    );
    _refresh();
  }

  Future<void> _deleteQuickLookStar() async {
    final star = _quickLookStar;
    if (star == null) return;
    final strings = context.strings;
    // Before the dialog, not after — see [_editQuickLookStar]'s own note
    // on why (the tooltip's root-overlay entry doesn't get covered by a
    // new one the way the old in-tree panel did).
    _closeSkyTooltip();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteStarConfirmTitle),
        content: Text(strings.deleteStarConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.deleteStarAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.starRepository.delete(star.id);
    _refresh();
  }

  /// Mirrors `StarReaderScreen._shareCurrent` exactly (same
  /// [RenderRepaintBoundary] capture, same [SharePlus] call) — captures
  /// [_quickLookShareKey], which wraps a [ShareableLitStarCard] rendered
  /// far off-screen (see the `build` Stack) purely so it exists to
  /// capture; only ever reachable when [_quickLookStar] is lit (see
  /// [SkyStarTooltip]'s own `onShare`, null otherwise).
  Future<void> _shareQuickLookStar() async {
    final star = _quickLookStar;
    if (star == null || !star.isLit || _sharingQuickLookStar) return;
    setState(() => _sharingQuickLookStar = true);
    try {
      final boundary =
          _quickLookShareKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('toByteData returned null');
      if (!mounted) return;
      final shareFile = XFile.fromData(
        byteData.buffer.asUint8List(),
        name: 'star_${DateTime.now().microsecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );
      await SharePlus.instance.share(
        ShareParams(files: [shareFile], text: star.title),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.shareStarError)));
      }
    } finally {
      if (mounted) setState(() => _sharingQuickLookStar = false);
    }
  }

  /// Opens the star form on one specific empty slot of [constellation]'s
  /// shape — the slot the tapped nascent star occupies — and creates the
  /// star exactly there, so the point of light the user aimed at is the one
  /// that lights up. The pulsar option is off: this slot belongs to the
  /// shape, and a pulsar never sits on the shape.
  Future<void> _configureNascentStar(
    PlacedConstellation constellation,
    ConstellationStar star,
  ) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: constellation.project,
          slotSequence: star.slotSequence,
          allowPulsar: false,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    await widget.starRepository.add(
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      slotSequence: result.slotSequence,
      targetDate: result.targetDate,
      achievedDate: result.achievedDate,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refresh();
  }

  /// The menu's own "light a star" entry: the same form, with every kind
  /// on offer and no constellation implied yet, so it can create a lit
  /// star, a pulsar or an unlit star anywhere.
  Future<void> _openStarForm() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    if (result.kind == StarKind.pulsar) {
      await widget.habitRepository.add(
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? 3,
        frequency: result.habitFrequency ?? HabitFrequency.daily,
        targetPerPeriod: result.habitTargetPerPeriod ?? 1,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
      );
    } else {
      await widget.starRepository.add(
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
      );
    }
    _refresh();
  }

  Future<void> _openNewConstellation() async {
    await Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openVisions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisionsScreen(
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
          projectRepository: widget.projectRepository,
          starRepository: widget.starRepository,
        ),
      ),
    );
    _refresh();
  }

  void _openAdmire() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdmireStarsScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
  }

  void _openStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
  }

  void _openShootingStars() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ShootingStarsScreen()));
  }

  void _openFriends() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
  }

  void _openMetaphor() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MetaphorScreen()));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          starsShapeRepository: widget.starsShapeRepository,
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
          audioSettingsRepository: widget.audioSettingsRepository,
          reminderService: widget.reminderService,
        ),
      ),
    );
    _refresh();
  }

  /// The FAB's own way into the same menu the drawer opens — same content
  /// ([SkyMenuContent], same callbacks), just as a modal sheet from the
  /// bottom instead of a panel from the side. An alternative entry point
  /// being tried alongside the drawer, not a replacement for it — both
  /// stay live so the two can be compared.
  void _openMenuModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // [SkyMenuModalFrame] draws its own background/shape/handle and
      // handles its own drag-to-dismiss (see its own doc comment for
      // why) — turned off here so [BottomSheet]'s own versions of all
      // three don't render or compete underneath it.
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: false,
      // `showModalBottomSheet` aligns via `Alignment.bottomCenter`, so
      // bounding `maxWidth` here is also what centers this horizontally
      // on a wide viewport — with no cap at all it stretched edge to
      // edge, which read as far too wide on desktop/web (a phone screen
      // is already narrower than this cap, so nothing changes there).
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        maxWidth: 480,
      ),
      builder: (_) => SkyMenuModalFrame(
        builder: (scrollController, physics) => SkyMenuContent(
          onLightAStar: _openStarForm,
          onNewConstellation: _openNewConstellation,
          onVisions: _openVisions,
          onShootingStars: _openShootingStars,
          onSearch: _openSearch,
          onStatistics: _openStatistics,
          onAdmire: _openAdmire,
          onFriends: _openFriends,
          onSettings: _openSettings,
          onMetaphor: _openMetaphor,
          detailed: true,
          scrollController: scrollController,
          physics: physics,
        ),
      ),
    );
  }

  /// Opens the search/filter popup (three levels of the same sky, minus a
  /// header — see [SkySearchScreen]) and, if a card's "take me there"
  /// button closed it with a target, snaps the camera to it.
  Future<void> _openSoundLab() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SoundLabScreen(audioService: widget.audioService),
      ),
    );
  }

  Future<void> _openSearch() async {
    final target = await Navigator.of(context).push<SkyNavigationTarget>(
      MaterialPageRoute(
        builder: (_) => SkySearchScreen(
          projectRepository: widget.projectRepository,
          starRepository: widget.starRepository,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          starsShapeRepository: widget.starsShapeRepository,
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
        ),
      ),
    );
    _refresh();
    if (target != null) _flyTo(target);
  }

  PlacedConstellation? _placedFor(Project project) {
    for (final placed in _placed) {
      if (placed.project.id == project.id) return placed;
    }
    return null;
  }

  Offset? _worldFor(SkyNavigationTarget target) => switch (target) {
    SkyAreaTarget(:final area) => areaWorldPosition(area),
    SkyProjectTarget(:final project) => _placedFor(project)?.worldPosition,
    SkyStarTarget(:final project) => _placedFor(project)?.worldPosition,
  };

  /// The zoom [_flyTo] should land [target] at — see [_areaZoomPercent]/
  /// [_constellationZoomPercent]/[_starZoomPercent]'s own doc comment for
  /// why each is its own fixed level rather than a per-content
  /// zoom-to-fit formula.
  double _zoomFor(SkyNavigationTarget target, Size screenSize) {
    final percent = switch (target) {
      SkyAreaTarget() => _areaZoomPercent,
      SkyProjectTarget() => _constellationZoomPercent,
      SkyStarTarget() => _starZoomPercent,
    };
    return zoomFromPercent(percent).clamp(minZoomWithoutRepeats, _maxZoom);
  }

  /// Flies the camera to [target]'s spot on the sky sphere — dead center by
  /// default (see [SkyCamera.lookingAt]), zoomed per [_zoomFor]. Animated as
  /// one smooth sweep along the great circle from wherever the camera
  /// currently looks (see [SkyCamera.rotatedToAlignFraction]), Maps-style,
  /// rather than an instant cut — [_onFlyTick] drives it every frame.
  ///
  /// [anchorFraction] moves where [target] ends up landing on screen —
  /// (0.5, 0.5) (the default) is dead center; (0.5, 0.25) is what the star
  /// quick-look panel uses to land its star in the middle of the screen's
  /// top half rather than behind the panel covering the bottom half. Found
  /// via [screenToDirection]/[SkyCamera.rotatedToAlign] rather than a
  /// simplified pixel-offset: aim a camera dead-center at [target] first
  /// (`baseCamera`, forward == target's own direction, by construction),
  /// then rotate so whatever direction *would* render at [anchorFraction]
  /// under `baseCamera` instead renders at dead center — the same rotation
  /// forces [target] itself to land at [anchorFraction] instead (the two
  /// are the same rotation run in the two directions a single-axis
  /// alignment always is).
  /// Returns the flight's own [TickerFuture] — [_openStarQuickLook] and
  /// [_flyToConstellation] use it to open their tooltip only once the
  /// camera actually lands (`whenCompleteOrCancel`, so an interrupted
  /// flight — a second tap before the first one finishes — still resolves
  /// instead of leaving a dangling callback). Every other caller ignores
  /// it, same as when this returned nothing at all.
  TickerFuture _flyTo(
    SkyNavigationTarget target, {
    Offset anchorFraction = const Offset(0.5, 0.5),
    bool straightenRoll = false,
  }) {
    final size = context.size;
    if (size == null) return TickerFuture.complete();
    final world = _worldFor(target);
    if (world == null) return TickerFuture.complete();
    return _flyToWorld(
      world,
      _zoomFor(target, size),
      anchorFraction: anchorFraction,
      straightenRoll: straightenRoll,
    );
  }

  /// The actual flight, once a target has already been resolved to a
  /// world (azimuth, elevation) position and a zoom — split out from
  /// [_flyTo] so [_openStarQuickLook] can fly to a *specific star's* own
  /// exact position (see [starWorldPosition]) rather than [SkyStarTarget]'s
  /// coarser "somewhere in its constellation".
  TickerFuture _flyToWorld(
    Offset world,
    double targetZoom, {
    Offset anchorFraction = const Offset(0.5, 0.5),
    // See [_flyRollCorrection]'s own doc comment — true only for a
    // constellation hold, so its shape lands upright rather than however
    // the camera happened to be twisted from an earlier manual rotation.
    bool straightenRoll = false,
  }) {
    final size = context.size;
    if (size == null) return TickerFuture.complete();

    final baseCamera = SkyCamera.lookingAt(
      azimuthTurns: world.dx,
      elevationTurns: world.dy,
    );

    var targetForward = baseCamera.forward;
    if (anchorFraction != const Offset(0.5, 0.5)) {
      final anchorPoint = Offset(
        size.width * anchorFraction.dx,
        size.height * anchorFraction.dy,
      );
      final anchorDirection = screenToDirection(
        anchorPoint,
        baseCamera,
        targetZoom,
        size,
      );
      targetForward = baseCamera
          .rotatedToAlign(anchorDirection, baseCamera.forward)
          .forward;
    }

    _stopInertia();
    _playZoomTransitionSound(_zoom, targetZoom);
    _flyStartCamera = _camera;
    _flyTargetForward = targetForward;
    _flyStartZoom = _zoom;
    _flyTargetZoom = targetZoom;
    // Computed against the *fully-swept* (t=1) target camera, not the
    // current one — verified by hand (see the scratch test this was
    // checked with): [rotatedToAlignFraction] does NOT preserve the roll
    // *reading* at a new direction the way its own doc comment first
    // suggested. It avoids adding any *extra* twist during the transport
    // itself, but the sphere's curvature (holonomy) still changes what
    // [cameraRollAngle] reads at a different point — so correcting
    // against the start camera's own roll landed at the wrong angle
    // entirely; only the destination's actual roll reading gives the
    // right correction.
    //
    // Targets [math.pi], not 0 — a zero-roll camera actually rendered a
    // constellation upside down (confirmed live), a full half-turn off
    // from [ConstellationPainter]'s own idea of "upright". [cameraRollAngle]'s
    // own "canonical" reference frame and the painter's don't agree on
    // which way is up; landing on the *opposite* pole of that reading is
    // what actually matches the shape editor's own orientation.
    _flyRollCorrection = straightenRoll
        ? math.pi -
              cameraRollAngle(_camera.rotatedToAlign(_camera.forward, targetForward))
        : 0;
    _flyController
      ..stop()
      ..reset();
    return _flyController.forward();
  }

  void _onFlyTick() {
    final startCamera = _flyStartCamera;
    final targetForward = _flyTargetForward;
    if (startCamera == null || targetForward == null) return;
    final t = Curves.easeInOutCubic.transform(_flyController.value);
    setState(() {
      var camera = startCamera.rotatedToAlignFraction(
        startCamera.forward,
        targetForward,
        t,
      );
      // [_flyRollCorrection] (see its own doc comment for how it's
      // computed and why plain [rotatedToAlignFraction] alone doesn't
      // already land level) — ramped in step with the same [t] so a
      // constellation hold finishes exactly level right as the camera
      // finishes arriving, not in a separate, visually disconnected step.
      if (_flyRollCorrection != 0) {
        camera = camera.rolled(_flyRollCorrection * t);
      }
      _camera = camera;
      _zoom = _flyStartZoom + (_flyTargetZoom - _flyStartZoom) * t;
    });
  }

  /// How far into the fly controller's own 0..1 progress a flight has to
  /// reach before the tooltip it's heading toward opens — well short of
  /// full arrival, on purpose: the tooltip is anchored to screen-center
  /// regardless of exactly where the flight currently sits (see
  /// [_buildSkyTooltipOverlay]), so it already reads fine while the
  /// camera is still finishing its last stretch, and opening it here
  /// rather than waiting out the whole ~900ms flight (see
  /// [TickerFuture.whenCompleteOrCancel]) is what makes a hold feel
  /// snappier.
  static const _tooltipOpenAtFlightProgress = 0.6;

  /// Opens [tooltip] once [flight] — the [TickerFuture] a [_flyToWorld]/
  /// [_flyTo] call just returned — crosses
  /// [_tooltipOpenAtFlightProgress], or actually finishes/gets
  /// interrupted, whichever comes first (a short flight, e.g. the target
  /// was already close, might complete before ever reaching that
  /// fraction). Shared by [_openStarQuickLook]/[_holdArea]/
  /// [_holdConstellation] so this early-open behavior lives in one place
  /// rather than three hand-rolled listeners.
  void _openTooltipDuringFlight(TickerFuture flight, _SkyTooltip tooltip) {
    var opened = false;
    void openOnce() {
      if (opened || !mounted) return;
      opened = true;
      _skyTooltipController.open(data: tooltip);
      // `tooltip_card` reads this tooltip's anchor position (moved by
      // [_tooltipAnchorOffset]'s own [Transform.translate], applied via
      // [ListenableBuilder] in [build]) the instant `open()` above
      // synchronously notifies it — before this frame's build/layout
      // pass has actually run, so `RenderBox.localToGlobal` can only
      // ever hand back the *previous* frame's position. `TooltipCard`
      // happens to self-correct this on its very first-ever open (its
      // own "did the resolved beak position change?" check starts
      // uninitialized, so it always differs once and triggers its own
      // refresh) — but that state is otherwise persistent across opens
      // (this screen deliberately keeps `TooltipCard`'s own widget
      // instance stable, see [_skyTooltipOverlay]'s doc comment), and
      // every *later* open resolves to the same side/beak position as
      // before, so nothing detects a change and the stale, un-offset
      // position just sticks — exactly the "first hold looks right,
      // every one after snaps back to no spacing" bug this was.
      // Nudging with a fresh (non-identical) copy of the same data one
      // frame later — after our offset has actually been laid out —
      // forces a fresh read, correctly this time.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_skyTooltipController.data, tooltip)) {
          _skyTooltipController.updateData(_copyTooltip(tooltip));
        }
      });
    }

    void onFlyProgress() {
      if (_flyController.value >= _tooltipOpenAtFlightProgress) {
        _flyController.removeListener(onFlyProgress);
        openOnce();
      }
    }

    _flyController.addListener(onFlyProgress);
    flight.whenCompleteOrCancel(() {
      _flyController.removeListener(onFlyProgress);
      openOnce();
    });
  }

  /// A field-for-field copy of [tooltip] as a *new* instance — see
  /// [_openTooltipDuringFlight]'s own `openOnce` for why: these classes
  /// don't override `==`, so a fresh instance is never `==` to the
  /// original one, which is exactly what's needed to make
  /// [TooltipCardController.updateData] treat it as "changed" and
  /// re-notify even though the actual content is identical.
  _SkyTooltip _copyTooltip(_SkyTooltip tooltip) => switch (tooltip) {
    _StarTooltip(:final constellation, :final starIndex) => _StarTooltip(
      constellation,
      starIndex,
    ),
    _PulsarTooltip(:final constellation, :final habit) => _PulsarTooltip(
      constellation,
      habit,
    ),
    _ConstellationTooltip(:final constellation) => _ConstellationTooltip(
      constellation,
    ),
    _AreaTooltip(:final area) => _AreaTooltip(area),
  };

  void _handleScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
    _stopInertia();
    _flyController.stop();
    final size = context.size;
    if (size != null && size.height > 0) {
      _dragStartCamera = _camera;
      _dragAnchorDirection = screenToDirection(
        details.localFocalPoint,
        _camera,
        _zoom,
        size,
      );
    } else {
      _dragStartCamera = null;
      _dragAnchorDirection = null;
    }
  }

  /// How much a single [_handleScaleUpdate] frame's own movement/zoom has
  /// to clear before it counts as a genuine pan/zoom rather than the
  /// sub-pixel jitter a finger produces while holding almost still for
  /// what's about to resolve as a tap — see where these gate closing any
  /// open tooltip below. A plain dismiss-tap needs to stay well under
  /// this, or every tap meant purely to close a tooltip would also read
  /// as an (imperceptible) pan.
  static const _realPanDistance = 3.0;
  static const _realZoomDelta = 0.01;

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // A genuine pan/zoom — not just the jitter above — closes any open
    // tooltip: letting the camera move out from under one used to leave
    // it pinned in place, still pointing at wherever the target *used*
    // to be rather than closing along with the view moving away from it.
    if (_skyTooltipController.isOpen &&
        (details.focalPointDelta.distance > _realPanDistance ||
            (details.scale - 1.0).abs() > _realZoomDelta)) {
      _skyTooltipController.close();
    }
    final size = context.size;
    setState(() {
      _zoom = (_zoomAtGestureStart * details.scale).clamp(
        minZoomWithoutRepeats,
        _maxZoom,
      );
      final startCamera = _dragStartCamera;
      final anchor = _dragAnchorDirection;
      if (size != null &&
          size.height > 0 &&
          startCamera != null &&
          anchor != null) {
        // Exact "grab and drag": re-derive the camera fresh, every frame,
        // as the single rotation of the *drag's starting* camera that
        // puts [anchor] back under wherever the cursor is *now* — never
        // by accumulating a small-angle delta step by step, so there's no
        // per-frame approximation error to build up over a long drag, and
        // the anchor point stays exactly under the cursor regardless of
        // zoom (recomputing its direction with the live zoom here is also
        // what makes a simultaneous pinch keep its focal point anchored
        // too, for the same reason).
        final current = screenToDirection(
          details.localFocalPoint,
          startCamera,
          _zoom,
          size,
        );
        // rotatedToAlign(from, to) rotates the *camera basis* so that a
        // FIXED WORLD direction at [from] renders at [to]'s screen
        // position. We want the opposite composition here: [anchor] is
        // fixed (the point grabbed at drag start) and needs to keep
        // rendering at the cursor's current screen position, which is
        // [current] only *as read against the unrotated startCamera* —
        // so the rotation actually needed is the one that carries
        // [current] to [anchor], not [anchor] to [current] (verified by
        // matching worldToScreen(anchor, camera') against
        // worldToScreen(current, startCamera) algebraically; passing
        // them the other way round was live-tested and turned every
        // drag/zoom backwards).
        _camera = startCamera
            .rotatedToAlign(current, anchor)
            .rolled(details.rotation);
      }
    });
  }

  /// Kicks off the coast-to-a-stop glide (see [_startInertia]) with
  /// whatever velocity the finger/pointer was moving at on release —
  /// [ScaleEndDetails.velocity] is already exactly that, in pixels/second.
  /// The glide itself has no cursor to track exactly (see
  /// [SkyCamera.rotated] vs. [SkyCamera.rotatedToAlign]), so this converts
  /// to pan-units/second with the same approximate pixels/height/zoom
  /// scaling [_rotateCamera] uses, rather than reusing the live drag's own
  /// exact tracking.
  void _handleScaleEnd(ScaleEndDetails details) {
    final size = context.size;
    if (size == null || size.height <= 0) return;
    _panVelocity =
        details.velocity.pixelsPerSecond /
        size.height /
        _zoom *
        _panSensitivity;
    if (_panVelocity == Offset.zero) return;
    _startInertia();
  }

  // Pinch/trackpad zoom arrives through the GestureDetector's scale
  // gesture above (and already keeps its focal point anchored, for free,
  // as a side effect of _handleScaleUpdate's own exact tracking) — a
  // plain mouse wheel never triggers that, so it needs its own
  // pointer-signal handler. Zooms toward wherever the cursor is, not the
  // screen center — matching a phone's pinch-to-zoom, which always
  // zooms wherever the fingers are, never forces the center.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final size = context.size;
    if (size == null) return;
    // A discrete scroll tick, unlike a finger's drag — no jitter to
    // filter out, so this always counts as a real zoom (see
    // [_handleScaleUpdate]'s own version of this for why that one needs
    // a threshold and this doesn't).
    if (_skyTooltipController.isOpen) _skyTooltipController.close();
    _stopInertia();
    _flyController.stop();
    final oldZoom = _zoom;
    final oldCamera = _camera;
    final anchor = screenToDirection(
      event.localPosition,
      oldCamera,
      oldZoom,
      size,
    );
    setState(() {
      _zoom = (oldZoom * math.exp(-event.scrollDelta.dy * 0.0015)).clamp(
        minZoomWithoutRepeats,
        _maxZoom,
      );
      final current = screenToDirection(
        event.localPosition,
        oldCamera,
        _zoom,
        size,
      );
      // See _handleScaleUpdate's comment — the rotation needed carries
      // [current] to [anchor], not the other way round.
      _camera = oldCamera.rotatedToAlign(current, anchor);
    });
  }

  /// Below this [zoomPercent] reading, a tap never resolves to an
  /// individual star — only to the constellation it's in (or a supernova).
  /// Zoomed out, a constellation's stars sit close enough together on
  /// screen that a tap aimed at the constellation as a whole kept
  /// resolving to whichever star happened to be nearest instead, which
  /// read as wrong (tapping a constellation shouldn't open a specific
  /// star at random). Zoomed in this far, stars are spread out enough on
  /// screen that a tap is unambiguously aimed at one of them specifically.
  /// See [_constellationZoomPercent]'s own doc comment for why this is
  /// that same value, not its own separate number.
  static const _starTapMinZoomPercent = _constellationZoomPercent;

  /// When and where the last tap that landed on *empty* sky happened —
  /// [_handleTapUp]'s own manual double-tap tracking, purely for
  /// [_zoomOutOneLevel]'s "double-tap empty sky to back out" gesture. Null
  /// whenever there's no such tap still eligible to be the first half of
  /// a double-tap.
  ///
  /// Deliberately not a real [GestureDetector.onDoubleTap] — registering
  /// one on the same detector as [onTapUp] would force *every* single tap
  /// (stars and constellations included) to wait out Flutter's own
  /// double-tap disambiguation window before firing at all, which read as
  /// a real, unwelcome lag on the app's single most common gesture. Empty
  /// sky is the only place a double-tap does anything, so tracking it by
  /// hand here — two plain taps close together in time and position, ordinary
  /// [onTapUp] firing immediately both times — gets the same gesture with
  /// no delay on everything else.
  DateTime? _lastEmptyTapTime;
  Offset? _lastEmptyTapPosition;

  static const _doubleTapWindow = Duration(milliseconds: 300);
  static const _doubleTapMaxDistance = 40.0;

  /// The tap-vs-hold split (see [_handleTapDown]/[_handleTapUp]/
  /// [_handleTapCancel]) is driven by a plain [Timer] off
  /// [GestureDetector]'s ordinary `onTapDown`/`onTapUp`/`onTapCancel`
  /// rather than its own `onLongPressStart` — a real
  /// `LongPressGestureRecognizer` on this same detector was tried first
  /// and broke [_MenuStarButton]'s own hold-to-open charge: that button
  /// times a hold purely through its own `onTapDown`/`onTapUp`/
  /// `onTapCancel` (see `_MenuStarButtonState._handlePressStart`/
  /// `_handlePressEnd`), and once a hold ran past
  /// [Duration(milliseconds: 500)] (`kLongPressTimeout`), the new
  /// long-press recognizer here self-accepted and won the gesture arena
  /// over the button's own tap recognizer — which fired *that* button's
  /// `onTapCancel` before its charge ever finished, so holding it no
  /// longer opened the menu. Timing the hold by hand off the very same
  /// `TapGestureRecognizer` this detector already had (rather than
  /// introducing a second, competing recognizer type) sidesteps that
  /// arena fight entirely — proven safe because [onTapUp] already
  /// coexisted fine with the button's own before this. Not tied to
  /// `kLongPressTimeout` at all any more, in fact — see [_holdDuration],
  /// itself just [kHoldGestureDuration].
  Timer? _holdTimer;

  /// How long a touch has to stay down before it counts as a hold rather
  /// than a tap — see [kHoldGestureDuration], shared with the menu
  /// button's own hold so the two gestures feel like one consistent
  /// timing across the screen.
  static const _holdDuration = kHoldGestureDuration;

  /// True once [_holdTimer] has actually fired for the touch currently
  /// down — [_handleTapUp] checks this to know the release is just the
  /// tail end of a hold that already acted, not a fresh plain tap.
  bool _holdFired = false;

  /// Drives [_HoldRingPainter]'s charging ring — runs in lockstep with
  /// [_holdTimer] (same [_holdDuration]) so the ring closes exactly as the
  /// hold fires, rather than as a separate, only-approximately-matching
  /// animation of its own.
  late final AnimationController _holdRingController;

  /// Screen position the ring is centered on — set once per touch in
  /// [_handleTapDown] (never moved while that touch stays down, same as
  /// [_holdTimer]'s own target) and only meaningful while
  /// [_holdRingController]'s value is above 0.
  Offset? _holdRingCenter;

  /// [_handleTapDown] doesn't start [_holdRingController] moving straight
  /// away — it waits this long first (see [_holdRingArmTimer]). A plain
  /// tap/click released before this elapses never gets the ring at all,
  /// which is the point: without this delay, a tap-down/up pair that
  /// lands and releases inside a single frame can leave the controller's
  /// `forward()` still scheduled with nothing left to cancel it — its
  /// value is still exactly 0 (the ticker hasn't ticked yet) when
  /// [_collapseHoldRing]'s old value-based guard ran, so that guard saw
  /// nothing to collapse and the forward animation then played out in
  /// full on the *next* frame with no release event left to stop it —
  /// the ring would finish closing and just sit there until some other
  /// gesture (a further tap, a pan/zoom) happened to reset it. Arming
  /// only after a short delay sidesteps the race entirely: nothing is
  /// ever scheduled for a genuinely quick tap to race against.
  static const _holdRingArmDelay = Duration(milliseconds: 100);
  Timer? _holdRingArmTimer;

  /// One real, continuous motor vibration for the length of a hold, via
  /// [Haptics]'s own native channel — [HapticFeedback] can only fire
  /// discrete, fixed-length system clicks, not a buzz of arbitrary
  /// duration. Started with a duration equal to [_holdDuration] the instant
  /// a hold begins charging (see [_handleTapDown]), it naturally stops
  /// exactly when the hold fires with nothing further to do;
  /// [_stopHoldHaptic] only has to cut it short for a release/cancel that
  /// comes *before* that.
  ///
  /// [_hapticActive] guards every call to [Haptics.cancel] here — the
  /// device only has one vibration motor, shared globally, not scoped per
  /// widget. [_handleTapDown]/[_handleTapCancel]/[_handleTapUp] all run
  /// for *every* touch on the sky's own full-screen `GestureDetector`,
  /// including one that lands on [_MenuStarButton] sitting on top of it
  /// (same hit-test chain, same pointer) — a touch [_hasHoldTarget] never
  /// found a target for. Calling [Haptics.cancel] unconditionally from
  /// those handlers used to cut the button's own, entirely unrelated
  /// hold-vibration short the moment this sky-side timer fired, since
  /// there's no way for the motor to know which caller's buzz it's
  /// silencing. Only cancelling when *this* class actually started the
  /// vibration keeps it from ever touching a buzz it doesn't own.
  bool _hapticActive = false;

  /// Out of [Haptics.vibrate]'s 1-255 range. On this project's own Xiaomi
  /// test device, dialing this between 10 and 30 changed nothing at all —
  /// turned out the `vibration` package's own `USAGE_ALARM` tag was the
  /// real culprit (see `Haptics`' own doc comment): the OS was substituting
  /// a fixed vendor haptic for that category regardless of what amplitude
  /// the app asked for. Routing through `Haptics` (tagged `USAGE_TOUCH`
  /// instead) is what made this constant the real dial it was meant to be.
  static const _hapticAmplitude = 10;

  void _startHoldHaptic() {
    _hapticActive = true;
    Haptics.vibrate(duration: _holdDuration, amplitude: _hapticAmplitude);
  }

  void _stopHoldHaptic() {
    if (!_hapticActive) return;
    _hapticActive = false;
    Haptics.cancel();
  }

  /// A short pulse for "a movement in the sky just started" (a plain tap
  /// hit, or the double-tap zoom-out) — the same motor-vibration mechanism
  /// as the hold's own long buzz above, just far shorter, rather than
  /// [HapticFeedback]'s separate, much lighter "system click" API: the two
  /// read as barely related in strength, which is exactly why this used
  /// to feel weak next to the hold's own buzz.
  static const _tapHapticDuration = Duration(milliseconds: 25);

  void _tapHaptic() {
    Haptics.vibrate(duration: _tapHapticDuration, amplitude: _hapticAmplitude);
  }

  /// A whoosh for the camera actually moving — called from both
  /// [_flyToWorld] (any tap/hold/search navigation) and [_zoomTo] (the
  /// double-tap zoom-out), the two places that ever animate [_zoom],
  /// right where each already knows both the zoom it's leaving and the
  /// one it's headed for. Silent for a pan that lands on the same zoom
  /// it started at — this is specifically about the zoom *changing*, not
  /// about a flight happening at all.
  void _playZoomTransitionSound(double fromZoom, double toZoom) {
    if (toZoom > fromZoom) {
      widget.audioService.playZoomInSound();
    } else if (toZoom < fromZoom) {
      widget.audioService.playZoomOutSound();
    }
  }

  /// Same three-step lookup [_resolveTapTarget] does, but read-only — no
  /// tooltip/flight side effects — so [_handleTapDown] can tell whether a
  /// hold starting here would actually land on something *before* the
  /// hold fires, purely to decide whether the charging ring/haptic are
  /// worth starting at all (never on empty sky).
  bool _hasHoldTarget(Offset position, Size size) {
    final hit = zoomPercent(_zoom) >= _starTapMinZoomPercent
        ? hitTestField(position, _placed, _camera, _zoom, size)
        : null;
    if (hit != null) return true;
    if (hitTestSupernovas(position, _camera, _zoom, size) != null) {
      return true;
    }
    return hitTestConstellations(position, _placed, _camera, _zoom, size) !=
        null;
  }

  void _handleTapDown(TapDownDetails details) {
    _holdFired = false;
    _holdTimer?.cancel();
    _holdRingArmTimer?.cancel();
    _holdRingArmTimer = null;
    _stopHoldHaptic();
    final size = context.size;
    final hasTarget = size != null && _hasHoldTarget(details.localPosition, size);
    if (hasTarget) {
      _holdRingCenter = details.localPosition;
      _holdRingArmTimer = Timer(_holdRingArmDelay, () {
        _holdRingArmTimer = null;
        _holdRingController.animateTo(
          1,
          duration: _holdDuration - _holdRingArmDelay,
        );
      });
      if (isTouchOnlyMobile) _startHoldHaptic();
    } else {
      _holdRingController.stop();
      _holdRingController.value = 0;
    }
    _holdTimer = Timer(_holdDuration, () {
      _holdTimer = null;
      _holdFired = true;
      // The ring's own job — showing the hold charging up — is done the
      // instant it fires; snapping it away rather than fading lets it read
      // as *becoming* the tooltip/flight that starts right here, instead
      // of lingering on top of it.
      _holdRingController.value = 0;
      _stopHoldHaptic();
      widget.audioService.playHoldSound();
      _handleHold(details.localPosition);
    });
  }

  /// Fires whenever the arena hands this touch to something else instead
  /// — most commonly a pan/zoom starting from the same spot, but also
  /// (see [_holdTimer]'s own doc comment) a nested control like
  /// [_MenuStarButton] winning its own tap outright. Either way, a
  /// pending hold that hasn't fired yet is no longer this touch's to act
  /// on.
  void _handleTapCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdRingArmTimer?.cancel();
    _holdRingArmTimer = null;
    _stopHoldHaptic();
    _collapseHoldRing();
  }

  /// Shared by [_handleTapCancel] and [_handleTapUp] — fades the charging
  /// ring away quickly (well under [_holdDuration]) rather than either
  /// snapping it off or letting it play out its own slower forward
  /// timing in reverse, which read as sluggish for a touch that's already
  /// gone. Checks [AnimationController.isAnimating], not just `value > 0`
  /// — see [_holdRingArmDelay]'s own doc comment for the race a
  /// value-only guard missed.
  void _collapseHoldRing() {
    if (_holdRingController.value > 0 || _holdRingController.isAnimating) {
      _holdRingController.animateTo(
        0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  /// Shared by [_handleTapUp] and [_handleHold] — both resolve a
  /// screen [position] to whichever of a star/supernova/constellation it
  /// landed on the exact same way, and only ever differ in what they do
  /// once they know: a plain tap ([showTooltip] false) only flies the
  /// camera there, a hold ([showTooltip] true) also opens that target's
  /// tooltip partway through the flight (see [_openStar]/[_flyToArea]/[_holdArea]/
  /// [_flyToConstellation]/[_holdConstellation]). Returns whether
  /// anything was actually hit, so [_handleTapUp] knows whether to fall
  /// through to its own empty-sky double-tap tracking.
  bool _resolveTapTarget(
    Offset position,
    Size size, {
    required bool showTooltip,
  }) {
    final hit = zoomPercent(_zoom) >= _starTapMinZoomPercent
        ? hitTestField(position, _placed, _camera, _zoom, size)
        : null;
    if (hit != null) {
      _openStar(hit.$1, hit.$2, showTooltip: showTooltip);
      return true;
    }
    // An invisible zone over each supernova's own icon — no visible change
    // to `SkySupernova`'s artwork, just the same tap-to-open-detail
    // behavior the Galaxy search popup's own Supernovas cards already have
    // (see [hitTestSupernovas]).
    final area = hitTestSupernovas(position, _camera, _zoom, size);
    if (area != null) {
      showTooltip ? _holdArea(area) : _flyToArea(area);
      return true;
    }
    // Same idea one level down: a tap that lands within a constellation's
    // own shape but not precisely on one of its stars (already handled
    // above) — see [hitTestConstellations].
    final constellation = hitTestConstellations(
      position,
      _placed,
      _camera,
      _zoom,
      size,
    );
    if (constellation != null) {
      showTooltip ? _holdConstellation(constellation) : _flyToConstellation(constellation);
      return true;
    }
    return false;
  }

  void _handleTapUp(TapUpDetails details) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdRingArmTimer?.cancel();
    _holdRingArmTimer = null;
    _stopHoldHaptic();
    // Captured before [_collapseHoldRing] below, which starts its own
    // reverse animation and would otherwise make `isAnimating` read true
    // regardless of whether a charge was actually in progress here.
    final holdWasCharging =
        _holdRingController.value > 0 || _holdRingController.isAnimating;
    _collapseHoldRing();
    // The hold already fired (and already did whatever it does — see
    // [_handleHold]) before this release arrived; the release itself is
    // not a second, separate tap on top of that.
    if (_holdFired) return;
    // A hold that started charging — the ring was already visibly on
    // screen — but let go before firing isn't a tap either: it's an
    // abandoned hold, and should read as exactly that. Falling through to
    // plain-tap handling here used to fly the camera (or close an open
    // tooltip) right after the user watched the ring cancel, which read
    // as the sky ignoring the cancellation instead of honoring it.
    if (holdWasCharging) return;
    final size = context.size;
    if (size == null) return;
    // While a tooltip is showing, the first tap anywhere else only
    // closes it — it doesn't also act on whatever's underneath. Without
    // this, a tap meant purely to dismiss (say) a star's tooltip could
    // also fly the camera to, and hold open a tooltip for, the
    // constellation sitting right behind it, which read as the sky
    // ignoring the dismissal entirely. A second, deliberate tap/hold is
    // what reaches that target now — this one is fully swallowed.
    if (_skyTooltipController.isOpen) {
      _skyTooltipController.close();
      _lastEmptyTapTime = null;
      _lastEmptyTapPosition = null;
      return;
    }
    if (_resolveTapTarget(details.localPosition, size, showTooltip: false)) {
      // A short buzz for "a movement in the sky just started" — the
      // hold's own long buzz (see [_startHoldHaptic]) means "a tooltip
      // just opened" instead, so this only ever fires from a plain tap.
      if (isTouchOnlyMobile) _tapHaptic();
      widget.audioService.playTapSound();
      _lastEmptyTapTime = null;
      return;
    }

    // Empty sky — see if this completes a double-tap with the previous
    // empty-sky tap (see [_lastEmptyTapTime]'s own doc comment).
    final now = DateTime.now();
    final lastTime = _lastEmptyTapTime;
    final lastPosition = _lastEmptyTapPosition;
    if (lastTime != null &&
        lastPosition != null &&
        now.difference(lastTime) < _doubleTapWindow &&
        (details.localPosition - lastPosition).distance < _doubleTapMaxDistance) {
      _lastEmptyTapTime = null;
      _lastEmptyTapPosition = null;
      // Same "a movement just started" buzz as a direct hit above — the
      // zoom-out this triggers is exactly that, just aimed at empty sky
      // instead of a target. No tap sound here though: this isn't a tap
      // on anything, it's a camera move, and [_zoomOutOneLevel] already
      // plays its own whoosh via [_playZoomTransitionSound].
      if (isTouchOnlyMobile) _tapHaptic();
      _zoomOutOneLevel();
      return;
    }
    _lastEmptyTapTime = now;
    _lastEmptyTapPosition = details.localPosition;
  }

  /// The hold counterpart to [_handleTapUp], fired by [_holdTimer] (see
  /// its own doc comment for why this is a plain timer rather than
  /// `onLongPressStart`) — same hit test (see [_resolveTapTarget]), but a
  /// hit's tooltip opens partway through the resulting flight (see
  /// [_openTooltipDuringFlight]) rather than staying suppressed.
  ///
  /// Unlike [_handleTapUp], an already-open tooltip does *not*
  /// unconditionally swallow this — only a hold that misses every real
  /// target (empty sky) behaves like the tap-only "first interaction
  /// outside just closes it" rule. A hold that lands on a genuine
  /// star/pulsar/constellation/supernova is a deliberate "go there
  /// instead": whatever tooltip was already open just gets replaced by
  /// the new one once the resulting flight lands there (`open()` with
  /// different data already handles that transition on its own — see
  /// [TooltipCardController.open]'s own doc comment — so this never needs
  /// an explicit close first).
  void _handleHold(Offset position) {
    final size = context.size;
    if (size == null) return;
    final hit = _resolveTapTarget(position, size, showTooltip: true);
    if (!hit && _skyTooltipController.isOpen) {
      _skyTooltipController.close();
      _lastEmptyTapTime = null;
      _lastEmptyTapPosition = null;
    }
  }

  /// The plain-tap half of a supernova hit — just the "take me there"
  /// flight every other target in the app gets, camera only, no tooltip.
  /// See [_holdArea] for the hold half, which adds the tooltip back in.
  void _flyToArea(LifeArea area) {
    _flyTo(SkyAreaTarget(area));
  }

  /// The hold half of a supernova hit — same flight as [_flyToArea], plus
  /// its own tooltip (see [_buildSkyTooltip]), opened partway through
  /// rather than waiting for it to land (see
  /// [_openTooltipDuringFlight]) — a tap on a supernova used to push
  /// [AreaDetailScreen] straight away, replaced first by just the camera
  /// movement and now by this tooltip's own [_viewArea] instead.
  void _holdArea(LifeArea area) {
    _openTooltipDuringFlight(_flyTo(SkyAreaTarget(area)), _AreaTooltip(area));
  }

  /// See [_flyToArea]'s own note — same plain-tap/camera-only split, for
  /// constellations.
  void _flyToConstellation(PlacedConstellation constellation) {
    _flyTo(SkyProjectTarget(constellation.project));
  }

  /// See [_holdArea]'s own note — same change, for constellations. Also
  /// straightens the camera's roll as it flies there (see
  /// [_flyToWorld]'s own `straightenRoll`), so the shape lands reading
  /// upright — the way it does in the shape editor — rather than however
  /// the camera happened to be twisted from an earlier manual rotation.
  void _holdConstellation(PlacedConstellation constellation) {
    _openTooltipDuringFlight(
      _flyTo(SkyProjectTarget(constellation.project), straightenRoll: true),
      _ConstellationTooltip(constellation),
    );
  }

  /// Steps back one rung of the [_areaZoomPercent]/
  /// [_constellationZoomPercent]/[_starZoomPercent] ladder from wherever
  /// [_zoom] currently sits — the largest rung strictly below it, or
  /// [_zoomOutFloorPercent] once already at or below the lowest one.
  /// Orientation is left exactly as it is; only zoom moves (see [_zoomTo]).
  void _zoomOutOneLevel() {
    const rungs = [
      _zoomOutFloorPercent,
      _areaZoomPercent,
      _constellationZoomPercent,
      _starZoomPercent,
    ];
    final currentPercent = zoomPercent(_zoom);
    // Already as far out as it goes — nothing to animate or announce.
    // Without this, [zoomFromPercent]'s log/exp round trip can land a
    // hair above [_zoom] even when both mean "the floor", which
    // [_playZoomTransitionSound] then misreads as a genuine zoom-in and
    // plays a whoosh for a tap that visibly did nothing.
    if (currentPercent <= _zoomOutFloorPercent + 0.5) return;
    var target = _zoomOutFloorPercent;
    for (final rung in rungs) {
      // A tiny margin below the current reading — without it, being
      // already sitting *exactly* on a rung (the usual case, having just
      // flown to one) would count that same rung as "below" itself due to
      // ordinary floating-point noise, and go nowhere.
      if (rung < currentPercent - 0.5) target = rung;
    }
    _zoomTo(zoomFromPercent(target).clamp(minZoomWithoutRepeats, _maxZoom));
  }

  /// Animates [_zoom] alone to [targetZoom], camera orientation
  /// unchanged — the zoom-only half of what [_flyToWorld] does, without
  /// its azimuth/elevation round-trip (there's no new direction to aim
  /// at here, just [_camera]'s own current one, exactly).
  void _zoomTo(double targetZoom) {
    _stopInertia();
    _playZoomTransitionSound(_zoom, targetZoom);
    _flyStartCamera = _camera;
    _flyTargetForward = _camera.forward;
    _flyStartZoom = _zoom;
    _flyTargetZoom = targetZoom;
    _flyRollCorrection = 0;
    _flyController
      ..stop()
      ..reset()
      ..forward();
  }

  /// Opens the small centered dialog that flips [_showGridControl]/
  /// [_showZoomControl]/[_showRotationControl] — a `StatefulBuilder` wraps
  /// its own content so each switch's own animation plays immediately
  /// inside the dialog itself, rather than waiting on `SkyScreen`'s own
  /// next rebuild; [setState] is still called alongside it on every change
  /// so the sky behind the (translucent) dialog barrier actually shows/
  /// hides each control as you go, not just once the dialog is dismissed.
  Future<void> _showUiControlsMenu(BuildContext context) async {
    final colors = context.colors;
    final strings = context.strings;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setSheetState) {
            Widget row(String label, bool value, ValueChanged<bool> onChanged) {
              return SwitchListTile(
                title: Text(label, style: TextStyle(color: colors.text)),
                value: value,
                onChanged: (newValue) {
                  onChanged(newValue);
                  setSheetState(() {});
                },
              );
            }

            return AlertDialog(
              title: Text(
                'Display',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row(
                    'Grid',
                    _showGridControl,
                    (value) => setState(() => _showGridControl = value),
                  ),
                  row(
                    'Zoom',
                    _showZoomControl,
                    (value) => setState(() => _showZoomControl = value),
                  ),
                  // Omitted on mobile — see [isTouchOnlyMobile]: there's
                  // nothing to toggle when the roll knob itself never shows.
                  if (!isTouchOnlyMobile)
                    row(
                      'Rotation',
                      _showRotationControl,
                      (value) => setState(() => _showRotationControl = value),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.closeAction),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // See [isTouchOnlyMobile]'s own doc comment for why mobile drops this
    // regardless of the (still user-toggleable, for every other platform)
    // [_showRotationControl] preference.
    final showRotation = _showRotationControl && !isTouchOnlyMobile;

    return PopScope(
      // The quick-look panel isn't a route of its own — a back gesture/
      // button with it open should close it (same as tapping its own X)
      // rather than leaving the sky screen entirely.
      canPop: _quickLookConstellation == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSkyTooltip();
      },
      child: Scaffold(
        key: _scaffoldKey,
        // The sky is dragged edge to edge to look around, so the drawer must
        // never claim an edge-swipe of its own — it opens from its button and
        // nowhere else.
        drawerEdgeDragWidth: 0,
        drawer: SkyMenuDrawer(
          onLightAStar: _openStarForm,
          onNewConstellation: _openNewConstellation,
          onVisions: _openVisions,
          onShootingStars: _openShootingStars,
          onSearch: _openSearch,
          onStatistics: _openStatistics,
          onAdmire: _openAdmire,
          onFriends: _openFriends,
          onSettings: _openSettings,
          onMetaphor: _openMetaphor,
        ),
        body: Stack(
          children: [
            Listener(
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NebulaBackground(
                      camera: _camera,
                      zoom: _zoom,
                      showGrid: widget.settings.showGrid,
                    ),
                    // An inert, invisible full-screen anchor purely so the
                    // "sky-navigation" tour's first step has *something* to
                    // spotlight — the sky itself is one hand-drawn canvas,
                    // not discrete per-star widgets, so there's no single
                    // real widget for "here's how to look around" to point
                    // at. IgnorePointer keeps it out of the gesture arena
                    // entirely; it never affects a real tap/pan/pinch.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: HintTarget(
                          tour: 'sky-navigation',
                          order: 1,
                          showArrow: true,
                          contentBuilder: appTourStepCard,
                          title: context.strings.skyTourLookAroundTitle,
                          description: context.strings.skyTourLookAroundBody,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    // A decorative sigil behind each supernova — see
                    // sky_area_sigils.dart. Painted before SkySupernova so that
                    // widget's own glow/icon sit on top of it, not the other
                    // way round.
                    SkyAreaSigils(camera: _camera, zoom: _zoom),
                    // Alternative takes on this slot, tried in order —
                    // SkyDecorations (spiral nebula + supernova per area),
                    // SkyWisps (wispy Hubble-style filaments), SkyBlackHole (a
                    // lensed black hole) — all disabled in favor of SkySupernova
                    // (one simple lens-flare-style star) while the visual style
                    // is explored; swap which one's active here to compare, none
                    // of the files are deleted.
                    SkySupernova(camera: _camera, zoom: _zoom),
                    AnimatedConstellationField(
                      placed: _placed,
                      camera: _camera,
                      zoom: _zoom,
                      flareProgram: _flareProgram,
                      // See [kSkyStarPalette]: a white core with a gold glow
                      // around it for anything burning, matching `SkySupernova`'s
                      // own icons (a plain white glyph over a gold gradient
                      // border/glow), and the blue/white families for everything
                      // that isn't.
                      palette: kSkyStarPalette,
                      revision: _revision,
                    ),
                    // The way into everything that isn't the sky itself — same
                    // disc/navy/gold styling as every other overlay control.
                    // There's no nav bar left for it to duplicate: this button
                    // *is* the app's navigation (or was, before the star FAB —
                    // see [_showDrawerButton]).
                    if (_showDrawerButton)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Material(
                              color: colors.nightPanel.withValues(alpha: 0.75),
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: colors.gold,
                                  width: kBorderWidthActive,
                                ),
                              ),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Tooltip(
                                    message: strings.openMenuAction,
                                    child: Icon(
                                      Icons.menu,
                                      color: colors.gold,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // The one overlay control with its colors inverted (solid
                    // gold, dark text/icon) rather than the translucent navy disc
                    // every other control uses — top-center and the most
                    // prominent thing here on purpose, since it's the fastest way
                    // off "wander and hope" navigation into the search popup.
                    if (_showSearchButton)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    kRadiusField,
                                  ),
                                  boxShadow: goldGlow(
                                    colors,
                                    strength: 1.1,
                                    size: 56,
                                  ),
                                ),
                                child: Material(
                                  color: colors.gold,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      kRadiusField,
                                    ),
                                    // Dark navy rather than the gold every other
                                    // control's border uses — this button's own fill
                                    // is already gold, so a gold border would
                                    // disappear into it.
                                    side: BorderSide(
                                      color: colors.night,
                                      width: kBorderWidthActive,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      kRadiusField,
                                    ),
                                    onTap: _openSearch,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search,
                                            color: colors.onGold,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            strings.searchButtonLabel,
                                            style: TextStyle(
                                              color: colors.onGold,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Always visible regardless of the three toggles below — it's
                    // the only way back to turning them on again, so it can't be
                    // one of the things it itself hides.
                    if (_showUiControlsButton)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Material(
                              color: colors.nightPanel.withValues(alpha: 0.75),
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: colors.gold,
                                  width: kBorderWidthActive,
                                ),
                              ),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _showUiControlsMenu(context),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(
                                    Icons.tune,
                                    color: colors.gold,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // The three toggleable controls (Grid/Zoom/Rotation), left to
                    // right along the bottom — one shared row rather than three
                    // independently-positioned corners, so [FittedBox] can shrink
                    // all three together (never grow them past their natural
                    // size) whenever a narrow screen can't fit them side by side
                    // at full size; on anything wide enough, this is a no-op and
                    // they render exactly as big as they'd otherwise be.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (_showGridControl)
                                    Material(
                                      color: colors.nightPanel.withValues(
                                        alpha: 0.75,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _bottomPillRadius,
                                        ),
                                        side: BorderSide(
                                          color: colors.gold,
                                          width: kBorderWidthActive,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                        ),
                                        child: SizedBox(
                                          height: _bottomPillHeight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Grid',
                                                style: TextStyle(
                                                  color: colors.muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              // Scaled down 20% along with the other
                                              // two sky-overlay controls (see
                                              // [_RollKnob]/[_ZoomSlider]'s own
                                              // sizing) — Switch has no size
                                              // parameter of its own, so this is the
                                              // plain way to shrink it without
                                              // losing its built-in tap/thumb-
                                              // animation behavior.
                                              // Colors come from the app's own
                                              // switch theme, same as every other
                                              // switch; only the 20% shrink is
                                              // local, matching the other two
                                              // sky-overlay controls' sizing.
                                              Transform.scale(
                                                scale: 0.8,
                                                child: Switch(
                                                  value:
                                                      widget.settings.showGrid,
                                                  onChanged: (value) {
                                                    widget.settings.setShowGrid(
                                                      value,
                                                    );
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_showGridControl &&
                                      (_showZoomControl || showRotation))
                                    const SizedBox(width: 12),
                                  if (_showZoomControl)
                                    _ZoomSlider(
                                      zoom: _zoom,
                                      minZoom: minZoomWithoutRepeats,
                                      maxZoom: _maxZoom,
                                      onChanged: (value) {
                                        if (_skyTooltipController.isOpen) {
                                          _skyTooltipController.close();
                                        }
                                        _stopInertia();
                                        _flyController.stop();
                                        setState(() => _zoom = value);
                                      },
                                    ),
                                  if (_showZoomControl && showRotation)
                                    const SizedBox(width: 12),
                                  // Touch already has its own two-finger rotate
                                  // gesture (see `_handleScaleUpdate`'s
                                  // `details.rotation`), which is exactly why this
                                  // knob is hidden outright on mobile (see
                                  // [isTouchOnlyMobile]) — kept on desktop/web,
                                  // where there's no such gesture without it, and
                                  // still user-toggleable there via
                                  // [_showUiControlsMenu].
                                  if (showRotation)
                                    _RollKnob(
                                      angle: cameraRollAngle(_camera),
                                      onRoll: (delta) {
                                        if (_skyTooltipController.isOpen) {
                                          _skyTooltipController.close();
                                        }
                                        _stopInertia();
                                        _flyController.stop();
                                        setState(
                                          () => _camera = _camera.rolled(delta),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The star FAB — an alternative way into the same menu the
                    // drawer opens (see [_openMenuModal]), tried alongside the
                    // drawer rather than replacing it. Deliberately not a disc/
                    // chrome control like every other overlay button here: no
                    // filled background, just a glowing gold ring around a
                    // white glyph — as close to [SkySupernova]'s own "white
                    // glyph inside a gold ring, glowing outward" look as a
                    // plain widget (no shader) can get, so it reads as one
                    // more thing burning up there rather than as UI sitting on
                    // top of it.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: HintTarget(
                              tour: 'sky-navigation',
                              order: 2,
                              showArrow: true,
                              // The spotlight's own hole is sized to the
                              // button's bounds plus this padding — the
                              // default (8px) is far smaller than
                              // [_TourGlow]'s blur/spread, so most of the
                              // glow was being covered right back up by
                              // the scrim surrounding that tight hole.
                              // Confirmed live: the glow only became
                              // genuinely visible once the hole was
                              // widened enough to contain the whole
                              // painted glow, not just the button itself.
                              spotlightPadding: kTourGlowSpotlightPadding,
                              // A circle, not the default rounded rect —
                              // matches the button's own round shape
                              // instead of leaving dimmed corners inside
                              // a squared-off hole.
                              spotlight: SpotlightShape.circle,
                              contentBuilder: appTourStepCard,
                              title: context.strings.skyTourMenuTitle,
                              description: context.strings.skyTourMenuBody,
                              child: TourGlow(
                                tour: 'sky-navigation',
                                order: 2,
                                shape: BoxShape.circle,
                                color: context.colors.gold,
                                child: _MenuStarButton(onTap: _openMenuModal),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // A dedicated way into the Sound Lab (see
                    // `SoundLabScreen`) — top-right, clear of every other
                    // control here. Placed for quick access while there's
                    // a growing pool of candidate sounds to audition;
                    // nothing behind it is destructive, so it's fine to
                    // stay one tap away rather than buried in Settings.
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: HintTarget(
                            tour: 'sky-navigation',
                            order: 3,
                            showArrow: true,
                            // See the menu button's own HintTarget above.
                            spotlightPadding: kTourGlowSpotlightPadding,
                            spotlight: SpotlightShape.circle,
                            contentBuilder: appTourStepCard,
                            title: context.strings.skyTourSoundLabTitle,
                            description: context.strings.skyTourSoundLabBody,
                            child: TourGlow(
                              tour: 'sky-navigation',
                              order: 3,
                              shape: BoxShape.circle,
                              color: context.colors.gold,
                              child: _SkyOverlayButton(
                                icon: Icons.graphic_eq,
                                tooltip: context.strings.soundLabButtonTooltip,
                                onTap: _openSoundLab,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The hold-charging ring (see [_handleTapDown]/
                    // [_holdRingController]) — last so it paints above
                    // every star/constellation/control here, never under
                    // them. Purely decorative: [IgnorePointer] keeps it out
                    // of hit-testing entirely, so it can't itself become
                    // one more thing competing for the gesture arena (see
                    // [_holdTimer]'s own doc comment on why that's worth
                    // avoiding).
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _holdRingController,
                        builder: (context, _) => CustomPaint(
                          painter: _HoldRingPainter(
                            center: _holdRingCenter,
                            progress: _holdRingController.value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // A lit star's quick-look tooltip needs a real [ShareableLitStarCard]
            // laid out (not just described) somewhere to capture — see
            // [_shareQuickLookStar] — rendered here, far to the side, so it's
            // never actually visible: [Opacity] would skip painting it
            // entirely at 0, which [RenderRepaintBoundary.toImage] needs to
            // have happened at least once, so an off-screen [Positioned] is
            // used instead.
            if (_quickLookStar case final star? when star.isLit)
              Positioned(
                left: -MediaQuery.sizeOf(context).width * 2,
                top: 0,
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: RepaintBoundary(
                  key: _quickLookShareKey,
                  child: ShareableLitStarCard(
                    star: star,
                    project: _quickLookConstellation?.project,
                  ),
                ),
              ),
            // The tap tooltip itself — see [_skyTooltipOverlay]'s own doc
            // comment for why the actual `TooltipCard` is a cached field
            // rather than built fresh right here. This [ListenableBuilder]
            // is a thin wrapper that *does* rebuild on every
            // [_skyTooltipController] change (exactly what
            // [_tooltipAnchorOffset] needs, to react to which kind of
            // tooltip just opened) — but since it hands the identical
            // [_skyTooltipOverlay] instance down as `child` every time,
            // `TooltipCard` itself never sees a reason to rebuild, so this
            // adds no risk of reintroducing that field's own bug.
            ListenableBuilder(
              listenable: _skyTooltipController,
              builder: (context, child) => Transform.translate(
                offset: _tooltipAnchorOffset(_skyTooltipController.data),
                child: child,
              ),
              child: _skyTooltipOverlay!,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the `TooltipCard` that hosts [_buildSkyTooltip] — split out
  /// from `build()` and only ever called from [didChangeDependencies] (see
  /// [_skyTooltipOverlay]'s own doc comment). `TooltipCard` already
  /// listens to [_skyTooltipController] itself and re-invokes its own
  /// `builder` callback whenever the controller opens/closes/changes data
  /// (that's the entire point of handing it a controller instead of
  /// driving its visibility from outside) — so it was never necessary to
  /// rebuild *this widget* on every one of this screen's own `setState`
  /// calls. Doing so anyway ran head-first into a real bug in
  /// `tooltip_card` 2.9.0: its `didUpdateWidget` unconditionally calls
  /// `OverlayEntry.markNeedsBuild()` on the tooltip's already-mounted
  /// overlay entry whenever this widget is handed a new instance while
  /// that entry still exists — which, called synchronously while *this*
  /// screen's own build was already in progress (which it always was,
  /// since a plain `setState` is exactly what got a new instance built in
  /// the first place), is an illegal cross-tree `markNeedsBuild` "during
  /// build". Flutter throws for it, and every frame after that first
  /// throw kept failing the same way ("Each child must be laid out
  /// exactly once") — the sky was still technically listening to pan/zoom
  /// gestures, it just could never successfully render the result, which
  /// read as the whole screen being stuck. Reproduced live on-device: the
  /// exact assertion showed up in the log the instant the first tooltip
  /// opened, and pan/zoom stayed dead afterward exactly as described.
  /// Keeping this widget's own instance stable (rebuilt only when the
  /// theme or screen size actually changes, never for a plain pan/zoom/
  /// inertia/fly frame) means Flutter's own `identical`-widget fast path
  /// skips `didUpdateWidget` entirely on those frames, so the buggy call
  /// never fires.
  Widget _buildSkyTooltipOverlay(AppColors colors) {
    return Center(
      child: TooltipCard.builder(
        controller: _skyTooltipController,
        placementSide: TooltipCardPlacementSide.bottom,
        flyoutBackgroundColor: colors.nightPanel,
        borderColor: colors.nightBorder,
        beakColor: colors.nightPanel,
        borderRadius: BorderRadius.circular(kRadiusCard),
        elevation: 8,
        // `tooltip_card`'s own position delegate caps width by
        // horizontal clearance to *one* screen edge from the
        // anchor — correct for a start/end placement, but overly
        // conservative for a `bottom` one like this: it never
        // accounts for a centered card only needing *half* its
        // width of clearance on each side, and it ignores
        // `minWidth` outright. With the anchor dead center that
        // halves the usable width for no real reason, so
        // `fitToViewport` is off here and this `maxWidth` (well
        // under any real phone's screen width, minus its own
        // small clamp margin) is what actually keeps it on
        // screen instead.
        fitToViewport: false,
        constraints: BoxConstraints(
          maxWidth: math.min(380, MediaQuery.sizeOf(context).width - 48),
        ),
        padding: const EdgeInsets.all(20),
        // `TooltipCard`'s own default (`WhenContentHide.goAway`) auto-closes
        // on the pointer leaving the panel — meant for a *hover*-triggered
        // tooltip, but it applies to any "press-like" trigger mode
        // (including this one's default, `pressButton`, even though this
        // controller only ever opens/closes it by hand, never via the
        // trigger's own tap). On web that reads as the tooltip vanishing
        // the instant the mouse drifts off it while reading, with no
        // click involved at all. `pressOutSide` turns that auto-close off;
        // pairing it with an explicit `barrierDismissible: false` stops it
        // from also inserting `tooltip_card`'s own dismiss-on-outside-tap
        // barrier, which — being a full-screen `HitTestBehavior.opaque`
        // `GestureDetector` sitting above everything in the root overlay —
        // would otherwise swallow every tap before the sky's own
        // hand-rolled tap/hold arena handling (see [_holdTimer]'s doc
        // comment) ever saw it. Dismissal here stays exactly what it
        // already was: this screen's own explicit `close()` calls.
        whenContentHide: WhenContentHide.pressOutSide,
        barrierDismissible: false,
        child: const SizedBox.shrink(),
        builder: (context, close) => _buildSkyTooltip(),
      ),
    );
  }

  /// The tooltip's own content — a star's quick-look, a pulsar's, a
  /// constellation's, or a supernova's — chosen by
  /// [_skyTooltipController]'s current `data`. `null` (nothing open, or
  /// the exit-animation frame after a close) renders empty: `TooltipCard`
  /// itself decides whether that's ever actually visible.
  Widget _buildSkyTooltip() {
    return switch (_skyTooltipController.data) {
      _StarTooltip(:final constellation, :final starIndex) =>
        _buildStarTooltip(constellation, starIndex),
      _PulsarTooltip(:final constellation, :final habit) =>
        _buildPulsarTooltip(constellation, habit),
      _ConstellationTooltip(:final constellation) => SkyConstellationTooltip(
        project: constellation.project,
        stars: constellation.stars,
        onClose: _closeSkyTooltip,
        onView: () => _viewConstellation(constellation),
      ),
      _AreaTooltip(:final area) => SkyAreaTooltip(
        area: area,
        starCount: starsInArea(
          area,
          widget.projectRepository,
          widget.starRepository,
        ),
        onClose: _closeSkyTooltip,
        onView: () => _viewArea(area),
      ),
      null => const SizedBox.shrink(),
    };
  }

  /// How far below the tooltip's own dead-center anchor each kind of
  /// popup actually renders — see the [ListenableBuilder] in [build] that
  /// applies this. A constellation's own shape is usually still on screen
  /// above the anchor, which crowded its tooltip into the shape's own
  /// lower stars, so it drops the farthest; a supernova's is just one
  /// icon, so it needs less; a star's already reads fine right under
  /// wherever it just flew to, so it only nudges down slightly. Plain
  /// tuned numbers, not derived from anything — adjust them directly if
  /// the amount ever needs to change.
  static const _starTooltipDrop = 15.0;
  static const _areaTooltipDrop = 35.0;
  static const _constellationTooltipDrop = 120.0;

  Offset _tooltipAnchorOffset(_SkyTooltip? data) => switch (data) {
    _ConstellationTooltip() => const Offset(0, _constellationTooltipDrop),
    _AreaTooltip() => const Offset(0, _areaTooltipDrop),
    _StarTooltip() || _PulsarTooltip() => const Offset(0, _starTooltipDrop),
    null => Offset.zero,
  };

  /// A pulsar's own version of [_buildStarTooltip] — no stale-index guard
  /// needed here (unlike a star, [_PulsarTooltip] carries the [Habit]
  /// itself, not an index to re-look-up), but streak/lit are recomputed
  /// fresh from [HabitCompletionRepository] every build rather than
  /// cached at hold-time, same "never show stale content" reasoning.
  Widget _buildPulsarTooltip(PlacedConstellation constellation, Habit habit) {
    final countsByDay = habitCompletionCountsByDay(
      widget.habitCompletionRepository.getAllForHabit(habit.id),
    );
    return SkyPulsarTooltip(
      habit: habit,
      project: constellation.project,
      currentStreak: habitCurrentStreak(habit, countsByDay),
      isLit: !habit.dead && isHabitLit(habit, countsByDay),
      onClose: _closeSkyTooltip,
      onView: _viewQuickLookPulsar,
    );
  }

  /// Split out from [_buildSkyTooltip] only because a [_StarTooltip]'s own
  /// [starIndex] can go stale (the star it pointed to was deleted
  /// elsewhere, e.g. from [StarReaderScreen] reached some other way) —
  /// this is the one spot that has to guard for that rather than assume
  /// the index is always still valid.
  Widget _buildStarTooltip(PlacedConstellation constellation, int starIndex) {
    if (starIndex >= constellation.stars.length) {
      return const SizedBox.shrink();
    }
    final star = constellation.stars[starIndex];
    return SkyStarTooltip(
      star: star,
      project: constellation.project,
      onClose: _closeSkyTooltip,
      onView: _viewQuickLookStar,
      onEdit: _editQuickLookStar,
      onShare: star.isLit ? _shareQuickLookStar : null,
      onDelete: star.dead ? null : _deleteQuickLookStar,
    );
  }

  Future<void> _viewConstellation(PlacedConstellation constellation) async {
    _closeSkyTooltip();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConstellationScreen(
          project: constellation.project,
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          habitRepository: widget.habitRepository,
          habitCompletionRepository: widget.habitCompletionRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _viewArea(LifeArea area) async {
    _closeSkyTooltip();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailScreen(
          area: area,
          areaVisionRepository: widget.areaVisionRepository,
          reflectionAnswerRepository: widget.reflectionAnswerRepository,
          projectRepository: widget.projectRepository,
          starRepository: widget.starRepository,
        ),
      ),
    );
    _refresh();
  }
}

/// Paints the hold-charging ring (see [_SkyScreenState._holdRingController])
/// — a single white arc that grows clockwise from a point at [center] and
/// closes into a full circle exactly as [progress] reaches 1, with a soft
/// white glow trailing behind the same stroke.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.center, required this.progress});

  final Offset? center;
  final double progress;

  // Three different pointers, three different sizes: native mobile touch
  // is a fingertip wide enough to cover the original size outright (bumped
  // up here), web's is a small mouse cursor (shrunk so the ring wraps it
  // closely instead of reading as oversized), and native desktop's mouse
  // keeps the size this had before either of those were split out.
  static double get _radius => isTouchOnlyMobile ? 50.0 : (kIsWeb ? 14.0 : 28.0);
  static double get _strokeWidth =>
      isTouchOnlyMobile ? 4.5 : (kIsWeb ? 2.0 : 3.0);
  static double get _glowBlur =>
      isTouchOnlyMobile ? 16.0 : (kIsWeb ? 6.0 : 10.0);
  // Starts straight up, same convention as a clock/loading-spinner face,
  // so the point it grows from and reconnects at reads as a fixed anchor
  // rather than an arbitrary spot on the ring.
  static const _startAngle = -math.pi / 2;

  // [center] is the raw pointer position — for a mouse that's the arrow
  // cursor's own hotspot, right at its tip, not the middle of the glyph
  // people actually see. Only on web does anything paint an OS cursor on
  // top of this at all (mobile has a finger, desktop native hides the
  // cursor while a button is held), so only there does the ring need
  // nudging down by roughly the arrow's own tip-to-visual-center offset
  // for the cursor to end up looking centered inside it, rather than
  // poking out through its top edge. Horizontally left near 0 — an
  // earlier rightward nudge here overshot and left the cursor reading as
  // stuck against the ring's own left edge instead of centered.
  static const _webCursorOffset = Offset(1, 8);

  @override
  void paint(Canvas canvas, Size size) {
    final rawCenter = this.center;
    if (rawCenter == null || progress <= 0) return;
    final center = kIsWeb ? rawCenter + _webCursorOffset : rawCenter;
    final sweep = progress * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: _radius);

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth * 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _glowBlur);
    canvas.drawArc(rect, _startAngle, sweep, false, glow);

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweep, false, ring);
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.progress != progress;
}

/// A small, chrome-disc icon button floating directly on the sky — see the
/// Sound Lab entry point's own doc comment for why this one exists.
/// [skyControlDecoration] is the app's one "control that sits on the sky
/// itself rather than on a page" surface (translucent panel, gold ring),
/// defined in `app_style.dart` but never actually used until now.
class _SkyOverlayButton extends StatelessWidget {
  const _SkyOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: skyControlDecoration(colors, circle: true),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, color: colors.gold, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// The FAB's own dedicated supernova — the same glow [SkySupernova] draws
/// for each life area (see `shaders/menu_star_button.frag`, a stripped
/// copy of `shaders/sky_supernova.frag` with the 3D camera projection
/// removed, since this one never moves: it always sits fixed right behind
/// the menu button, no area icon, no rotating sigil, nothing else that
/// belongs to a real supernova on the sky). [Icons.star] (the plain solid
/// star) sits on top, blended into the glow with [BlendMode.overlay] (see
/// [_MenuStarSupernovaPainter.paint]) rather than pasted flat on top of
/// it — [Icons.stars] was tried alongside it too, but turned out to *be*
/// a disc with a star-shaped hole cut out rather than a separate glyph,
/// so it's hidden now.
class _MenuStarButton extends StatefulWidget {
  const _MenuStarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MenuStarButton> createState() => _MenuStarButtonState();
}

class _MenuStarButtonState extends State<_MenuStarButton>
    with TickerProviderStateMixin {
  // 2/3 of the previous (95) pass, rounded, nudged down slightly again.
  // Still what the ring/glow/canvas below size themselves off of — see
  // [_starGlyphSize] for the star glyph's own, now-separate size.
  static const _iconSize = 58.0;
  // The star glyph itself, slightly smaller again than [_iconSize] —
  // split out from it on purpose: shrinking [_iconSize] directly would
  // have pulled the ring in to match too (see [_scale] below, sized off
  // [_iconSize]), when only the star itself was asked to shrink this
  // time.
  static const _starGlyphSize = _iconSize * 0.9;
  static const _tapTargetSize = 110.0;
  // Big enough that the shader's own glow/spikes fade out naturally well
  // before this canvas's own edge, rather than clipping hard against a
  // boundary that's part of the visible glow.
  static const _glowCanvasSize = _iconSize * 6;
  // The shader's own ring sits at a fixed 0.09 (world units, not pixels).
  // iconSize/(2*0.09) alone puts its diameter at exactly the icon's own
  // — the *0.85 pulls it in a little further, so the ring's own radius
  // (not diameter) lands right at the icon's edge instead of sitting
  // just outside it.
  static const _scale = _iconSize / (2 * 0.09) * 0.85;
  // The white ring + white star glyph [_MenuStarSupernovaPainter] used
  // to draw on top of the shader's own glow are swapped out for the
  // app's actual logo below, while a couple of looks are being compared
  // — off rather than deleted, so flipping it back to true restores
  // them exactly as they were.
  static const _showStarRingIcon = false;
  // The same disc already used at the top of the menu (see
  // [SkyMenuContent._logoAsset]) at that exact same size, but with its
  // gold ring/disc recolored to white — a plain asset swap (see
  // assets/icon/app_icon_ring_centered_white.png) rather than a runtime
  // tint. The header keeps the original gold version.
  static const _logoAsset = 'assets/icon/app_icon_ring_centered_white.png';
  static const _logoSize = 72.0;
  // Drawn into the same canvas as the shader's own glow (see
  // [_MenuStarSupernovaPainter.paint]) at this alpha, with plain normal
  // (srcOver) blending — [BlendMode.overlay] was tried first (see the
  // gallery in `MenuButtonGalleryScreen`) but read as too washed-out;
  // normal blending at 100% keeps the logo solid white instead.
  static const _logoOverlayOpacity = 1.0;
  // The "MENU" caption under the button, off for now — not deleted, see
  // [_showStarRingIcon] just above for the same pattern.
  static const _showMenuLabel = false;
  // See [kHoldGestureDuration] — shared with the sky's own hold-to-peek
  // so the two gestures feel like one consistent timing across the
  // screen, rather than two independently-tuned numbers that happened to
  // be close.
  static const _chargeDuration = kHoldGestureDuration;

  ui.FragmentShader? _shader;
  // Decoded once and kept around rather than reloaded every frame — drawn
  // straight into [_MenuStarSupernovaPainter]'s own canvas (see
  // [paintLogo]) rather than as an [Image] widget, so it can share that
  // canvas's own blend-mode-against-the-glow treatment the same way the
  // star glyph it replaced did.
  ui.Image? _logoImage;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  // A press doesn't open the menu itself — it charges this for as long
  // as the finger stays down, and the menu only opens once it reaches
  // 1.0 (see the status listener in initState); let go early and it
  // reverses back to 0 instead of firing. Its own value, read straight
  // in build() below (already rebuilding every frame off [_ticker]), is
  // what drives `supernovaGlow`'s own [chargeGlow].
  late final AnimationController _chargeController;
  // Shown briefly whenever a press lets go before the charge completes
  // — a plain tap reads as "nothing happened" otherwise, with no clue
  // that holding is what this button actually wants. Visible for
  // [_hintVisibleDuration], then faded out quickly (see the
  // AnimatedOpacity in build()) rather than lingering.
  bool _showHoldHint = false;
  Timer? _hintTimer;
  static const _hintVisibleDuration = Duration(milliseconds: 1100);

  // Same real, continuous motor vibration as the sky's own hold, including
  // the same [_hapticActive]-guarded cancel — see
  // `_SkyScreenState._startHoldHaptic`'s own doc comment for why a blind
  // `Haptics.cancel()` is dangerous (the motor is one global resource,
  // and this button sits on top of the sky's own full-screen
  // `GestureDetector`, sharing its hit-test chain — a stray cancel from
  // one side can silence a buzz the other side started for an unrelated
  // touch). There's no shared home for this between the two unrelated
  // widgets, so it's kept small and duplicated rather than factored out.
  bool _hapticActive = false;

  // See `_SkyScreenState._hapticAmplitude`'s own doc comment for why this
  // needs to be set explicitly at all — the same low value, so the button's
  // own buzz matches the sky's.
  static const _hapticAmplitude = 10;

  void _startHoldHaptic() {
    _hapticActive = true;
    Haptics.vibrate(duration: _chargeDuration, amplitude: _hapticAmplitude);
  }

  void _stopHoldHaptic() {
    if (!_hapticActive) return;
    _hapticActive = false;
    Haptics.cancel();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
    _chargeController =
        AnimationController(vsync: this, duration: _chargeDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _chargeController.reset();
              _stopHoldHaptic();
              widget.onTap();
            }
          });
    _loadShader();
    _loadLogoImage();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/menu_star_button.frag',
    );
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  Future<void> _loadLogoImage() async {
    final bytes = await rootBundle.load(_logoAsset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _logoImage = frame.image);
  }

  void _handlePressStart() {
    _chargeController.forward();
    if (isTouchOnlyMobile) _startHoldHaptic();
  }

  // Shared by both onTapUp (a genuine release) and onTapCancel (the
  // gesture arena handing this touch to something else, e.g. a pan
  // starting on top of this button) — either way, letting go before
  // reaching 1.0 backs the charge off rather than leaving it stuck
  // wherever it was, and is also exactly when the hint below is worth
  // showing — the press genuinely wasn't held long enough to open
  // anything.
  void _handlePressEnd() {
    _stopHoldHaptic();
    if (_chargeController.status == AnimationStatus.forward) {
      _chargeController.reverse();
      _hintTimer?.cancel();
      setState(() => _showHoldHint = true);
      _hintTimer = Timer(_hintVisibleDuration, () {
        if (mounted) setState(() => _showHoldHint = false);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _chargeController.dispose();
    _hintTimer?.cancel();
    _stopHoldHaptic();
    _shader?.dispose();
    _logoImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildButtonAndLabel(shader)],
        ),
        // Floating above the button via [Positioned] rather than
        // sitting in the Column's own flow — appearing/disappearing
        // shouldn't nudge the button or the MENU label up and down
        // every time it toggles.
        Positioned(
          top: -30,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showHoldHint ? 1.0 : 0.0,
              // Fades in a little slower than it fades out — matches
              // asking for it to *disappear* "molto velocemente"
              // specifically, not necessarily appear that fast too.
              duration: Duration(milliseconds: _showHoldHint ? 200 : 120),
              child: Builder(
                builder: (context) {
                  final label = context.strings.menuButtonHoldHint
                      .toUpperCase();
                  // Same language as the button itself now — a thin navy
                  // border (`Colors.white` glow's counterpart to the
                  // button's own navy disc border) and a white glow
                  // behind it (was blue) instead of the app's usual
                  // accent, to read as lit by the same light as the
                  // button it's floating above.
                  const style = TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  );
                  return Stack(
                    children: [
                      Text(
                        label,
                        style: style.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3
                            ..color = const Color(0xFF0D1220),
                        ),
                      ),
                      Text(
                        label,
                        style: style.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 2),
                            Shadow(color: Colors.white, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonAndLabel(ui.FragmentShader? shader) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (shader != null)
              // A [Positioned] child with only width/height set (no
              // left/top/right/bottom) — it's centered per this Stack's
              // own `alignment` instead, same as a non-positioned child
              // would be, but explicitly sized regardless of the Stack's
              // own reported bounds. A Stack's own size only ever comes
              // from its *non*-positioned children (the tap target
              // below), so this can be arbitrarily bigger without
              // needing to escape any constraint at all — the same
              // mechanism the hold-hint label elsewhere in this widget
              // already relies on to paint above this whole button's own
              // bounds. [OverflowBox] was tried first here and worked
              // fine on mobile, but clipped this glow down to the tap
              // target's own small 110×110 footprint specifically on the
              // deployed web build (confirmed on the live GitHub Pages
              // site, not reproducible from the app itself) — switching
              // to the approach already proven to work everywhere else
              // in this widget is what actually fixed it.
              Positioned(
                width: _glowCanvasSize,
                height: _glowCanvasSize,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MenuStarSupernovaPainter(
                      shader: shader,
                      time:
                          _elapsed.inMicroseconds /
                          Duration.microsecondsPerSecond,
                      scale: _scale,
                      starGlyphSize: _starGlyphSize,
                      charge: _chargeController.value,
                      showStarAndRing: _showStarRingIcon,
                      logoImage: _showStarRingIcon ? null : _logoImage,
                      logoSize: _logoSize,
                      logoOpacity: _logoOverlayOpacity,
                    ),
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              // [Clip.none] is this widget's own default, which only ever
              // matters once there's something for it to clip: this
              // Material paints nothing of its own (transparent, no
              // elevation), so on mobile/touch there was nothing to see
              // either way. On the web, the [InkWell] below gets a real,
              // persistent hover state from the mouse — with clipping off,
              // that hover highlight painted as a full, hard-edged square
              // over this whole tap target instead of following its own
              // [CircleBorder], since an unclipped Material doesn't
              // constrain its child's ink features to the shape at all.
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                // The real logic lives in onTapDown/onTapUp/onTapCancel
                // below — [onTap] itself stays a no-op, kept only because
                // InkWell needs at least one tap handler set to wire up its
                // tap recognizer at all (so onTapDown/onTapUp/onTapCancel
                // actually fire).
                onTap: () {},
                onTapDown: (_) => _handlePressStart(),
                onTapUp: (_) => _handlePressEnd(),
                onTapCancel: _handlePressEnd,
                // No ripple/highlight of its own — [supernovaGlow]'s own
                // [chargeGlow] is the only feedback a press gets here;
                // Android's default translucent disc underneath would just
                // double up on it, off-center from the actual glow and in
                // a flat white that doesn't match. [hoverColor]/[focusColor]
                // join [splashColor]/[highlightColor] here for the same
                // reason — touch has no hover/focus state to speak of, but
                // a mouse on the web does, and left at their defaults they
                // were the actual visible square reported on the web build
                // (see the [clipBehavior] note above for why it was square
                // rather than round in the first place).
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                child: const SizedBox(
                  width: _tapTargetSize,
                  height: _tapTargetSize,
                ),
              ),
            ),
          ],
        ),
        // Just a plain caption — makes it clear at a glance that this
        // is a menu button, not another life-area supernova or a
        // decoration; deliberately small and secondary next to the
        // button itself, not competing with it. The two stacked
        // [Shadow]s are the same blue as the button's own glow — a
        // tight one for a bright core right against the letters, a
        // wide, soft one behind that — so the caption reads as lit by
        // the same light rather than just sitting near it.
        //
        // Pulled up with a negative [Transform.translate] rather than
        // just a smaller/zero gap above — the Column still reserves the
        // gap-less layout space below the button first, then this
        // shifts purely the *painted* position up into it, closer than
        // a real layout gap could go without the button and caption
        // starting to overlap in hit-testing too.
        if (_showMenuLabel)
          Transform.translate(
            offset: const Offset(0, -15),
            child: Text(
              // Reuses [openMenuAction] (already the localized "Menu",
              // used elsewhere as this same button's tooltip) rather than
              // a second, separate string for the same word — just
              // uppercased here to match this caption's own small-caps
              // styling, which the tooltip text doesn't need.
              context.strings.openMenuAction.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(color: Color(0xFF6E8CD8), blurRadius: 6),
                  Shadow(color: Color(0xFF6E8CD8), blurRadius: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MenuStarSupernovaPainter extends CustomPainter {
  const _MenuStarSupernovaPainter({
    required this.shader,
    required this.time,
    required this.scale,
    required this.starGlyphSize,
    required this.charge,
    required this.showStarAndRing,
    required this.logoImage,
    required this.logoSize,
    required this.logoOpacity,
  });

  final ui.FragmentShader shader;
  final double time;
  final double scale;
  // The star glyph's own rendered size — deliberately not tied to
  // [scale] (which the ring/glow canvas size off of instead), so the
  // star can be resized on its own without dragging the ring along.
  final double starGlyphSize;
  // 0..1 — see `_MenuStarButtonState._chargeController`.
  final double charge;
  // See `_MenuStarButtonState._showStarRingIcon` — the shader's own
  // additive glow (drawn above, before this flag is even checked) always
  // stays; only the white ring + white star glyph below it are gated by
  // this, in favor of the app's own logo drawn on top instead.
  final bool showStarAndRing;
  // Null while the asset is still decoding, or while [showStarAndRing]
  // is true (the older ring+star look, with no logo to draw) — see
  // `_MenuStarButtonState._loadLogoImage`.
  final ui.Image? logoImage;
  // Matches [SkyMenuContent]'s own header logo size.
  final double logoSize;
  // See `_MenuStarButtonState._logoOverlayOpacity`.
  final double logoOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, scale)
      ..setFloat(4, charge);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );

    // Tried, disabled: the same "rotating decoration"
    // [SkySupernova._paintOutlineIcon] draws behind each life area's own
    // icon — a blurred gradient stroke of the glyph's own outline, spun
    // around its center. That's exactly the problem here: it's a glow
    // that traces the star's own contour, and on this much smaller
    // button it just read as the star having its own outline glow
    // rather than a separate decoration — see [paintRing] below and
    // `supernovaGlow`'s own [nearGlow] for the shapeless central glow
    // that replaced it instead.
    //
    // const glowGradientColors = [Color(0xFFFFEFA0), Color(0xFFF0C078)];
    // void paintRotatingGlow() {
    //   final text = String.fromCharCode(Icons.star.codePoint);
    //   final center = Offset(size.width, size.height) / 2;
    //   final glowAngle = time * 2.2;
    //   final glowAxis =
    //       Offset(math.cos(glowAngle), math.sin(glowAngle)) * (iconSize / 2);
    //   final glowShader = ui.Gradient.linear(
    //     center - glowAxis,
    //     center + glowAxis,
    //     glowGradientColors,
    //   );
    //   final glowPainter = TextPainter(textDirection: TextDirection.ltr)
    //     ..text = TextSpan(
    //       text: text,
    //       style: TextStyle(
    //         fontSize: iconSize,
    //         fontFamily: Icons.star.fontFamily,
    //         package: Icons.star.fontPackage,
    //         foreground: Paint()
    //           ..style = PaintingStyle.stroke
    //           ..strokeWidth = iconSize * 0.08
    //           ..shader = glowShader
    //           ..maskFilter = MaskFilter.blur(BlurStyle.normal, iconSize * 0.04),
    //       ),
    //     )
    //     ..layout();
    //   final topLeft =
    //       center - Offset(glowPainter.width, glowPainter.height) / 2;
    //   glowPainter.paint(canvas, topLeft);
    // }

    // Tried dark navy here (and in [paintRing] below) for both, just to
    // see it — back to white now. [BlendMode.overlay] only ever
    // brightens what's under it, which is exactly why navy didn't read
    // as dark there; white doesn't have that problem.
    void paintIcon(IconData icon, double opacity) {
      final text = String.fromCharCode(icon.codePoint);
      final iconPainter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: text,
          style: TextStyle(
            fontSize: starGlyphSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            foreground: Paint()
              ..color = Colors.white.withValues(alpha: opacity)
              ..blendMode = BlendMode.overlay,
          ),
        )
        ..layout();
      final topLeft =
          Offset(size.width, size.height) / 2 -
          Offset(iconPainter.width, iconPainter.height) / 2;
      iconPainter.paint(canvas, topLeft);
    }

    // Used to be part of the shader's own additive glow (drawn first,
    // via [shader] above) — but at 0.09 world units its radius sits
    // well inside the icon's own, so drawn there it was the icon
    // covering most of the ring rather than the ring sitting around
    // the icon. Painted here instead, after the icon, so it's
    // unambiguously the outermost thing — same idea as the real
    // supernovas' own fixed outer ring (see
    // `SkySupernova._paintOutlineIcon`'s [outlinePainter], also drawn
    // on top of its icon), just a plain stroked circle rather than a
    // glyph-shaped one since this ring was never meant to trace the
    // star's own outline.
    void paintRing() {
      final center = Offset(size.width, size.height) / 2;
      // [scale] is the exact same world-units-to-pixels factor passed
      // to the shader as `uScale`; 0.09/0.016 match that shader's own
      // former `ringRadius`/ring width.
      final radius = 0.09 * scale;
      final width = 0.016 * scale;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 3
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2)
          ..blendMode = BlendMode.plus,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = Colors.white.withValues(alpha: 0.8)
          ..blendMode = BlendMode.plus,
      );
    }

    // Drawn straight into this same canvas, after the glow.
    void paintLogo() {
      final image = logoImage;
      if (image == null) return;
      final center = Offset(size.width, size.height) / 2;
      final rect = Rect.fromCenter(
        center: center,
        width: logoSize,
        height: logoSize,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      canvas.save();
      canvas.clipPath(Path()..addOval(rect));

      // 1. A fully opaque base pass, plain normal compositing — this is
      // what actually makes the button occlude whatever's behind it
      // (a stray constellation, a real supernova sharing the same screen
      // spot — see the Sky's own report of one crossing right through the
      // disc). [BlendMode.softLight] alone (tried first, below) is a
      // blend *formula*, not a solid paint, so it never fully replaces
      // the destination even at full source alpha — it was letting
      // background content show through the disc's own footprint no
      // matter how opaque the source pixels were.
      canvas.drawImageRect(
        image,
        src,
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: logoOpacity)
          ..blendMode = BlendMode.srcOver
          ..filterQuality = FilterQuality.high,
      );

      // 2. The same image again, [BlendMode.softLight] this time, layered
      // on top of the now-opaque base above purely for flavor — lets the
      // glow drawn earlier on this same canvas modulate the logo's
      // whites/darks a little rather than sitting perfectly flat, without
      // reopening the occlusion hole pass 1 exists to close (a blend pass
      // drawn *after* an opaque base can only combine with that base's
      // own already-solid result, never reach back to whatever pass 1
      // already painted over).
      canvas.drawImageRect(
        image,
        src,
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: logoOpacity * 0.6)
          ..blendMode = BlendMode.softLight
          ..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      // 3. A soft, blurred, additive bloom drawn *after* the crisp logo —
      // it has to come last, or the crisp pass above (opaque, covering
      // almost this entire canvas) just paints straight over it and hides
      // it entirely. Deliberately unclipped, so the star's own light
      // visibly spreads past the disc's own edge into the glow around it
      // and eats into the dark disc immediately around it, rather than
      // either blocking the glow outright (opaque) or just letting it
      // passively show through (transparency) — "consumes what's around
      // it" rather than "lets it pass through".
      //
      // Skipped on web: `ImageFilter.blur` on an unclipped `drawImageRect`
      // with `BlendMode.plus` doesn't blur at all there — confirmed via
      // headless-Chrome screenshots (both software SwiftShader and real
      // D3D11 GPU rendering) that it instead paints a hard-edged, roughly
      // logoSize²-ish solid square, which is the "square glow" bug the
      // user reported. Isolated by bisection: disabling this one pass
      // (leaving 1/2/4 untouched) removes the square with no other visual
      // change. A native-only bug in this exact filter+blend+unclipped
      // combination, not reproducible on mobile — nothing to fix there.
      if (!kIsWeb) {
        canvas.drawImageRect(
          image,
          src,
          rect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..blendMode = BlendMode.plus
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8)
            ..filterQuality = FilterQuality.high,
        );
      }

      // 4. A small, tight white glow right on the star itself, on top of
      // everything else — the same idea as the shader's own glow further
      // behind (see [supernovaGlow]'s `glow`/`nearGlow`), just white
      // instead of blue, with a much smaller idle reach, and now actually
      // animated the same way that one is instead of sitting static:
      // [pulse] mirrors `supernovaGlow`'s own breathing exactly (same
      // formula, same period), and [charge] grows and brightens it right
      // alongside `chargeGlow` as the button is held, rather than only the
      // glow behind it reacting to a press.
      final pulse = 0.955 + 0.045 * math.sin(time * 0.6);
      // Shrunk again (0.16 -> 0.10) for the idle diameter.
      final starGlowRadius = logoSize * 0.10 * (1 + charge * 1.8);
      // A hot, near-full-white core (rather than fading from the very
      // center) that holds through roughly a third of the radius before
      // easing out — a softer, more gradual falloff than the old straight
      // two-stop fade, while actually reading as *more* intense right at
      // the center, not less.
      final starGlowCoreAlpha = (1.0 * pulse + charge * 0.2).clamp(0.0, 1.0);
      final starGlowPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          starGlowRadius,
          [
            Colors.white.withValues(alpha: starGlowCoreAlpha),
            Colors.white.withValues(alpha: starGlowCoreAlpha * 0.55),
            Colors.white.withValues(alpha: starGlowCoreAlpha * 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.35, 0.7, 1.0],
        )
        ..blendMode = BlendMode.softLight
        // The actual fix for "reads as a hard-edged disc, not a glow" —
        // a plain radial gradient still has a genuinely *geometric* edge
        // right at [starGlowRadius] (alpha hits exactly 0 exactly there,
        // however many gradient stops lead up to it), and doubling the
        // draw (tried first, to read as more intense) only made that
        // edge more visible, not less. A blur is what actually removes
        // it — it softens the whole falloff into something with no sharp
        // boundary left to see at all, rather than a smoother-but-still-
        // sharply-bounded version of the same disc.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, starGlowRadius * 0.5);
      // Drawn twice for extra strength — safe to compound now that
      // [maskFilter] is what's actually softening the edge (unlike the
      // earlier attempt, before the blur existed, where doubling a
      // hard-edged gradient was exactly what made it read as a solid
      // disc): two soft-edged passes just make a brighter soft glow.
      canvas.drawCircle(center, starGlowRadius, starGlowPaint);
      canvas.drawCircle(center, starGlowRadius, starGlowPaint);
    }

    if (showStarAndRing) {
      paintIcon(Icons.star, 0.8);
      paintRing();
    }
    paintLogo();
  }

  @override
  bool shouldRepaint(covariant _MenuStarSupernovaPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.scale != scale ||
      oldDelegate.starGlyphSize != starGlyphSize ||
      oldDelegate.charge != charge ||
      oldDelegate.showStarAndRing != showStarAndRing ||
      oldDelegate.logoImage != logoImage ||
      oldDelegate.logoSize != logoSize ||
      oldDelegate.logoOpacity != logoOpacity;
}

/// A two-finger rotate gesture (see `_handleScaleUpdate`) is touch-only —
/// a mouse/trackpad has no equivalent, so desktop/web needs its own
/// control for the same [SkyCamera.rolled]; shown on phone too (see
/// `SkyScreen.build`'s own comment on why) rather than hardcoded off
/// there just because touch already has the gesture. Drag anywhere
/// around this dial (not just directly on the icon) and the
/// camera rolls by however far the angle around the dial's own center
/// changed since the last frame — same feel as spinning a real dial or a
/// ship's wheel, and exactly the same underlying rotation a phone's
/// pinch-rotate drives.
///
/// Styled to match the "Grid" switch as closely as a circular dial can:
/// the same translucent `colors.nightPanel` disc (not a solid fill), the
/// same gold `colors.gold` a `Switch` turns to when it's the thing you're
/// actively engaging with, rather than the app's usual gold everywhere or
/// a separate white-and-navy scheme of its own. The small dot orbiting
/// just outside its rim — see [angle] — is what actually shows how far
/// you've rolled, the way a map app's own small compass badge shows its
/// needle rather than just a plain icon; solid gold, no glow, so it stays
/// a crisp, precise readout rather than a soft blob.
class _RollKnob extends StatefulWidget {
  const _RollKnob({required this.angle, required this.onRoll});

  /// Current roll, in radians, relative to level (see
  /// `cameraRollAngle` in `constellation_field.dart`) — purely a readout,
  /// never written back by this widget; drag gestures only ever report a
  /// *delta* through [onRoll], same as before.
  final double angle;

  /// Called with a delta angle in radians (positive = clockwise, matching
  /// [SkyCamera.rolled]'s own convention) every time the drag angle around
  /// the dial's center changes.
  final ValueChanged<double> onRoll;

  @override
  State<_RollKnob> createState() => _RollKnobState();
}

class _RollKnobState extends State<_RollKnob> {
  // 20% smaller than before, matching the same shrink applied to the
  // "Grid" switch and [_ZoomSlider] — frees up more of the sky for
  // constellations/navigation without losing any of these controls.
  static const _knobSize = 42.0;
  // Bigger than _knobSize so the indicator dot has room to orbit just
  // outside the knob's own rim without getting clipped.
  static const _boxSize = 62.0;
  static const _orbitRadius = _knobSize / 2 + 6;
  static const _dotSize = 8.0;

  double? _lastAngle;

  void _updateAngle(Offset localPosition) {
    final center = const Offset(_knobSize / 2, _knobSize / 2);
    final vector = localPosition - center;
    // Too close to the pivot for an angle to mean anything stable — just
    // wait for the drag to move further out instead of jittering.
    if (vector.distance < 6) return;

    final angle = math.atan2(vector.dy, vector.dx);
    final lastAngle = _lastAngle;
    if (lastAngle != null) {
      // Shortest signed distance around the circle, so crossing the
      // ±π seam (straight left of center) doesn't register as a
      // near-full rotation the wrong way.
      var delta = angle - lastAngle;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;
      widget.onRoll(delta);
    }
    _lastAngle = angle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Same screen-space atan2(dy, dx) convention _updateAngle itself
    // measures drags in, so the dot visibly orbits the same way the
    // dial's been dragged.
    final dotCenter = Offset(
      _boxSize / 2 + _orbitRadius * math.cos(widget.angle),
      _boxSize / 2 + _orbitRadius * math.sin(widget.angle),
    );

    return SizedBox(
      width: _boxSize,
      height: _boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (_boxSize - _knobSize) / 2,
            top: (_boxSize - _knobSize) / 2,
            child: GestureDetector(
              onPanStart: (details) => _updateAngle(details.localPosition),
              onPanUpdate: (details) => _updateAngle(details.localPosition),
              onPanEnd: (_) => _lastAngle = null,
              child: Material(
                color: colors.nightPanel.withValues(alpha: 0.75),
                shape: CircleBorder(
                  side: BorderSide(
                    color: colors.gold,
                    width: kBorderWidthActive,
                  ),
                ),
                child: SizedBox(
                  width: _knobSize,
                  height: _knobSize,
                  child: Icon(Icons.threesixty, color: colors.gold, size: 22),
                ),
              ),
            ),
          ),
          Positioned(
            left: dotCenter.dx - _dotSize / 2,
            top: dotCenter.dy - _dotSize / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.gold,
              ),
              child: SizedBox(width: _dotSize, height: _dotSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dedicated zoom control alongside the pinch/scroll-wheel gestures
/// `SkyScreen` already handles — styled like the "Grid" switch, same
/// as [_RollKnob]: the translucent `colors.nightPanel` pill, a muted
/// "Zoom" caption the same way "Grid" labels its own switch, and gold
/// (`colors.gold`) wherever the switch itself would turn gold — the
/// active track/thumb and the percentage readout, since that's the part
/// actually being engaged with. Always shown on both phone and web
/// (unlike the roll knob, which only covers a gap touch itself already
/// fills). A plain horizontal [Slider], the "Zoom" caption at its zoomed-
/// out (min) end and the percentage readout at its zoomed-in (max) end —
/// bottom-center alongside the Grid switch and roll knob (see
/// `SkyScreen.build`'s shared [FittedBox] row) rather than its own
/// rotated-on-its-side rail off to the right.
///
/// Mapped through `math.log` rather than [zoom] itself: zoom is
/// inherently multiplicative (min to max is a 100x span — see
/// `NebulaScreen._maxZoom`'s own doc comment), so a slider driven by the
/// raw value would spend almost its entire length on just the bottom
/// sliver of that range and leave the rest of the track meaningless — the
/// log scale is what makes the thumb's position actually track how
/// "zoomed in" the view feels.
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onChanged,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  static const _trackLength = 120.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logMin = math.log(minZoom);
    final logMax = math.log(maxZoom);
    final logValue = math.log(zoom).clamp(logMin, logMax).toDouble();
    final percent = (((logValue - logMin) / (logMax - logMin)) * 100).round();

    return Material(
      color: colors.nightPanel.withValues(alpha: 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_bottomPillRadius),
        side: BorderSide(color: colors.gold, width: kBorderWidthActive),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: _bottomPillHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Zoom', style: TextStyle(color: colors.muted, fontSize: 12)),
              const SizedBox(width: 8),
              SizedBox(
                width: _trackLength,
                height: 24,
                child: SliderTheme(
                  // Only the track height and the dimmer inactive track are
                  // local: this slider sits on the sky itself, where the
                  // app's own navy track would vanish into the background.
                  data: SliderTheme.of(context).copyWith(
                    inactiveTrackColor: colors.muted.withValues(alpha: 0.35),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: logMin,
                    max: logMax,
                    value: logValue,
                    onChanged: (value) => onChanged(math.exp(value)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Fixed width (enough for "100%", the widest this ever reads)
              // rather than sizing to the current text — otherwise the whole
              // pill (and everything sharing its row) subtly resizes as the
              // digit count changes while dragging.
              SizedBox(
                width: 34,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.right,
                  // Belt-and-braces alongside the fixed width above: forces
                  // exactly one line regardless of how tight that width is,
                  // so "100%" (the one value with 3 digits) can never wrap
                  // its "%" onto a second line and grow this pill taller
                  // than the Grid switch sharing its row.
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: colors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
