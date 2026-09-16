import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../widgets/nightlight_star_glow.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import 'admire_stars_screen.dart';

enum _BreathPhase { inhale, holdFull, exhale, holdEmpty }

/// The last screen of the Nightlight "in crisis" path, reached from
/// [NightlightExplainedScreen] — a fixed box-breathing rhythm (4s in, 4s
/// hold, 4s out, 4s hold), [_totalCycles] times, with a short countdown
/// first. [NightlightStarGlow] is the thing that actually grows/shrinks
/// with the breath, driven by [_controller]'s own 0-1 value, rather than a
/// plain circle. Once the cycles finish (or the user skips ahead, allowed
/// only after the first full cycle — cutting it short before the mind's
/// even had one full breath would defeat the point), it replaces itself
/// with [AdmireStarsScreen].
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
  static const _phaseDuration = Duration(seconds: 4);
  static const _totalCycles = 4;

  late final AnimationController _controller = AnimationController(vsync: this);

  int _countdown = 3;
  bool _countingDown = true;
  _BreathPhase _phase = _BreathPhase.inhale;
  bool _canSkip = false;

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
    for (var i = 3; i > 0; i--) {
      if (_done) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (_done) return;
    setState(() => _countingDown = false);

    for (var cycle = 0; cycle < _totalCycles; cycle++) {
      if (_done) return;
      await _runPhase(_BreathPhase.inhale, 0, 1);
      if (_done) return;
      await _runPhase(_BreathPhase.holdFull, 1, 1);
      if (_done) return;
      await _runPhase(_BreathPhase.exhale, 1, 0);
      if (_done) return;
      await _runPhase(_BreathPhase.holdEmpty, 0, 0);
      if (cycle == 0 && !_done) setState(() => _canSkip = true);
    }
    if (!_done) _advanceToAdmire();
  }

  Future<void> _runPhase(_BreathPhase phase, double from, double to) async {
    setState(() => _phase = phase);
    _controller.value = from;
    await _controller.animateTo(
      to,
      duration: _phaseDuration,
      curve: Curves.easeInOut,
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
            // A subtle color wash behind the starfield, tied to the same
            // [_controller] driving the star glow — brightest at the peak
            // of an inhale, darkest at the bottom of an exhale, so it reads
            // as part of the same breath rather than a separate animation.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        colors.nightlightGradientMid,
                        colors.nightlightGradientCenter,
                        _controller.value,
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
                          icon: Icon(
                            Icons.arrow_back,
                            color: colors.nightlightMuted,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _close,
                          icon: Icon(
                            Icons.close,
                            color: colors.nightlightMuted,
                          ),
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
                                fontFamily: kFontMono,
                                fontSize: 72,
                                color: colors.text,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    NightlightStarGlow(
                                      progress: _controller.value,
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      _phaseLabel(strings),
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: colors.text,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                  if (_canSkip)
                    ResponsiveContent(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                        child: TextButton(
                          onPressed: _advanceToAdmire,
                          child: Text(strings.nightlightBreathingSkip),
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
