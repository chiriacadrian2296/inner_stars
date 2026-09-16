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
/// If the user taps "I'm ready" (allowed once the first cycle finishes),
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
    with SingleTickerProviderStateMixin {
  // The actual in/out movement — long, so the wave/glow have room to
  // visibly ease rather than snap through the middle at a steady rate.
  static const _breathDuration = Duration(seconds: 6);
  // The pause at each extreme — brief on purpose. An earlier pass gave
  // this the same length as the movement itself, which read as "nothing
  // happening" for half of every cycle; this should feel like a held
  // breath, not a stop.
  static const _holdDuration = Duration(milliseconds: 700);
  // 10 × (6+0.7+6+0.7)s ≈ 2 minutes — long enough to be worth a cycle
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
  static const _breathDurationMs = 6000;
  static const _holdDurationMs = 700;

  late final AnimationController _controller = AnimationController(vsync: this);
  final Stopwatch _exerciseStopwatch = Stopwatch();

  int _countdown = 3;
  bool _countingDown = true;
  _BreathPhase _phase = _BreathPhase.inhale;
  int _currentCycle = 0;
  bool _canSkip = false;
  bool _showSkipGlow = false;

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
    super.dispose();
  }

  Future<void> _run() async {
    // The wave/glow both read [_controller.value] straight, and it starts
    // at its default 0 — left alone, the countdown would sit through a
    // fully dark composition (the wave's darkest color pinned across
    // almost the whole screen) for its entire 3 seconds, reading as an
    // unintended scrim over everything but the countdown digit itself.
    // Settling to a balanced middle value over that same span instead
    // means everything else fades back in gradually, rather than sitting
    // dark then snapping bright the moment breathing starts.
    unawaited(
      _controller.animateTo(
        0.5,
        duration: const Duration(seconds: _countdownStart),
        curve: Curves.easeOut,
      ),
    );
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

    for (var cycle = 0; cycle < _totalCycles; cycle++) {
      if (_done) return;
      setState(() => _currentCycle = cycle);
      await _runPhase(_BreathPhase.inhale, 0, 1);
      if (_done) return;
      await _runPhase(_BreathPhase.holdFull, 1, 1);
      if (_done) return;
      await _runPhase(_BreathPhase.exhale, 1, 0);
      if (_done) return;
      await _runPhase(_BreathPhase.holdEmpty, 0, 0);
      if (cycle == 0 && !_done) {
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
    // No explicit `_controller.value = from` here — [_controller] is
    // already sitting at `from` by the time this runs (either the previous
    // phase ended there, or, for the very first inhale, the countdown's
    // own settle-to-0.5 animation left it there). Forcing it would snap
    // that value backwards instead of letting this phase continue smoothly
    // from wherever the controller actually is.
    await _controller.animateTo(
      to,
      duration: from == to ? _holdDuration : _breathDuration,
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

  String _phaseLabel(AppStrings strings) {
    switch (_phase) {
      case _BreathPhase.inhale:
        return strings.nightlightBreathingInhale;
      case _BreathPhase.holdFull:
      case _BreathPhase.holdEmpty:
        return strings.nightlightBreathingHold;
      case _BreathPhase.exhale:
        return strings.nightlightBreathingExhale;
    }
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
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
            const Positioned.fill(child: NightlightStarfield()),
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
                      child: _countingDown
                          ? Text(
                              '$_countdown',
                              style: TextStyle(
                                fontFamily: kFontBranding,
                                fontSize: 72,
                                color: colors.text,
                                // Same glow as the "Nightlight" title.
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 22),
                                  Shadow(color: Colors.white54, blurRadius: 42),
                                ],
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final remaining =
                                    _totalExerciseDuration -
                                    _exerciseStopwatch.elapsed;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Time above, bigger and glowing like
                                    // the countdown digits — the more
                                    // glanceable of the two. The cycle
                                    // count below it is its own line
                                    // rather than sharing one with the
                                    // time, and gets the same glow
                                    // treatment at a smaller scale.
                                    Text(
                                      _formatRemaining(remaining),
                                      style: TextStyle(
                                        fontFamily: kFontBranding,
                                        fontSize: 32,
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
                                    // The outgoing label fades fully out
                                    // before the incoming one fades in —
                                    // not a crossfade — by giving each an
                                    // [Interval] of the *same* shared
                                    // duration instead of letting both
                                    // halves run the whole span at once
                                    // (the default, which overlaps them).
                                    // The [ValueKey] is what tells
                                    // [AnimatedSwitcher] a *new* child
                                    // arrived (only true when [_phase]
                                    // itself changes, not on every one of
                                    // this [AnimatedBuilder]'s own frames).
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      switchOutCurve: const Interval(
                                        0.0,
                                        0.5,
                                        curve: Curves.easeOut,
                                      ),
                                      switchInCurve: const Interval(
                                        0.5,
                                        1.0,
                                        curve: Curves.easeIn,
                                      ),
                                      child: Text(
                                        _phaseLabel(strings),
                                        key: ValueKey(_phase),
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
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                  // Its slot stays reserved even while hidden (rather than
                  // an `if (_canSkip)` removing it from the tree) — that
                  // would shrink the [Expanded] above by this row's own
                  // height right as the first cycle finishes, visibly
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
