import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tooltip_card/tooltip_card.dart';

import '../audio/audio_service.dart';
import '../data/area_vision_repository.dart';
import '../data/audio_settings_repository.dart';
import '../data/constellation_layout.dart';
import '../data/constellation_presets.dart'
    show LocalizedNameX, presetById;
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
import '../tutorials/sky_hint_target.dart';
import '../tutorials/tour_gesture_step.dart';
import '../tutorials/tour_step_card.dart';
import '../tutorials/tutorial_management.dart';
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
import 'quick_settings_screen.dart';
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

  /// Where the `Stack` painting the sky's own background/constellations/
  /// supernovas lives — the `RenderBox` [SkyHintTarget] measures against to
  /// turn a world position into a screen rect (see its own doc comment for
  /// why it can't just use the whole screen: an app bar/safe area can
  /// offset this from the `Overlay`'s own origin).
  final _skySurfaceKey = GlobalKey();

  /// [_MenuStarButton]'s own key, so [_menuButtonCenter] can look up its
  /// on-screen position directly rather than the button having to compute
  /// and forward it itself — see [_menuControlPressed]'s own doc comment
  /// for what this is for.
  final _menuStarButtonKey = GlobalKey();

  /// True for as long as a touch is down on [_MenuStarButton] or one of
  /// the five [_QuickAccessButton]s in [_QuickAccessFan] — both sit on top
  /// of the sky's own full-screen `GestureDetector` further below
  /// (`onTapDown`/`onTapUp`/`onTapCancel`), sharing its hit-test chain, so
  /// *every* one of their touches also reaches the sky's own handlers (see
  /// [_hapticActive]'s own doc comment for the exact same shape of problem
  /// with the shared vibration motor). Without this, holding the button
  /// while something happens to sit underneath it (a supernova, a
  /// constellation) used to also fly the camera there and open its
  /// tooltip — via the sky's own independent hold timer, which runs on
  /// its own clock regardless of which widget the gesture arena eventually
  /// credits the tap to — leaving that flight finishing on top of the menu
  /// that had *also* just opened. Set by [_setMenuControlPressed], which
  /// both widgets call from their own press-start/release/cancel handlers.
  bool _menuControlPressed = false;

  /// Captured once, at the start of [_handleTapDown], from
  /// [_menuControlPressed] — whether *this* touch's down event landed on a
  /// menu control. Read by [_handleTapUp] instead of the live
  /// [_menuControlPressed] for the rest of the touch's lifecycle: by the
  /// time a release reaches the sky's own handler, the button (a
  /// descendant, dispatched first) may already have cleared
  /// [_menuControlPressed] itself in reaction to the very same release —
  /// capturing the decision once, at the one moment it's reliably still
  /// accurate, avoids depending on that ordering.
  bool _holdTargetIsMenuControl = false;

  void _setMenuControlPressed(bool pressed) {
    _menuControlPressed = pressed;
  }

  /// [_MenuStarButton]'s own center, converted into the sky surface's
  /// local coordinate space — the same space [TapDownDetails.localPosition]
  /// arrives in (see [_skySurfaceKey]'s own doc comment for why that's a
  /// safe assumption). `null` before the button's first frame, which never
  /// actually matters since [_menuControlPressed] can't be true before
  /// then either.
  Offset? _menuButtonCenter() {
    final buttonBox = _menuStarButtonKey.currentContext?.findRenderObject();
    final skyBox = _skySurfaceKey.currentContext?.findRenderObject();
    if (buttonBox is! RenderBox || !buttonBox.attached) return null;
    if (skyBox is! RenderBox || !skyBox.attached) return null;
    final globalCenter = buttonBox.localToGlobal(
      buttonBox.size.center(Offset.zero),
    );
    return skyBox.globalToLocal(globalCenter);
  }

  /// The fixed area the `'sky-navigation'` tour's placeholder "house"
  /// constellation belongs to, and the area whose supernova the tour asks
  /// the user to tap first — see [_buildTutorialDemoPlaced] and
  /// [_enterTutorialDemo]. Picked for the theme (a house fits "personal"),
  /// not for any property of the area itself — any fixed one would do.
  static const _tutorialArea = LifeArea.personal;

  /// The sentinel [Project.id]/[Star.id]s the tour's placeholder
  /// constellation uses — negative, so they can never collide with a real
  /// one (real ids are `millisecondsSinceEpoch`, always positive). See
  /// [_buildTutorialDemoPlaced]: this constellation is never written to
  /// [widget.projectRepository]/[widget.starRepository], only added to
  /// [_placed] in memory for as long as the tour is on screen.
  static const _tutorialProjectId = -1;

  /// Whether the `'sky-navigation'` tour's placeholder constellation is
  /// currently mixed into [_placed] — see [_loadData]/[_handleTourChanged].
  bool _tutorialDemoActive = false;

  /// The camera/zoom the tour temporarily overrides — captured right
  /// before [_enterTutorialDemo] forces a fixed one, and restored exactly
  /// by [_exitTutorialDemo], so a "Replay" from the Tutorials panel hands
  /// the user back their own spot in the sky rather than stranding them at
  /// the tutorial's fixed position (or, on a fresh install, wherever the
  /// default/"Love" logic above already put them).
  SkyCamera? _preTutorialCamera;
  double? _preTutorialZoom;

  /// The controller `_handleTourChanged` is subscribed to — kept so
  /// [dispose] can remove that listener without needing a [context], which
  /// may no longer be safe to read by then.
  TourController? _tourController;

  /// Whether [_handleTourChanged] has already kicked the background music
  /// once for pressing Start on the tour's own order-1 welcome step — see
  /// that method's own doc comment for why that specific moment, not
  /// app launch, is what this waits for.
  bool _backgroundMusicKicked = false;

  /// Whether the tour's own steps 1/2/3/5 (the four [SkyHintTarget]s —
  /// see that widget's own doc comment) should be left out of the tree
  /// entirely right now, because the tap/hold that just satisfied one of
  /// them also kicked off a camera flight: a scrim+card sitting frozen
  /// over a moving camera would hide the very motion the step just asked
  /// for. Set/cleared only by [_advanceGestureTourStep] (`endsFlight:
  /// true`), at the start and end of the exact same 900ms timer that
  /// delays `Tour.next()` — deliberately *not* read off
  /// `_flyController.isAnimating` directly, even though the two normally
  /// last about as long: those are two independently-clocked timers (one
  /// a `Future.delayed`, the other a frame-driven `AnimationController`),
  /// and letting the tour's own step re-register before `next()` has
  /// actually advanced the controller's index — or the reverse — is
  /// exactly what produced a "Two HintTargets are mounted... order must
  /// be unique" assertion under real timing (confirmed live, not just in
  /// theory). Tying both effects to one shared clock instead of two
  /// separate ones removes the race by construction rather than papering
  /// over one particular ordering of it.
  bool _hideTourDuringFlight = false;

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
  // Same pattern, for the Sound Lab/Tutorials buttons that used to sit
  // top-right — [QuickSettingsScreen] (see the quick-access mini menu's
  // Quick Settings entry) now covers both, so these are redundant rather
  // than a second way in worth keeping visible.
  static const bool _showSoundLabButton = false;
  static const bool _showTutorialsButton = false;

  /// Whether the quick-access mini menu (see [_QuickAccessFan]) is open —
  /// toggled by a plain tap on [_MenuStarButton] (its `onQuickTap`), an
  /// alternative to the same button's hold-to-open charge, which still
  /// opens the full menu exactly as before (see [_openMenuModal]). Purely
  /// exploratory alongside the full menu, not a replacement for it.
  bool _quickAccessMenuOpen = false;

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

  /// Whether the most recent [_flyToWorld] call actually moved the camera
  /// (or would have, had it not short-circuited — see there) — read by
  /// [_handleTapUp] right after [_resolveTapTarget] to decide whether the
  /// tap sound/haptic play at all. Retapping whatever the camera is
  /// already sitting on is a real, common gesture (re-opening a tooltip
  /// just closed, say), and playing "you moved" feedback for a tap that
  /// visibly did nothing read as the sky misreporting itself. Defaults to
  /// `true` so any caller that reaches the camera some other way (not
  /// through [_flyToWorld]) keeps today's behaviour rather than silently
  /// losing its feedback.
  bool _lastFlightMoved = true;

  /// Below this angular separation (radians) between the camera's current
  /// aim and a flight's target, or this many zoom *percent* apart (see
  /// [zoomPercent]), a flight is close enough to "already there" that
  /// animating it would show no visible movement — small enough that no
  /// genuine tap ever lands inside it (every real target the sky can fly
  /// to sits much farther than this from any other), large enough to
  /// absorb ordinary floating-point residue from repeated flights to the
  /// exact same spot.
  static const _flyMovementAngleEpsilon = 0.0015;
  static const _flyMovementZoomPercentEpsilon = 0.05;

  /// The dot product of two sky-sphere direction vectors — see
  /// [SkyCamera.forward] — used only to measure the angle between them
  /// (`acos`, clamped) for [_flyToWorld]'s own "would this actually move
  /// the camera" check. Kept local rather than reused from
  /// `constellation_field.dart`'s own private `_dot`, which this file has
  /// no access to.
  static double _dotDirections(
    (double, double, double) a,
    (double, double, double) b,
  ) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

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
    _skyTooltipController.addListener(_onSkyTooltipChanged);
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
    // Drives the tour's placeholder constellation and fixed camera — see
    // [_handleTourChanged]. A listener rather than reading the controller
    // only from the `start()` call above, so a later "Replay" (from the
    // Tutorials panel, which calls `start(..., force: true)` from a
    // completely different part of the tree) is picked up the same way.
    _tourController = Tour.read(context)..addListener(_handleTourChanged);
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
    _tourController?.removeListener(_handleTourChanged);
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
      // While the tour's placeholder constellation is up, the user's own
      // real ones are left out entirely — not just visually secondary,
      // *absent* — so nothing but what the tour is actually pointing at is
      // there to tap/hold by mistake (real ones would otherwise still sit
      // wherever [constellationWorldPosition] put them, possibly right next
      // to the tour's own fixed spot). They're back the moment the tour
      // ends: this only ever changes what [_loadData] itself builds, never
      // [widget.projectRepository]/[widget.starRepository].
      if (!_tutorialDemoActive)
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
      // The 'sky-navigation' tour's placeholder constellation — mixed
      // straight into [_placed], never [widget.projectRepository]/
      // [widget.starRepository], so every other place that reads [_placed]
      // (rendering, hit-testing, fly-to, tooltips) already handles it for
      // free. See [_buildTutorialDemoPlaced]/[_handleTourChanged].
      if (_tutorialDemoActive) _buildTutorialDemoPlaced(),
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

  /// The 'sky-navigation' tour's own placeholder constellation — a small
  /// "house" (see the preset library), built by hand instead of through
  /// [widget.projectRepository]/[widget.starRepository]/
  /// [widget.starsShapeRepository] so it never touches disk: it exists only
  /// while [_tutorialDemoActive] is true, and simply stops being included
  /// in [_placed] once the tour ends — nothing to clean up, nothing that
  /// can be left behind by a killed app. Its [Project.id]/[Star.id]s are
  /// negative sentinels (see [_tutorialProjectId]) so they can never
  /// collide with a real project/star, and its
  /// [PlacedConstellation.worldPosition] comes from
  /// [tutorialDemoWorldPosition] rather than [constellationWorldPosition],
  /// which is exactly why: that one depends on how many real constellations
  /// the user already has in [_tutorialArea], and this one must be at a
  /// fixed, always-empty spot regardless.
  PlacedConstellation _buildTutorialDemoPlaced() {
    final preset = presetById('house')!;
    final name = preset.name.of(context.strings.languageCode);
    final project = Project(
      id: _tutorialProjectId,
      name: name,
      area: _tutorialArea,
      iconSlug: preset.iconSlug,
      createdAt: DateTime.now(),
    );
    final now = DateTime.now();
    // Two lit, one unlit — enough to look like a real constellation
    // mid-way through, without needing every one of the shape's slots
    // filled.
    final stars = [
      Star(
        id: _tutorialProjectId - 1,
        projectId: _tutorialProjectId,
        slotSequence: 1,
        title: name,
        createdAt: now,
        achievedDate: now,
        intensity: 3,
      ),
      Star(
        id: _tutorialProjectId - 2,
        projectId: _tutorialProjectId,
        slotSequence: 2,
        title: name,
        createdAt: now,
        achievedDate: now,
        intensity: 3,
      ),
      Star(
        id: _tutorialProjectId - 3,
        projectId: _tutorialProjectId,
        slotSequence: 3,
        title: name,
        createdAt: now,
      ),
    ];
    final built = buildConstellationRenderStars(
      stars: stars,
      habits: const [],
      shape: preset.shape,
      completionsByHabit: const {},
    );

    return PlacedConstellation(
      project: project,
      shape: preset.shape,
      worldPosition: tutorialDemoWorldPosition(_tutorialArea),
      stars: stars,
      habits: const [],
      renderStars: built.stars,
      edges: built.edges,
    );
  }

  /// Turns the tour's placeholder constellation and fixed camera on/off as
  /// the `'sky-navigation'` tour starts/ends — covers both the very first
  /// run (from [initState]'s own `start` call) and every later "Replay"
  /// from the Tutorials panel (`start(..., force: true)`) the same way,
  /// since both just flip [TourController.activeTour] and this only reacts
  /// to that, never to which call caused it.
  ///
  /// Also where the background loop gets an explicit nudge the first time
  /// the tour moves past its own order-1 welcome step (pressing Start) —
  /// [AudioService] already tries to start it unprompted at app launch
  /// (see its own doc comment), but on the web a browser that has not
  /// yet seen a *trusted* user gesture anywhere on the page leaves that
  /// attempt sitting blocked by the autoplay policy indefinitely; the
  /// Start button is the first one this screen is guaranteed to get
  /// (every step before it, and most after it, only ever advance on a
  /// gesture aimed at the sky canvas itself, not a real Flutter button),
  /// so re-issuing the same call from inside its own real button press is
  /// what actually satisfies that policy, rather than leaving it to
  /// chance on whichever gesture the tour's own steps happen to need.
  /// Guarded by [_backgroundMusicKicked] so this only ever fires once.
  void _handleTourChanged() {
    final TourController? controller = _tourController;
    final bool isActive = controller?.activeTour == 'sky-navigation';
    if (isActive &&
        !_backgroundMusicKicked &&
        (controller?.index ?? 0) > 0 &&
        // Only if the user hasn't deliberately paused it themselves — this
        // is a nudge past a browser policy blocking an attempt the app
        // already made on its own, not a reason to override a real
        // preference.
        !widget.audioService.backgroundPaused) {
      _backgroundMusicKicked = true;
      widget.audioService.resumeBackground();
    }
    if (isActive == _tutorialDemoActive) return;
    setState(() {
      if (isActive) {
        _enterTutorialDemo();
      } else {
        _exitTutorialDemo();
      }
    });
  }

  /// Snapshots the real camera, then points it at [_tutorialArea]'s own
  /// supernova (guaranteeing it's actually on screen — the world origin
  /// isn't: which area ends up behind the camera from there depends on
  /// [LifeArea.index]/[LifeArea.values.length]'s own golden-angle spiral,
  /// and [_tutorialArea] happens to land almost exactly opposite it, which
  /// is what briefly broke this) at maximum zoom-out (see
  /// [minZoomWithoutRepeats]) rather than the closer zoom [_flyTo] would
  /// use for an area. The first step still asks the user to find and tap
  /// it — from this far out it reads small, alongside every other area's
  /// own supernova, the same view a brand-new install opens on — and
  /// tapping it still zooms all the way in, which is the whole point: a
  /// real fly-to, not an already-arrived first step.
  void _enterTutorialDemo() {
    _preTutorialCamera = _camera;
    _preTutorialZoom = _zoom;
    _tutorialDemoActive = true;
    final areaPosition = areaWorldPosition(_tutorialArea);
    _camera = SkyCamera.lookingAt(
      azimuthTurns: areaPosition.dx,
      elevationTurns: areaPosition.dy,
    );
    _zoom = minZoomWithoutRepeats;
    _loadData();
  }

  /// Hands the camera back exactly where [_enterTutorialDemo] found it —
  /// not the world origin, not the "Love" heuristic above, so a "Replay"
  /// mid-use returns the user to their own spot rather than stranding them
  /// at the tutorial's fixed one.
  void _exitTutorialDemo() {
    _tutorialDemoActive = false;
    final camera = _preTutorialCamera;
    final zoom = _preTutorialZoom;
    if (camera != null) _camera = camera;
    if (zoom != null) _zoom = zoom;
    _preTutorialCamera = null;
    _preTutorialZoom = null;
    // A Skip during orders 10-14 (the quick-access fan's own five steps)
    // would otherwise strand the fan open with nothing left to close it
    // — its own buttons only stay modal *because* the tour is still
    // running (see [_QuickAccessFan]'s own doc comment).
    _quickAccessMenuOpen = false;
    _loadData();
  }

  /// The tour's placeholder constellation, as it currently sits in
  /// [_placed] — null whenever [_tutorialDemoActive] is false (it simply
  /// isn't in the list then). Used by the tour's own [SkyHintTarget] steps
  /// to find what to spotlight.
  PlacedConstellation? _tutorialDemoPlacedOrNull() {
    for (final placed in _placed) {
      if (placed.project.id == _tutorialProjectId) return placed;
    }
    return null;
  }

  /// The specific star inside the placeholder constellation the tour's
  /// "tap a star" step (order 3) points at — its first slot, the first one
  /// built in [_buildTutorialDemoPlaced].
  ConstellationStar? _tutorialDemoTapStar(PlacedConstellation placed) {
    for (final star in placed.renderStars) {
      if (star.entityId == _tutorialProjectId - 1) return star;
    }
    return null;
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
    // The "tap a star" tour step, not the hold/tooltip half — a plain tap
    // on any star (nascent slot or a real one) satisfies it. `endsFlight`
    // is safe even though this specific call happens before the flight
    // that follows a few lines down (rather than after, like the other
    // three call sites) — the tour's own demo star is always a real, lit
    // one (see `_buildTutorialDemoPlaced`), so the nascent branch right
    // below, the only path here that *doesn't* end in a flight, is never
    // actually reached while order 4 is the active step.
    if (!showTooltip) _advanceGestureTourStep(4, endsFlight: true);
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

  /// Toggles [_quickAccessMenuOpen] — [_MenuStarButton]'s own quick-tap
  /// callback; the mini menu's full-screen dismiss barrier and each of
  /// its five buttons close it back down through [_closeQuickAccessMenu]
  /// instead (see [_QuickAccessFan] in build()).
  void _toggleQuickAccessMenu() {
    setState(() => _quickAccessMenuOpen = !_quickAccessMenuOpen);
    // The tour's order-10 step — this is its only real gesture, opening or
    // closing either way (the guard inside only ever lets this through
    // while order 10 is actually the active step, i.e. the very first
    // time, so a later close/reopen well past that point is a no-op
    // here).
    _advanceGestureTourStep(10);
  }

  void _closeQuickAccessMenu() {
    if (_quickAccessMenuOpen) setState(() => _quickAccessMenuOpen = false);
  }

  /// Closes the mini menu, then runs [action] — every one of
  /// [_QuickAccessFan]'s five buttons routes through this rather than
  /// calling its destination directly, so picking one always leaves the
  /// mini menu closed behind it instead of still open once the pushed
  /// screen is popped back to.
  void _selectQuickAccess(VoidCallback action) {
    _closeQuickAccessMenu();
    action();
  }

  void _openQuickSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickSettingsScreen(
          settings: widget.settings,
          audioService: widget.audioService,
        ),
      ),
    );
  }

  /// The FAB's own way into the same menu the drawer opens — same content
  /// ([SkyMenuContent], same callbacks), just as a modal sheet from the
  /// bottom instead of a panel from the side. An alternative entry point
  /// being tried alongside the drawer, not a replacement for it — both
  /// stay live so the two can be compared.
  void _openMenuModal() {
    // Closed first rather than left open underneath — a hold that
    // completes while the quick-access menu happens to be open (both
    // read off the same button) should still land on a clean full menu,
    // not one with the mini menu's own buttons still floating on top.
    _closeQuickAccessMenu();
    // The tour's order-8 step, continuing into order 9 once this modal
    // actually closes (see the `.then` at the end of this call) — see
    // `TourGestureStep`'s own doc comment for why this is a direct call
    // rather than `passthrough`'s usual "call next() from the target's
    // own callback" pattern being any different here: it's the same
    // pattern, just on a real `HintTarget` instead of an invisible
    // full-screen one.
    _advanceGestureTourStep(8);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Explicit, not just relying on the default (also true): a tap
      // outside the sheet — on the barrier, not on `SkyMenuContent`
      // itself — must close it, since that's one of the three ways the
      // tour's own order-9 step (below) explicitly promises will work.
      isDismissible: true,
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
      builder: (_) => Stack(
        children: [
          SkyMenuModalFrame(
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
          // The tour's order-9 step — a real gate, not just a banner:
          // full scrim + centered card + one "Try" button, blocking
          // [SkyMenuModalFrame] entirely until pressed, only then letting
          // the real dismiss gesture (swipe, tap outside, back button —
          // any of the three) reach it. See
          // [TourGestureConfirmStep]'s own doc comment.
          TourGestureConfirmStep(
            tour: 'sky-navigation',
            order: 9,
            title: context.strings.skyTourMenuCloseTitle,
            description: context.strings.skyTourMenuCloseBody,
            tryLabel: context.strings.skyTourMenuCloseTryAction,
          ),
        ],
      ),
      // Fires once this closes, however it closed (swipe down, tap
      // outside, the Android back button, or a menu item's own
      // navigation) — exactly what the order-9 step above is waiting
      // for, and the only thing three different dismiss paths all have
      // in common.
    ).then((_) => _advanceGestureTourStep(9));
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

  /// [SkyAreaTarget] normally lands dead-center on the area's own
  /// supernova (see [areaWorldPosition]) — fine everywhere, since a real
  /// area has no single "point of interest" beyond its star. Mid-tour,
  /// though, tapping [_tutorialArea]'s supernova (the tour's own step 2)
  /// needs to land somewhere that keeps the placeholder constellation
  /// on screen for step 3 right after, and [tutorialDemoWorldPosition] sits
  /// far enough from the supernova (see its own doc comment) that dead
  /// centering the supernova instead pushes the constellation mostly or
  /// entirely off a narrow (phone-portrait) screen — [worldToScreen]
  /// scales *both* screen axes by `screenSize.height`, so how much of that
  /// offset actually fits on screen depends on the screen's aspect ratio,
  /// not just its width. Centering the constellation itself here instead
  /// works on every aspect ratio the same way, and still leaves the
  /// supernova nearby (it was the thing just tapped, its job already
  /// done).
  Offset? _worldFor(SkyNavigationTarget target) => switch (target) {
    SkyAreaTarget(:final area) => _tutorialDemoActive && area == _tutorialArea
        ? tutorialDemoWorldPosition(area)
        : areaWorldPosition(area),
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
    final rollCorrection = straightenRoll
        ? math.pi -
              cameraRollAngle(_camera.rotatedToAlign(_camera.forward, targetForward))
        : 0.0;

    // Nothing to actually fly — the camera is already aimed here (a retap
    // on whatever's already focused, most commonly). See
    // [_lastFlightMoved]'s own doc comment for why this matters to the
    // caller: skip the flight *and* its tap sound/haptic, but still hand
    // back an already-resolved future so a hold's tooltip opens at once
    // rather than waiting on a flight that was never going to tick.
    final angleToTarget = math.acos(
      _dotDirections(_camera.forward, targetForward).clamp(-1.0, 1.0),
    );
    final movedEnough = angleToTarget > _flyMovementAngleEpsilon ||
        (zoomPercent(targetZoom) - zoomPercent(_zoom)).abs() >
            _flyMovementZoomPercentEpsilon ||
        rollCorrection.abs() > _flyMovementAngleEpsilon;
    if (!movedEnough) {
      _lastFlightMoved = false;
      return TickerFuture.complete();
    }
    _lastFlightMoved = true;

    _stopInertia();
    _playZoomTransitionSound(_zoom, targetZoom);
    _flyStartCamera = _camera;
    _flyTargetForward = targetForward;
    _flyStartZoom = _zoom;
    _flyTargetZoom = targetZoom;
    _flyRollCorrection = rollCorrection;
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
    _holdTargetIsMenuControl = _menuControlPressed;
    if (_holdTargetIsMenuControl) {
      // This touch's down event landed on [_MenuStarButton] or a
      // [_QuickAccessButton] — see [_menuControlPressed]'s own doc comment
      // for why the sky still gets this callback at all. Still show the
      // charging ring, since the user is genuinely holding *something* and
      // expects to see it — just centered on the button itself rather than
      // wherever their finger also happens to land on the sky underneath,
      // and with none of a real sky hold's own consequences (sound,
      // haptic, fly-to, tooltip): the button already handles all of that
      // for its own gesture, entirely independently.
      final center = _menuButtonCenter();
      if (center != null) {
        _holdRingCenter = center;
        _holdRingArmTimer = Timer(_holdRingArmDelay, () {
          _holdRingArmTimer = null;
          _holdRingController.animateTo(
            1,
            duration: _holdDuration - _holdRingArmDelay,
          );
        });
      } else {
        _holdRingController.stop();
        _holdRingController.value = 0;
      }
      _holdTimer = Timer(_holdDuration, () {
        _holdTimer = null;
        _holdFired = true;
        _holdRingController.value = 0;
      });
      return;
    }
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
      // Same rule the charging ring/haptic above already followed (both
      // gated on `hasTarget`, never started at all on empty sky) — the
      // sound was the one piece of hold feedback that always fired
      // regardless, audible even for a hold on nothing. `_handleHold`
      // itself stays unconditional: on empty sky it already correctly
      // does nothing beyond closing an open tooltip, if any.
      if (hasTarget) widget.audioService.playHoldSound();
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
    // This touch's down event landed on a menu control (see
    // [_holdTargetIsMenuControl]'s own doc comment) — its release is the
    // control's to handle, not the sky's, no matter what a plain hit test
    // on this release position would otherwise find underneath it.
    if (_holdTargetIsMenuControl) return;
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
      // Gated on [_lastFlightMoved] (see its own doc comment): a tap on
      // whatever the camera is already sitting on triggers this same
      // branch — a real, deliberate hit — but shouldn't buzz/whoosh for a
      // "movement" that never actually happened.
      if (_lastFlightMoved) {
        if (isTouchOnlyMobile) _tapHaptic();
        widget.audioService.playTapSound();
      }
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

  /// Advances the "sky-navigation" tour past [order] once the matching
  /// real gesture has actually happened — called from the tail of the
  /// same handlers the gesture itself already runs through (`_flyToArea`,
  /// `_openStar`, `_zoomOutOneLevel`, `_holdConstellation`, and
  /// `_openMenuModal`'s own step further down), since these steps have no
  /// widget for `HintTarget`'s own `passthrough` callback pattern to sit
  /// on — see [TourGestureStep]'s own doc comment for the full mechanism.
  /// A short pause first, so the camera flight/zoom the gesture just
  /// triggered is visibly under way before the next step's card replaces
  /// this one — jumping straight to the next instruction read as the app
  /// not acknowledging what the user just did.
  ///
  /// [endsFlight] additionally clears [_hideTourDuringFlight] at the exact
  /// moment [Tour.next] is called — see that field's own doc comment for
  /// why the two are tied to this one shared timer rather than each
  /// running off its own clock.
  void _advanceGestureTourStep(int order, {bool endsFlight = false}) {
    final controller = Tour.maybeOf(context);
    if (controller == null || controller.activeTour != 'sky-navigation') {
      return;
    }
    if (TourScope.of(context).orderAt('sky-navigation', controller.index) !=
        order) {
      return;
    }
    if (endsFlight) {
      setState(() => _hideTourDuringFlight = true);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (endsFlight) {
        setState(() => _hideTourDuringFlight = false);
      }
      Tour.read(context).next();
    });
  }

  /// Reacts to the sky's own tooltip opening, closing or changing data —
  /// the `setState` nudge every part of [build] reading
  /// [_quickLookConstellation]/[_quickLookStar]/[_skyTooltipController]
  /// needs, plus advancing the "sky-navigation" tour's order-7 step
  /// ([_holdConstellation]'s own order-6 step opens the tooltip this one
  /// is about) once that tooltip actually closes.
  ///
  /// That step has no single real gesture to wait for the way every other
  /// one does — the tooltip closes via its own X, a tap outside it, or
  /// just moving the camera (see the several [TooltipCardController.close]
  /// call sites above) — so rather than adding a call to
  /// [_advanceGestureTourStep] at the tail of every one of those, this
  /// hooks the controller directly and reuses [_advanceGestureTourStep]
  /// only for its guard/pause, the same as they do.
  void _onSkyTooltipChanged() {
    if (mounted) setState(() {});
    if (!_skyTooltipController.isOpen) _advanceGestureTourStep(7);
  }

  /// The plain-tap half of a supernova hit — just the "take me there"
  /// flight every other target in the app gets, camera only, no tooltip.
  /// See [_holdArea] for the hold half, which adds the tooltip back in.
  void _flyToArea(LifeArea area) {
    _flyTo(SkyAreaTarget(area));
    _advanceGestureTourStep(2, endsFlight: true);
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
    _advanceGestureTourStep(3, endsFlight: true);
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
    _advanceGestureTourStep(6, endsFlight: true);
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
    _advanceGestureTourStep(5);
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
                  key: _skySurfaceKey,
                  fit: StackFit.expand,
                  children: [
                    NebulaBackground(
                      camera: _camera,
                      zoom: _zoom,
                      showGrid: widget.settings.showGrid,
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
                    // Order 1, the tour's own opening — deliberately unlike
                    // every step after it: no hole (nothing to point at
                    // yet), no scrim at all (`scrimOpacity: 0`, so the sky
                    // behind the card is fully visible, not dimmed), and
                    // the card sits pinned dead-center of the screen
                    // (`pinnedCardAlignment: Alignment.center`) rather than
                    // anchored to anything. One button — Start
                    // (`appTourWelcomeCard`, its own content builder, the
                    // only one in this tour with a real Next-equivalent
                    // control) — advances straight into order 2. `pulse:
                    // false` turns off the (invisible anyway, with no hole)
                    // pulsing ring, and `child: SizedBox.shrink()` matches
                    // every other pointer-free step here.
                    HintTarget(
                      key: const ValueKey('sky-nav-step-1'),
                      tour: 'sky-navigation',
                      order: 1,
                      showArrow: false,
                      pulse: false,
                      spotlightPadding: EdgeInsets.zero,
                      pinnedCardAlignment: Alignment.center,
                      theme: const HintThemeData(scrimOpacity: 0),
                      contentBuilder: appTourWelcomeCard,
                      title: context.strings.skyTourWelcomeTitle,
                      description: context.strings.skyTourWelcomeBody,
                      child: const SizedBox.shrink(),
                    ),
                    // Six gesture-driven steps — the sky itself is one
                    // hand-drawn canvas, not discrete per-star widgets, so
                    // there's nothing for a normal `HintTarget` to circle.
                    // Four of them (1/2/3/5, each pointing at a real spot —
                    // a supernova, the tour's own placeholder constellation,
                    // one of its stars) use [SkyHintTarget] instead, which
                    // cuts a real hole around that spot via the sky's own
                    // camera projection and carries its own title/body card
                    // (via [appTourGestureStepCard], Skip-only — see
                    // [SkyHintTarget]'s own doc comment for why that card,
                    // not a separate banner, is what keeps it from ending up
                    // rendered *under* the scrim: both are the same
                    // `HintTarget`'s own `Overlay` entry). The other two
                    // (5/7) have no specific spot to point at — a gesture
                    // (double-tap), and a tooltip closing — so they stay a
                    // plain full-screen [TourGestureStep] paired with its
                    // own top-of-screen [TourGestureBanner], same as before.
                    // Either way, each only registers its own order and only
                    // actually advances from the matching real gesture's own
                    // handler below (`_flyToArea`, `_openStar`, etc. — order
                    // 7 is different, see [_onSkyTooltipChanged]), not from
                    // a Next tap. Order 1, the tour's own opening, is
                    // different again — see [skyTourWelcomeTitle]'s own doc
                    // comment, just below the FAB's own steps further down.
                    //
                    // Each of the four is also gated on
                    // `!_hideTourDuringFlight` (see that field's own doc
                    // comment for why it's a dedicated flag rather than
                    // `_flyController.isAnimating` read directly): the tap
                    // that advances it also kicks off a ~900ms fly-to (see
                    // `_flyToArea`/`_flyToConstellation`/`_openStar`/
                    // `_holdConstellation`), and a scrim+card sitting
                    // frozen over a moving camera for that whole flight
                    // hid the very motion the step just asked for.
                    // Omitting the widget outright (rather than, say,
                    // fading its opacity) is safe across that gap —
                    // deregistering does not touch step counting or
                    // ordering (`TourScope.deregisterTarget`'s own doc
                    // comment), and re-registering when the flight ends
                    // replays the normal fade-in, which reads as the card
                    // "returning" rather than a glitch.
                    //
                    // Every one of steps 2-7 below carries its own
                    // explicit `ValueKey` — without one, removing steps
                    // 2-4 from this list (when `_hideTourDuringFlight`
                    // flips true) shifts everything after them up by
                    // three *positions*, and Flutter's unkeyed
                    // `updateChildren` matches children by position, not
                    // by identity: it briefly tried to turn the old
                    // position-0 `SkyHintTarget(order: 2)` into the new
                    // position-0 `TourGestureStep(order: 5)` while the
                    // *original* order-5 element (now several slots
                    // further down the shrunk list) hadn't been torn
                    // down yet, producing two simultaneously-registered
                    // `HintTarget`s for the same order and the exact
                    // "Two HintTargets are mounted..." assertion this app
                    // hit live. A `Key` per step makes every one of them
                    // independently trackable across the list's length
                    // changing, so Flutter moves/keeps each by its own
                    // identity instead of by whatever position it happens
                    // to fall on this build.
                    if (!_hideTourDuringFlight) ...[
                      SkyHintTarget(
                        key: const ValueKey('sky-nav-step-2'),
                        tour: 'sky-navigation',
                        order: 2,
                        title: context.strings.skyTourTapSupernovaTitle,
                        description: context.strings.skyTourTapSupernovaBody,
                        skySurfaceKey: _skySurfaceKey,
                        camera: () => _camera,
                        zoom: () => _zoom,
                        spotlightPadding: const EdgeInsets.all(56),
                        worldPosition: (camera, zoom, screenSize) =>
                            areaWorldPosition(_tutorialArea),
                      ),
                      SkyHintTarget(
                        key: const ValueKey('sky-nav-step-3'),
                        tour: 'sky-navigation',
                        order: 3,
                        title: context.strings.skyTourTapConstellationTitle,
                        description:
                            context.strings.skyTourTapConstellationBody,
                        skySurfaceKey: _skySurfaceKey,
                        camera: () => _camera,
                        zoom: () => _zoom,
                        spotlightPadding: const EdgeInsets.all(48),
                        worldPosition: (camera, zoom, screenSize) =>
                            tutorialDemoWorldPosition(_tutorialArea),
                      ),
                      SkyHintTarget(
                        key: const ValueKey('sky-nav-step-4'),
                        tour: 'sky-navigation',
                        order: 4,
                        title: context.strings.skyTourTapStarTitle,
                        description: context.strings.skyTourTapStarBody,
                        skySurfaceKey: _skySurfaceKey,
                        camera: () => _camera,
                        zoom: () => _zoom,
                        spotlightPadding: const EdgeInsets.all(24),
                        worldPosition: (camera, zoom, screenSize) {
                          final placed = _tutorialDemoPlacedOrNull();
                          if (placed == null) return null;
                          final star = _tutorialDemoTapStar(placed);
                          if (star == null) return null;
                          return starWorldPosition(
                            placed,
                            star,
                            camera,
                            zoom,
                            screenSize,
                          );
                        },
                      ),
                    ],
                    // A real spotlight hole over an empty patch of sky —
                    // see [TourGestureEmptySpotHint]'s own doc comment for
                    // why order 5 gets one instead of the fully invisible
                    // scrim every other gesture step uses.
                    const TourGestureEmptySpotHint(
                      key: ValueKey('sky-nav-step-5'),
                      tour: 'sky-navigation',
                      order: 5,
                    ),
                    if (!_hideTourDuringFlight)
                      SkyHintTarget(
                        key: const ValueKey('sky-nav-step-6'),
                        tour: 'sky-navigation',
                        order: 6,
                        title: context.strings.skyTourHoldTitle,
                        description: context.strings.skyTourHoldBody,
                        skySurfaceKey: _skySurfaceKey,
                        camera: () => _camera,
                        zoom: () => _zoom,
                        spotlightPadding: const EdgeInsets.all(48),
                        worldPosition: (camera, zoom, screenSize) =>
                            tutorialDemoWorldPosition(_tutorialArea),
                      ),
                    TourGestureStep(
                      key: const ValueKey('sky-nav-step-7'),
                      tour: 'sky-navigation',
                      order: 7,
                    ),
                    TourGestureBanner(
                      tour: 'sky-navigation',
                      order: 5,
                      title: context.strings.skyTourDoubleTapTitle,
                      description: context.strings.skyTourDoubleTapBody,
                    ),
                    // Sits on top of the tooltip [_holdConstellation]'s own
                    // hold just opened — no gesture of its own to wait for,
                    // just the tooltip closing (see
                    // [_onSkyTooltipChanged]), whichever way that happens.
                    TourGestureBanner(
                      tour: 'sky-navigation',
                      order: 7,
                      title: context.strings.skyTourTooltipTitle,
                      description: context.strings.skyTourTooltipBody,
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
                            // Order 10 wraps order 8's own `HintTarget`
                            // rather than replacing it — the two are
                            // never active at once (the tour has already
                            // moved past 8 by the time 10 comes up), and
                            // nesting is what lets both point at this
                            // exact same button/hole without duplicating
                            // `_MenuStarButton` itself. See
                            // [skyTourQuickMenuTapTitle]'s own doc
                            // comment for the step sequence this and
                            // order 8 are now part of.
                            child: HintTarget(
                              tour: 'sky-navigation',
                              order: 10,
                              showArrow: true,
                              // Real (quick) tap advances this one too
                              // (see `_toggleQuickAccessMenu`) — same
                              // reasoning as order 8's own `passthrough`.
                              passthrough: true,
                              spotlight: SpotlightShape.circle,
                              spotlightPadding: const EdgeInsets.all(-11),
                              contentBuilder: appTourGestureStepCard,
                              title: context.strings.skyTourQuickMenuTapTitle,
                              description:
                                  context.strings.skyTourQuickMenuTapBody,
                              child: HintTarget(
                                tour: 'sky-navigation',
                                order: 8,
                                showArrow: true,
                                // Real tap advances this one too (see
                                // `_openMenuModal`) — `passthrough` has to
                                // let the actual press through to
                                // `_MenuStarButton` underneath instead of
                                // the scrim swallowing it.
                                passthrough: true,
                                // A circle, not the default rounded rect —
                                // matches the button's own round shape
                                // instead of leaving dimmed corners inside
                                // a squared-off hole.
                                spotlight: SpotlightShape.circle,
                                // Negative on purpose: `_MenuStarButton`'s
                                // own measured size is its 110×110 tap
                                // target (see `_tapTargetSize`),
                                // deliberately much bigger than what it
                                // actually draws — the visible mark is the
                                // app logo at `_logoSize` (72px), not the
                                // underlying `_iconSize` (58px) an earlier
                                // pass mistakenly used here, which pulled
                                // the hole in too far and nearly clipped
                                // the logo. -11 targets a hole of
                                // 72 + 2*8 = 88px — the same ~8px gap
                                // Sound Lab gets from the theme's plain
                                // default, around the logo's own real
                                // size.
                                spotlightPadding: const EdgeInsets.all(-11),
                                contentBuilder: appTourGestureStepCard,
                                title: context.strings.skyTourMenuTitle,
                                description: context.strings.skyTourMenuBody,
                                child: _MenuStarButton(
                                  key: _menuStarButtonKey,
                                  onTap: _openMenuModal,
                                  onQuickTap: _toggleQuickAccessMenu,
                                  onPressChanged: _setMenuControlPressed,
                                ),
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
                    // Parked behind [_showSoundLabButton] now that
                    // [QuickSettingsScreen] covers this same shortcut.
                    if (_showSoundLabButton)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _SkyOverlayButton(
                              icon: Icons.graphic_eq,
                              tooltip: context.strings.soundLabButtonTooltip,
                              onTap: _openSoundLab,
                            ),
                          ),
                        ),
                      ),
                    // Tutorial management (on/off switch + reset) — right
                    // below the Sound Lab button, same corner, same style;
                    // no `HintTarget` of its own since it isn't part of any
                    // tour. See `showTutorialManagementDialog`'s own doc
                    // comment for why this moved out of Settings. Parked
                    // behind [_showTutorialsButton] for the same reason as
                    // [_showSoundLabButton] just above.
                    if (_showTutorialsButton)
                      Positioned(
                        top: 64,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _SkyOverlayButton(
                              icon: Icons.school_outlined,
                              tooltip: context.strings.tutorialsButtonTooltip,
                              onTap: () => showTutorialManagementDialog(
                                context,
                                settings: widget.settings,
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
                    // A full-screen catch-all that closes the quick-access
                    // menu on an outside tap — sits right under the fan
                    // itself (next) so both paint/hit-test above every
                    // other control here, last two in this Stack on
                    // purpose. [IgnorePointer] while closed lets every
                    // normal gesture on the sky pass straight through, the
                    // same as if this widget weren't here at all.
                    IgnorePointer(
                      ignoring: !_quickAccessMenuOpen,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeQuickAccessMenu,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // The quick-access mini menu itself (see
                    // [_QuickAccessFan]) — same bottom-center anchor as
                    // [_MenuStarButton] just above (same
                    // [SafeArea]/[Padding]/[Center] wrapping), so its own
                    // fan of buttons arcs out from that exact button's
                    // center rather than an independently-tuned spot.
                    // Always mounted (never conditionally built) so it can
                    // fade/scale in and out instead of popping; only
                    // interactive while open.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: IgnorePointer(
                              ignoring: !_quickAccessMenuOpen,
                              child: AnimatedScale(
                                scale: _quickAccessMenuOpen ? 1 : 0.85,
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                child: AnimatedOpacity(
                                  opacity: _quickAccessMenuOpen ? 1 : 0,
                                  duration: const Duration(milliseconds: 160),
                                  child: _QuickAccessFan(
                                    onQuickSettings: () =>
                                        _selectQuickAccess(_openQuickSettings),
                                    onSupernovas: () =>
                                        _selectQuickAccess(_openVisions),
                                    onConstellations: () => _selectQuickAccess(
                                      _openNewConstellation,
                                    ),
                                    onStars: () =>
                                        _selectQuickAccess(_openStarForm),
                                    onSearch: () =>
                                        _selectQuickAccess(_openSearch),
                                    onPressChanged: _setMenuControlPressed,
                                  ),
                                ),
                              ),
                            ),
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
  const _MenuStarButton({
    super.key,
    required this.onTap,
    required this.onQuickTap,
    this.onPressChanged,
  });

  final VoidCallback onTap;

  // A plain tap — released before the charge below reaches 1.0 — used to
  // open the quick-access mini menu (see `_QuickAccessFan`) instead of
  // doing nothing, which is what a released-early press did before. Only
  // fires on a genuine release (`onTapUp`), not on `onTapCancel` (the
  // gesture arena handing this touch to something else, e.g. a pan
  // starting on top of this button) — see `_handleTapUp`/`_handleTapCancel`.
  final VoidCallback onQuickTap;

  /// Called `true` the instant a touch lands here, `false` the instant it
  /// releases or cancels — see `_SkyScreenState._menuControlPressed`'s own
  /// doc comment for why the sky needs to know this at all.
  final ValueChanged<bool>? onPressChanged;

  @override
  State<_MenuStarButton> createState() => _MenuStarButtonState();
}

class _MenuStarButtonState extends State<_MenuStarButton>
    with TickerProviderStateMixin {
  // Purely what [_scale]/[_glowCanvasSize] below size the shader's own
  // glow off of — no longer tied to a drawn glyph size now that the
  // button's actual icon is [_svgIconSize]/[app_star.svg] instead (see
  // [_buildButtonAndLabel]).
  static const _iconSize = 58.0;
  // The invisible tap target — kept generous and bigger than the disc
  // actually drawn on it (see [_visibleSize]) for a comfortable hit area,
  // same as this had before the navy-disc look. [_QuickAccessFan._hubLift]
  // depends on this exact value staying the main button's own touch
  // footprint.
  static const _tapTargetSize = 110.0;
  // The navy-disc-with-border button actually drawn on screen — matches
  // [_QuickAccessButton]'s own look, just bigger since this is the main
  // button, but nowhere near [_tapTargetSize]: sizing the visible disc to
  // the tap target itself (tried first) drew a button far bigger than
  // this one ever visually was.
  static const _visibleSize = 72.0;
  // Smaller than [_QuickAccessButton]'s own 24/40 icon-to-disc ratio —
  // that ratio read as too big on this button's own bigger disc.
  static const _svgIconSize = _visibleSize * 0.44;
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
  // The "MENU" caption under the button, off for now — not deleted, kept
  // wired up so flipping it back to true restores it exactly as it was.
  static const _showMenuLabel = false;
  // See [kHoldGestureDuration] — shared with the sky's own hold-to-peek
  // so the two gestures feel like one consistent timing across the
  // screen, rather than two independently-tuned numbers that happened to
  // be close.
  static const _chargeDuration = kHoldGestureDuration;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  // A press doesn't open the menu itself — it charges this for as long
  // as the finger stays down, and the menu only opens once it reaches
  // 1.0 (see the status listener in initState); let go early and it
  // reverses back to 0 instead of firing. Its own value, read straight
  // in build() below (already rebuilding every frame off [_ticker]), is
  // what drives `supernovaGlow`'s own [chargeGlow].
  late final AnimationController _chargeController;
  // Used to show this briefly whenever a press let go before the charge
  // completed and wasn't a real tap either (see [_handleTapCancel]) — a
  // plain tap now opens the quick-access mini menu instead (see
  // [_MenuStarButtonState.build]'s own [_showHoldHintFeature] doc comment
  // for why that path is off for now), so this never actually fires at
  // the moment, but stays wired up rather than deleted. Visible for
  // [_hintVisibleDuration], then faded out quickly (see the
  // AnimatedOpacity in build()) rather than lingering.
  bool _showHoldHint = false;
  Timer? _hintTimer;
  static const _hintVisibleDuration = Duration(milliseconds: 1100);
  // See the doc comment on [_showHoldHint] just above — the only place
  // left that could still trigger the hint (a real cancel, not a tap) is
  // gated behind this now that a plain tap has its own job. Off rather
  // than deleted, same pattern as [_showStarRingIcon]/[_showMenuLabel]
  // below: flip back to true to restore it exactly as it was.
  static const _showHoldHintFeature = false;

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
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/menu_star_button.frag',
    );
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  void _handlePressStart() {
    widget.onPressChanged?.call(true);
    _chargeController.forward();
    if (isTouchOnlyMobile) _startHoldHaptic();
  }

  // A genuine release — the gesture stayed on this button the whole time,
  // finger lifted here. Letting go before the charge reaches 1.0 backs it
  // off rather than leaving it stuck wherever it was, same as
  // [_handleTapCancel] below, but this is also a real tap on its own
  // right: it's what now opens the quick-access mini menu (see
  // [_MenuStarButton.onQuickTap]), taking over from the hold-hint label
  // this used to show instead (see [_showHoldHint]'s own doc comment for
  // why that's parked rather than deleted).
  void _handleTapUp() {
    widget.onPressChanged?.call(false);
    _stopHoldHaptic();
    if (_chargeController.status == AnimationStatus.forward) {
      _chargeController.reverse();
      widget.onQuickTap();
    }
  }

  // The gesture arena handing this touch to something else instead (e.g. a
  // pan starting on top of this button) — unlike [_handleTapUp], not a
  // real tap, so it only backs the charge off, nothing more.
  void _handleTapCancel() {
    widget.onPressChanged?.call(false);
    _stopHoldHaptic();
    if (_chargeController.status == AnimationStatus.forward) {
      _chargeController.reverse();
      if (_showHoldHintFeature) {
        _hintTimer?.cancel();
        setState(() => _showHoldHint = true);
        _hintTimer = Timer(_hintVisibleDuration, () {
          if (mounted) setState(() => _showHoldHint = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _chargeController.dispose();
    _hintTimer?.cancel();
    _stopHoldHaptic();
    _shader?.dispose();
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
                    painter: _MenuStarGlowPainter(
                      shader: shader,
                      time:
                          _elapsed.inMicroseconds /
                          Duration.microsecondsPerSecond,
                      scale: _scale,
                      charge: _chargeController.value,
                    ),
                  ),
                ),
              ),
            // The same "white icon on a navy disc with a white border"
            // look every [_QuickAccessButton] uses, just at this button's
            // own bigger [_visibleSize] — a real drawn circle now (unlike
            // the borderless, purely-photographic-logo look this used to
            // have), so it reads as one more button in that same family
            // rather than a free-floating glowing icon. Wrapped in its own
            // centered [SizedBox] rather than sized to fill the InkWell
            // below directly, since that tap target is deliberately
            // bigger than this disc (see [_tapTargetSize]).
            IgnorePointer(
              child: SizedBox(
                width: _visibleSize,
                height: _visibleSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.nightPanel,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icon/app_star.svg',
                      width: _svgIconSize,
                      height: _svgIconSize,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
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
                onTapUp: (_) => _handleTapUp(),
                onTapCancel: _handleTapCancel,
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

/// The quick-access mini menu's five buttons, fanned out in a dome above
/// [_MenuStarButton] — flutter_expandable_fab's "center fan" arrangement,
/// built by hand instead of the package itself: [_MenuStarButton] is
/// already a bespoke shader-drawn control with its own hold-to-charge
/// gesture, not a real [FloatingActionButton], so there's no host widget
/// that package could actually expand. Left to right per the request this
/// was built from: Quick Settings, Supernovas, Constellations, Stars,
/// Search.
class _QuickAccessFan extends StatelessWidget {
  const _QuickAccessFan({
    required this.onQuickSettings,
    required this.onSupernovas,
    required this.onConstellations,
    required this.onStars,
    required this.onSearch,
    this.onPressChanged,
  });

  final VoidCallback onQuickSettings;
  final VoidCallback onSupernovas;
  final VoidCallback onConstellations;
  final VoidCallback onStars;
  final VoidCallback onSearch;

  /// Forwarded to every [_QuickAccessButton] below — see
  /// `_SkyScreenState._menuControlPressed`'s own doc comment for what this
  /// is for.
  final ValueChanged<bool>? onPressChanged;

  // An ellipse, not a circle: [_radiusX] alone decides how far Quick
  // Settings/Search reach out to the sides (see [_angleDeg] — they sit at
  // exactly 180°/0°, so only [_radiusX] ever affects their position, never
  // [_radiusY]), while [_radiusY] alone decides how high
  // Supernovas/Constellations/Stars dome up above the main button. Shrunk
  // from an equal-on-both-axes 92 (itself already pulled in from an even
  // wider 118) specifically to lower that dome per request, without also
  // pulling the two side buttons in past where they need to be to clear
  // the main button horizontally.
  static const _radiusX = 100.0;
  static const _radiusY = 85.0;
  // [_MenuStarButtonState._tapTargetSize] halved — the main button's own
  // visible box sits with its *bottom* edge, not its center, on this
  // fan's own shared baseline (both are anchored the same way: see the
  // matching [SafeArea]/[Padding]/[Center] wrapping at each call site in
  // build()), so this is what actually lines this fan's hub up with that
  // button's true center instead of its bottom edge.
  static const _hubLift = 55.0;
  // One angle per button, left to right, measured the way [math.cos]/
  // [math.sin] expect (0° is straight right, 90° straight up). Quick
  // Settings and Search sit at exactly 180°/0° — pure horizontal, so
  // [_radiusY]'s own vertical contribution (`sin(180°)`/`sin(0°)`, both
  // 0) drops out entirely and their center lands exactly [_hubLift] above
  // the baseline, the same height as the main button's own true center,
  // by construction rather than by tuning — "all three centers on one
  // horizontal line", per request. Supernovas/Constellations/Stars stay
  // in a tighter 30°-apart cluster around 90° (dead center, straight up),
  // leaving a wide, visibly empty 60° gap on the arc between that middle
  // cluster and each side button.
  static const _angleDeg = [180.0, 120.0, 90.0, 60.0, 0.0];

  /// The tour's own five steps over these buttons (orders 11-15, left to
  /// right — see [skyTourQuickMenuTapTitle]'s own doc comment for where
  /// they fit in the sequence). Purely informational: `passthrough` stays
  /// off (the default), so the real buttons stay inert — can't actually
  /// be used to navigate away — until the tour reaches its last step and
  /// finishes, at which point every `HintTarget` here simply goes back to
  /// doing nothing on its own (the buttons' real `onTap`s were always
  /// live underneath; only the scrim was ever in the way). Their card
  /// (`appTourStepCardNoSkip`) still offers Next/Back — there is no real
  /// gesture to wait for here — but never Skip, same as every other step
  /// in this tour.
  static const _firstOrder = 11;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final items =
        <(IconData, String tooltip, VoidCallback, String title, String body)>[
          (
            Icons.tune,
            strings.quickSettingsButtonTooltip,
            onQuickSettings,
            strings.skyTourQuickSettingsHintTitle,
            strings.skyTourQuickSettingsHintBody,
          ),
          (
            Icons.flare,
            strings.lightYourSkyChooserSupernovaOption,
            onSupernovas,
            strings.skyTourSupernovasHintTitle,
            strings.skyTourSupernovasHintBody,
          ),
          (
            Icons.auto_awesome,
            strings.menuNewConstellation,
            onConstellations,
            strings.skyTourConstellationsHintTitle,
            strings.skyTourConstellationsHintBody,
          ),
          (
            Icons.star,
            strings.menuLightAStar,
            onStars,
            strings.skyTourStarsHintTitle,
            strings.skyTourStarsHintBody,
          ),
          (
            Icons.saved_search,
            strings.menuSearch,
            onSearch,
            strings.skyTourSearchHintTitle,
            strings.skyTourSearchHintBody,
          ),
        ];

    return SizedBox(
      width: 280,
      height: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < items.length; i++)
            _fanItem(angleDeg: _angleDeg[i], order: _firstOrder + i, item: items[i]),
        ],
      ),
    );
  }

  /// One fan button, translated out from the shared hub by [angleDeg] (see
  /// the class doc comment for the angle convention) — split out from
  /// [build] just to keep that `for` loop itself readable.
  Widget _fanItem({
    required double angleDeg,
    required int order,
    required (IconData, String, VoidCallback, String, String) item,
  }) {
    final angleRad = angleDeg * math.pi / 180;
    final offset = Offset(
      _radiusX * math.cos(angleRad),
      -(_radiusY * math.sin(angleRad) + _hubLift),
    );
    final (icon, tooltip, onTap, title, body) = item;
    return Transform.translate(
      offset: offset,
      child: HintTarget(
        tour: 'sky-navigation',
        order: order,
        spotlight: SpotlightShape.circle,
        // Forced above every one of these five buttons rather than left
        // to `HintDirection.auto`'s own default preference (bottom first)
        // — these all sit near the bottom of the screen, where "below"
        // reads as sitting right on top of Android's own gesture/nav
        // bar, not as this app's own UI. `showArrow: true` draws the
        // caret that comes with it, pointing down at the button each
        // card belongs to.
        direction: HintDirection.top,
        showArrow: true,
        contentBuilder: appTourStepCardNoSkip,
        title: title,
        description: body,
        child: _QuickAccessButton(
          icon: icon,
          tooltip: tooltip,
          onTap: onTap,
          onPressChanged: onPressChanged,
        ),
      ),
    );
  }
}

/// One button on [_QuickAccessFan] — the app's "white on navy" look (see
/// the hold-hint label and the tour's own Skip/Back/Next buttons for the
/// same pairing elsewhere) rather than [skyControlDecoration]'s usual
/// gold-on-translucent, so this reads as its own distinct control, not one
/// more thing in the gold-ringed family [_SkyOverlayButton] belongs to.
class _QuickAccessButton extends StatelessWidget {
  const _QuickAccessButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onPressChanged,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// See `_SkyScreenState._menuControlPressed`'s own doc comment — same
  /// leaking-touch problem as [_MenuStarButton], just without a hold
  /// gesture of its own: a plain [InkWell] still fires `onTapDown` (and
  /// therefore the sky's own `_handleTapDown`) the instant a touch lands,
  /// well before it resolves into a real tap.
  final ValueChanged<bool>? onPressChanged;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.nightPanel,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: InkWell(
          onTapDown: (_) => onPressChanged?.call(true),
          onTapCancel: () => onPressChanged?.call(false),
          onTap: () {
            onPressChanged?.call(false);
            onTap();
          },
          child: SizedBox(
            width: _size,
            height: _size,
            child: Tooltip(
              message: tooltip,
              child: Center(child: Icon(icon, color: Colors.white, size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

// Just the shader's own additive nebula behind the button (see
// menu_star_button.frag's `supernovaGlow`) — the resting/idle glow plus the
// growing `chargeGlow` while the button is held. The icon itself is a
// plain [SvgPicture] drawn as a normal widget on top (see
// `_MenuStarButtonState._buildButtonAndLabel`) now, not painted into this
// same canvas — this used to also draw a raster logo here, with several
// extra glow/bloom passes layered around it (one of them skipped on web
// for a blur+blend bug there); all of that went with the logo, so this
// canvas is nothing but the shader now, identical on every platform.
class _MenuStarGlowPainter extends CustomPainter {
  const _MenuStarGlowPainter({
    required this.shader,
    required this.time,
    required this.scale,
    required this.charge,
  });

  final ui.FragmentShader shader;
  final double time;
  final double scale;
  // 0..1 — see `_MenuStarButtonState._chargeController`.
  final double charge;

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
  }

  @override
  bool shouldRepaint(covariant _MenuStarGlowPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.scale != scale ||
      oldDelegate.charge != charge;
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
