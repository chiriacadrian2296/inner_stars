import 'dart:async';

import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../theme/nightlight_style.dart';
import '../widgets/nightlight_star_glow.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/nightlight_zone_measurer.dart';
import '../widgets/responsive_content.dart';
import 'admire_stars_screen.dart';

enum _BreathPhase { inhale, holdFull, exhale, holdEmpty }

/// What the post-exercise check-in dialog (see [_NightlightBreathingScreenState._onCyclesFinished])
/// was answered with.
enum _CheckInAction { redo, proceed }

/// The last screen of the Nightlight "in crisis" path, reached from
/// [NightlightExplainedScreen] — a fixed box-breathing rhythm
/// ([_breathDuration] in, a brief [_holdDuration], the same out, another
/// brief hold), [_totalCycles] times (~2 minutes total), with a short
/// countdown first. [NightlightStarGlow] is the thing that actually
/// grows/shrinks with the breath, driven by [_controller]'s own 0-1 value,
/// rather than a plain circle.
///
/// If the user taps "I'm ready" (allowed once the 3rd cycle finishes),
/// it goes straight to [AdmireStarsScreen] — that's an explicit "I'm okay
/// now". If the cycles instead run out on their own, [_onCyclesFinished]
/// asks first rather than assuming the exercise alone was enough.
class NightlightBreathingScreen extends StatefulWidget {
  const NightlightBreathingScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<NightlightBreathingScreen> createState() =>
      _NightlightBreathingScreenState();
}

class _NightlightBreathingScreenState extends State<NightlightBreathingScreen>
    with TickerProviderStateMixin, NightlightZoneMeasuring {
  // The actual in/out movement — long, so the wave/glow have room to
  // visibly ease rather than snap through the middle at a steady rate.
  static const _breathDuration = Duration(milliseconds: 5000);
  // The pause at each extreme — brief on purpose. An earlier pass gave
  // this the same length as the movement itself, which read as "nothing
  // happening" for half of every cycle; this should feel like a held
  // breath, not a stop.
  static const _holdDuration = Duration(milliseconds: 1000);
  // 10 × (5+1+5+1)s = exactly 2 minutes — long enough to be worth a cycle
  // counter and a running clock (see [_currentCycle]/[_remaining]).
  static const _totalCycles = 10;
  static const _countdownStart = 3;

  static const _totalExerciseDuration = Duration(
    milliseconds: _totalCycles * 2 * (_breathDurationMs + _holdDurationMs),
  );
  // Kept as separate raw-millisecond consts (rather than reading
  // `_breathDuration.inMilliseconds` above) only because a const
  // expression can't call an instance getter, even on another const value
  // — these two must stay equal to [_breathDuration]/[_holdDuration].
  static const _breathDurationMs = 5000;
  static const _holdDurationMs = 1000;

  // One "Breathe in"/"Breathe out" label spans its full half of the cycle
  // (the movement plus the hold that follows it) — see [_startLabelFade]/
  // [_labelOpacityAt] — rather than switching again at every one of the 4
  // sub-phases, which would have put a third "Hold" label between every
  // in/out instead of the gap this is meant to read as.
  static const _halfCycleDurationMs = _breathDurationMs + _holdDurationMs;
  static const _halfCycleDuration = Duration(
    milliseconds: _halfCycleDurationMs,
  );
  // Each label waits this long into its own half before it starts fading
  // in, and finishes fading out this long before that half actually ends —
  // the same offset on both ends, so there's a real stretch with nothing
  // shown around every boundary (roughly centered on the hold, where the
  // breath itself is paused) rather than one label fading in the instant
  // the other reaches zero.
  static const _labelFadeDelayMs = 500;
  static const _labelFadeMs = 2000;

  late final AnimationController _controller = AnimationController(vsync: this);
  late final AnimationController _labelController = AnimationController(
    vsync: this,
    duration: _halfCycleDuration,
  );
  // A one-shot 0-1 sweep of its own, entirely separate from [_controller]
  // (which keeps cycling 0-1-0 every breath) — [_run] starts it exactly
  // once, right after the countdown ends, and nothing ever resets it
  // mid-exercise. Driving the running content's fade-in off [_controller]
  // itself instead made it fade back out (and back in) every single cycle,
  // since that value keeps revisiting the low end it started from.
  late final AnimationController _introOpacityController = AnimationController(
    vsync: this,
    duration: _breathDuration,
  );
  late final Animation<double> _introOpacity = CurvedAnimation(
    parent: _introOpacityController,
    curve: Curves.easeIn,
  );
  final Stopwatch _exerciseStopwatch = Stopwatch();

  int _countdown = 3;
  bool _countingDown = true;
  _BreathPhase _phase = _BreathPhase.inhale;
  int _currentCycle = 0;
  bool _canSkip = false;
  bool _showSkipGlow = false;

  final _centerContentKey = GlobalKey();
  final _skipButtonKey = GlobalKey();

  // [FontFeature.tabularFigures] alone didn't stop the countdown/remaining
  // time from visibly shifting as its digits changed — [kFontBranding]
  // (Gloock) doesn't actually define the OpenType tables that feature
  // depends on, so the request is silently ignored and every glyph keeps
  // its own natural, unequal advance width. Fixed here instead by measuring
  // the widest any single digit renders at each size, once, and giving the
  // text a box exactly that wide (times how many digits it always has) —
  // centered inside it, so the box itself never resizes as digits change,
  // regardless of whether the font's own glyph widths are uniform.
  static const _countdownStyle = TextStyle(
    fontFamily: kFontBranding,
    fontSize: 72,
  );
  static const _remainingStyle = TextStyle(
    fontFamily: kFontBranding,
    fontSize: 32,
  );
  // A little slack added on top of the raw measurement below — summing
  // individually-measured characters can come in a hair narrower than the
  // same characters actually rendered together (kerning/rounding), and
  // without this margin that was enough to make the text wrap onto a
  // second line right at the box's own edge (visibly hit at "0:00").
  static const _textWidthSafetyMargin = 6.0;
  late final double _countdownDigitWidth =
      _widestDigitWidth(_countdownStyle) + _textWidthSafetyMargin;
  late final double _remainingWidth =
      _widestDigitWidth(_remainingStyle) * 3 +
      _measureText(':', _remainingStyle) +
      _textWidthSafetyMargin;

  static double _widestDigitWidth(TextStyle style) {
    var maxWidth = 0.0;
    for (var d = 0; d <= 9; d++) {
      final width = _measureText('$d', style);
      if (width > maxWidth) maxWidth = width;
    }
    return maxWidth;
  }

  static double _measureText(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  /// Set the moment the exercise ends one way or another (finished, skipped,
  /// or backed out of) — checked between every `await` in [_run] so that
  /// coroutine stops touching `setState`/the controller instead of relying
  /// on `mounted`, since navigating away doesn't unmount this widget until
  /// its own route transition finishes.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _done = true;
    _controller.stop();
    _controller.dispose();
    _labelController.stop();
    _labelController.dispose();
    _introOpacityController.stop();
    _introOpacityController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    // The wave/glow both read [_controller.value] straight, and it starts
    // at its default 0 — left alone, the countdown would sit through a
    // fully dark composition (the wave's darkest color pinned across
    // almost the whole screen) for its entire 3 seconds, reading as an
    // unintended scrim over everything but the countdown digit itself. Set
    // once, directly, rather than *animated* there — the gradient wave
    // shouldn't visibly move at all during the countdown; that motion (and
    // everything else fading in with it) is meant to start only once the
    // countdown actually ends, with the first inhale.
    _controller.value = 0.5;
    for (var i = _countdownStart; i > 0; i--) {
      if (_done) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (_done) return;
    _exerciseStopwatch
      ..reset()
      ..start();
    setState(() => _countingDown = false);
    // Starts only now — right as the countdown actually ends, not
    // alongside it — and only this once; nothing later ever restarts it,
    // so the running content it fades in stays fully visible from here on.
    unawaited(_introOpacityController.forward());

    for (var cycle = 0; cycle < _totalCycles; cycle++) {
      if (_done) return;
      setState(() => _currentCycle = cycle);
      _startLabelFade();
      await _runPhase(_BreathPhase.inhale, 0, 1);
      if (_done) return;
      await _runPhase(_BreathPhase.holdFull, 1, 1);
      if (_done) return;
      _startLabelFade();
      await _runPhase(_BreathPhase.exhale, 1, 0);
      if (_done) return;
      await _runPhase(_BreathPhase.holdEmpty, 0, 0);
      if (cycle == 2 && !_done) {
        setState(() => _canSkip = true);
        // The glow fades in as its own, later step — see the skip
        // button's own build code — rather than together with the button
        // itself.
        unawaited(
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!_done && mounted) setState(() => _showSkipGlow = true);
          }),
        );
      }
    }
    _exerciseStopwatch.stop();
    if (!_done) _onCyclesFinished();
  }

  Future<void> _runPhase(_BreathPhase phase, double from, double to) async {
    setState(() => _phase = phase);
    if (from == to) {
      // A hold: [_controller] is already sitting at `to` (the previous
      // phase just finished there), so `animateTo(to, ...)` below would
      // have nothing to actually animate — and `AnimationController`
      // special-cases exactly that ("already at target") by completing in
      // zero time, silently ignoring whatever `duration` was asked for.
      // That's what was eating [_holdDuration] out of every hold, real
      // wall-clock time, while [_totalExerciseDuration] still counted it —
      // 20 holds' worth (2 per cycle × [_totalCycles]) unaccounted for by
      // the time the exercise actually finished, left sitting on the
      // clock instead of reaching 0:00. A plain delay actually waits.
      await Future.delayed(_holdDuration);
      return;
    }
    // No explicit `_controller.value = from` here — [_controller] is
    // already sitting at `from` by the time this runs (either the previous
    // phase ended there, or, for the very first inhale, the countdown's
    // own settle-to-0.5 animation left it there). Forcing it would snap
    // that value backwards instead of letting this phase continue smoothly
    // from wherever the controller actually is.
    await _controller.animateTo(
      to,
      duration: _breathDuration,
      // Every animated bit of this screen (the star glow, the gradient
      // wave) reads its motion straight off [_controller.value], so this
      // one curve is the only place the "soft, unhurried" feel needs to
      // come from. Cubic rather than the steeper Quart an earlier pass
      // used — Quart's own middle stretch moved noticeably fast to make up
      // for how flat it stays at each end; this keeps the same slow,
      // settled ends without that fast swing through the middle.
      curve: Curves.easeInOutCubic,
    );
  }

  // The hold that follows each movement keeps showing that same movement's
  // label (see [_startLabelFade]'s own doc comment) — there's no separate
  // "Hold" text anymore.
  String _phaseLabel(AppStrings strings) {
    switch (_phase) {
      case _BreathPhase.inhale:
      case _BreathPhase.holdFull:
        return strings.nightlightBreathingInhale;
      case _BreathPhase.exhale:
      case _BreathPhase.holdEmpty:
        return strings.nightlightBreathingExhale;
    }
  }

  /// Restarts [_labelController]'s 0-1 sweep from scratch — called exactly
  /// once per half-cycle, right as its movement phase begins (inhale or
  /// exhale), so the sweep's own [_halfCycleDuration] lines up with that
  /// movement plus the hold that follows it. [_labelOpacityAt] is what
  /// turns this plain 0-1 value into the actual fade-in/hold/fade-out/gap
  /// shape.
  void _startLabelFade() {
    _labelController
      ..stop()
      ..value = 0;
    unawaited(
      _labelController.animateTo(
        1,
        duration: _halfCycleDuration,
        curve: Curves.linear,
      ),
    );
  }

  /// The current label's opacity for a given point in its own sweep
  /// ([_labelController]'s value, 0 at the movement's start to 1 at the end
  /// of the hold that follows it): invisible for [_labelFadeDelayMs], a
  /// fade in, held fully visible, a fade out, then invisible again for the
  /// last [_labelFadeDelayMs] — see that constant's own doc comment for why.
  /// Each fade's own raw linear fraction is eased through [Curves.easeInOut]
  /// rather than used straight, so the label eases into and out of view
  /// instead of fading at a flat, constant rate.
  static double _labelOpacityAt(double t) {
    final ms = t * _halfCycleDurationMs;
    const fadeInStart = _labelFadeDelayMs;
    const fadeInEnd = fadeInStart + _labelFadeMs;
    const fadeOutEnd = _halfCycleDurationMs - _labelFadeDelayMs;
    const fadeOutStart = fadeOutEnd - _labelFadeMs;
    if (ms < fadeInStart || ms > fadeOutEnd) return 0;
    if (ms < fadeInEnd) {
      return Curves.easeInOut.transform((ms - fadeInStart) / _labelFadeMs);
    }
    if (ms > fadeOutStart) {
      return Curves.easeInOut.transform((fadeOutEnd - ms) / _labelFadeMs);
    }
    return 1;
  }

  static String _formatRemaining(Duration remaining) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes;
    final seconds = clamped.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Reached when the cycles run out on their own, as opposed to the user
  /// tapping "I'm ready" themselves (that goes straight to
  /// [_advanceToAdmire]) — the exercise finishing isn't the same thing as
  /// it having worked, so this asks rather than assuming.
  Future<void> _onCyclesFinished() async {
    if (_done) return;
    final colors = context.colors;
    final strings = context.strings;
    final action = await showDialog<_CheckInAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.nightPanel,
        title: Text(
          strings.nightlightBreathingCheckInTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 260,
          child: Text(
            strings.nightlightBreathingCheckInBody,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        actions: [
          OutlinedButton(
            style: nightlightOutlinedButtonStyle(colors),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CheckInAction.redo),
            child: Text(strings.nightlightBreathingCheckInRedo),
          ),
          ElevatedButton(
            style: nightlightButtonStyle(colors),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CheckInAction.proceed),
            child: Text(strings.nightlightBreathingCheckInProceed),
          ),
        ],
      ),
    );
    if (_done) return;
    if (action == _CheckInAction.redo) {
      _restart();
    } else {
      _advanceToAdmire();
    }
  }

  void _restart() {
    if (_done) return;
    _controller.value = 0;
    _labelController.stop();
    _labelController.value = 0;
    _introOpacityController.stop();
    _introOpacityController.value = 0;
    setState(() {
      _countdown = _countdownStart;
      _countingDown = true;
      _phase = _BreathPhase.inhale;
      _currentCycle = 0;
      _canSkip = false;
      _showSkipGlow = false;
    });
    _run();
  }

  void _advanceToAdmire() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AdmireStarsScreen(
          starRepository: widget.starRepository,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
  }

  void _goBack() {
    _done = true;
    Navigator.of(context).pop();
  }

  void _close() {
    _done = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Establishes a dependency on the current screen size, so a resize (a
    // browser window, an orientation change) rebuilds this and, in turn,
    // re-measures the zones below against the new layout.
    MediaQuery.sizeOf(context);
    scheduleZoneMeasurement([_centerContentKey, _skipButtonKey]);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
          key: stackKey,
          children: [
            // A soft band of light sweeping top-to-bottom behind the
            // starfield, tied to the same [_controller] driving the star
            // glow — rising toward the top as you breathe in, sinking back
            // toward the bottom as you breathe out, so it reads as one more
            // part of the same breath rather than a separate animation.
            // The nearest hand-rolled equivalent to the "gradient wave"
            // `breathing_collection`'s `BreathingBackground` gave the
            // screen before that package was dropped (see the fix for the
            // broken web build) — a moving gradient rather than that
            // widget's own flat color cross-fade.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Reads [_controller.value] straight — it's already
                  // eased at the source (see [_runPhase]'s own curve), so
                  // re-easing an already-eased value here would only
                  // dilute the effect rather than add to it. A plain 0-1
                  // clamp is just a defensive backstop against floating
                  // point drift, not a deliberate inset — the band is
                  // meant to actually reach both true edges.
                  final bandStop = (1.0 - _controller.value).clamp(0.0, 1.0);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.nightlightGradientOuter,
                          colors.nightlightGradientCenter,
                          colors.nightlightGradientOuter,
                        ],
                        stops: [0.0, bandStop, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Kept clear of the running countdown/time/label content and
            // the skip button — see [NightlightZoneMeasuring] — measured
            // off their own actual, current position rather than a fixed
            // guess, so this stays correct across screen sizes.
            Positioned.fill(
              child: NightlightStarfield(exclusionZones: nightlightZones),
            ),
            SafeArea(
              child: Column(
                children: [
                  ResponsiveContent(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _close,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: KeyedSubtree(
                        key: _centerContentKey,
                        // The running content is always in the tree, not
                        // swapped in only once the countdown ends — its own
                        // opacity instead fades it in, once, right after the
                        // countdown actually finishes (see [_introOpacity]/
                        // where [_introOpacityController] is started in
                        // [_run]), rather than popping in abruptly. The
                        // countdown digit sits on top of it meanwhile, in
                        // the same [Stack] slot.
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _controller,
                                _introOpacityController,
                              ]),
                              builder: (context, _) {
                                final remaining =
                                    _totalExerciseDuration -
                                    _exerciseStopwatch.elapsed;
                                return Opacity(
                                  opacity: _introOpacity.value,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Time above, bigger and glowing like
                                      // the countdown digits — the more
                                      // glanceable of the two. The cycle
                                      // count below it is its own line
                                      // rather than sharing one with the
                                      // time, and gets the same glow
                                      // treatment at a smaller scale.
                                      SizedBox(
                                        width: _remainingWidth,
                                        child: Text(
                                          _formatRemaining(remaining),
                                          textAlign: TextAlign.center,
                                          softWrap: false,
                                          style: _remainingStyle.copyWith(
                                            // Kept in case a future font
                                            // swap actually supports it —
                                            // harmless either way, since
                                            // the fixed-width box above is
                                            // what actually stops the
                                            // jitter now (see this state's
                                            // own doc comment on
                                            // [_countdownDigitWidth]).
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                            color: colors.text,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.white,
                                                blurRadius: 16,
                                              ),
                                              Shadow(
                                                color: Colors.white54,
                                                blurRadius: 32,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.nightlightBreathingCycleLabel(
                                          _currentCycle + 1,
                                          _totalCycles,
                                        ),
                                        style: TextStyle(
                                          fontFamily: kFontBranding,
                                          fontSize: 14,
                                          color: colors.text.withValues(
                                            alpha: 0.7,
                                          ),
                                          shadows: const [
                                            Shadow(
                                              color: Colors.white38,
                                              blurRadius: 8,
                                            ),
                                            Shadow(
                                              color: Colors.white24,
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      NightlightStarGlow(
                                        progress: _controller.value,
                                      ),
                                      const SizedBox(height: 28),
                                      // Driven by [_labelController] rather
                                      // than an [AnimatedSwitcher] — see
                                      // [_labelOpacityAt]'s own doc comment
                                      // for the actual fade-in/hold/fade-out/
                                      // gap shape this produces.
                                      AnimatedBuilder(
                                        animation: _labelController,
                                        builder: (context, _) {
                                          return Opacity(
                                            opacity: _labelOpacityAt(
                                              _labelController.value,
                                            ),
                                            child: Text(
                                              _phaseLabel(strings),
                                              style: TextStyle(
                                                fontFamily: kFontBranding,
                                                fontSize: 20,
                                                color: colors.text,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.white,
                                                    blurRadius: 14,
                                                  ),
                                                  Shadow(
                                                    color: Colors.white54,
                                                    blurRadius: 28,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // On top of the (fading-in) running content —
                            // see this widget's own doc comment above.
                            if (_countingDown)
                              SizedBox(
                                width: _countdownDigitWidth,
                                child: Text(
                                  '$_countdown',
                                  textAlign: TextAlign.center,
                                  softWrap: false,
                                  style: _countdownStyle.copyWith(
                                    color: colors.text,
                                    // Same glow as the "Nightlight" title.
                                    shadows: const [
                                      Shadow(
                                        color: Colors.white,
                                        blurRadius: 22,
                                      ),
                                      Shadow(
                                        color: Colors.white54,
                                        blurRadius: 42,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Its slot stays reserved even while hidden (rather than
                  // an `if (_canSkip)` removing it from the tree) — that
                  // would shrink the [Expanded] above by this row's own
                  // height right as the 3rd cycle finishes, visibly
                  // nudging the centered star/label upward at that moment.
                  //
                  // Two separate fade-ins, not one: the button itself
                  // fades in first with no glow at all, and only once
                  // that's done does the glow fade in as its own later
                  // step (see [_showSkipGlow]) — an [AnimatedContainer]
                  // animating the glow's own [BoxDecoration] between no
                  // shadow and the full one, entirely independent of the
                  // button's own opacity/content, which stays fully
                  // visible and interactive throughout.
                  ResponsiveContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                      child: AnimatedOpacity(
                        opacity: _canSkip ? 1 : 0,
                        duration: const Duration(milliseconds: 500),
                        child: IgnorePointer(
                          ignoring: !_canSkip,
                          child: AnimatedContainer(
                            key: _skipButtonKey,
                            duration: const Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(kRadiusPill),
                              boxShadow: _showSkipGlow
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 24,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: TextButton(
                              style: nightlightTextButtonStyle(colors),
                              onPressed: _advanceToAdmire,
                              child: Text(strings.nightlightBreathingSkip),
                            ),
                          ),
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
