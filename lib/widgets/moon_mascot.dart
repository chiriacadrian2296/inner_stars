import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Persistent moods that Moon can smoothly transition between.
enum MoonExpression { neutral, happy, sleepy, curious, concerned, surprised }

/// Short, app-triggered motions that return Moon to her current expression.
enum MoonReaction { acknowledge, celebrate }

/// Color treatments for the same Moon design and motion system.
enum MoonPalette { original, app, gold }

/// Optional layer controls used by the Moon visual lab.
@immutable
class MoonAppearance {
  const MoonAppearance({
    this.showEyeStars = true,
    this.showEyeAccent = true,
    this.showOuterGlow = true,
    this.showBlush = true,
    this.showMouth = true,
    this.showBrows = true,
    this.showForeheadShine = true,
    this.showRim = true,
    this.useBodyGradient = true,
    this.bodyHue = 211,
    this.rimHue = 198,
    this.glowHue = 194,
    this.faceHue = 224,
    this.starHue = 194,
    this.eyeAccentHue = 192,
    this.blushHue = 252,
    this.shineHue = 190,
  });

  final bool showEyeStars;
  final bool showEyeAccent;
  final bool showOuterGlow;
  final bool showBlush;
  final bool showMouth;
  final bool showBrows;
  final bool showForeheadShine;
  final bool showRim;
  final bool useBodyGradient;
  final double bodyHue;
  final double rimHue;
  final double glowHue;
  final double faceHue;
  final double starHue;
  final double eyeAccentHue;
  final double blushHue;
  final double shineHue;

  MoonAppearance copyWith({
    bool? showEyeStars,
    bool? showEyeAccent,
    bool? showOuterGlow,
    bool? showBlush,
    bool? showMouth,
    bool? showBrows,
    bool? showForeheadShine,
    bool? showRim,
    bool? useBodyGradient,
    double? bodyHue,
    double? rimHue,
    double? glowHue,
    double? faceHue,
    double? starHue,
    double? eyeAccentHue,
    double? blushHue,
    double? shineHue,
  }) => MoonAppearance(
    showEyeStars: showEyeStars ?? this.showEyeStars,
    showEyeAccent: showEyeAccent ?? this.showEyeAccent,
    showOuterGlow: showOuterGlow ?? this.showOuterGlow,
    showBlush: showBlush ?? this.showBlush,
    showMouth: showMouth ?? this.showMouth,
    showBrows: showBrows ?? this.showBrows,
    showForeheadShine: showForeheadShine ?? this.showForeheadShine,
    showRim: showRim ?? this.showRim,
    useBodyGradient: useBodyGradient ?? this.useBodyGradient,
    bodyHue: bodyHue ?? this.bodyHue,
    rimHue: rimHue ?? this.rimHue,
    glowHue: glowHue ?? this.glowHue,
    faceHue: faceHue ?? this.faceHue,
    starHue: starHue ?? this.starHue,
    eyeAccentHue: eyeAccentHue ?? this.eyeAccentHue,
    blushHue: blushHue ?? this.blushHue,
    shineHue: shineHue ?? this.shineHue,
  );
}

/// Imperative access to the one-shot reactions of a mounted [MoonMascot].
class MoonMascotController {
  _MoonMascotState? _state;

  bool get isAttached => _state != null;

  /// Plays [reaction]. Detached and reduced-motion controllers are safe no-ops.
  Future<void> play(MoonReaction reaction) =>
      _state?._playReaction(reaction) ?? Future<void>.value();

  void _attach(_MoonMascotState state) {
    assert(
      _state == null || identical(_state, state),
      'A MoonMascotController can only control one MoonMascot at a time.',
    );
    _state = state;
  }

  void _detach(_MoonMascotState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// Flutter-native Moon: an SVG body with an independently animated face.
class MoonMascot extends StatefulWidget {
  const MoonMascot({
    super.key,
    this.expression = MoonExpression.neutral,
    this.size = 180,
    this.animate = true,
    this.controller,
    this.palette = MoonPalette.original,
    this.appearance,
    this.semanticLabel = 'Moon',
  }) : assert(size > 0);

  final MoonExpression expression;
  final double size;
  final bool animate;
  final MoonMascotController? controller;
  final MoonPalette palette;
  final MoonAppearance? appearance;
  final String semanticLabel;

  @override
  State<MoonMascot> createState() => _MoonMascotState();
}

enum _MicroBehavior { glance, contented }

class _MoonMascotState extends State<MoonMascot>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _originalBodyAsset = 'assets/mascots/moon_body.svg';
  static const _appBodyAsset = 'assets/mascots/moon_body_app.svg';
  static const _goldBodyAsset = 'assets/mascots/moon_body_gold.svg';

  late final AnimationController _blinkController;
  late final AnimationController _idleController;
  late final AnimationController _expressionController;
  late final AnimationController _microController;
  late final AnimationController _reactionController;
  final _random = math.Random();

  Timer? _blinkTimer;
  Timer? _glanceTimer;
  Timer? _contentedTimer;
  bool _motionActive = false;
  bool _appActive = true;
  int _glanceDirection = 1;
  _MicroBehavior? _microBehavior;
  MoonReaction? _reaction;
  Completer<void>? _reactionCompleter;
  late _FacePose _fromPose;
  late _FacePose _toPose;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _expressionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    )..addStatusListener(_handleExpressionStatus);
    _microController = AnimationController(vsync: this)
      ..addStatusListener(_handleMicroStatus);
    _reactionController = AnimationController(vsync: this)
      ..addStatusListener(_handleReactionStatus);
    _fromPose = _FacePose.forExpression(widget.expression);
    _toPose = _fromPose;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant MoonMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.expression != widget.expression) {
      _fromPose = _currentPose;
      _toPose = _FacePose.forExpression(widget.expression);
      _suspendAmbient();
      if (_motionActive) {
        _expressionController.forward(from: 0);
      } else {
        _expressionController.value = 1;
      }
    }
    if (oldWidget.animate != widget.animate) _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  _FacePose get _currentPose => _FacePose.lerp(
    _fromPose,
    _toPose,
    Curves.easeInOutCubic.transform(
      _expressionController.value.clamp(0.0, 1.0),
    ),
  );

  bool get _ambientAvailable =>
      _motionActive && _reaction == null && !_expressionController.isAnimating;

  void _syncMotion() {
    final media = MediaQuery.maybeOf(context);
    final shouldAnimate =
        widget.animate &&
        !(media?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled &&
        _appActive;
    if (shouldAnimate == _motionActive) return;
    _motionActive = shouldAnimate;
    if (shouldAnimate) {
      _idleController.repeat();
      _scheduleAmbient();
    } else {
      _suspendAmbient();
      _interruptReaction();
      _idleController
        ..stop()
        ..value = 0;
      _expressionController.value = 1;
    }
  }

  void _scheduleAmbient() {
    if (!_ambientAvailable) return;
    _scheduleBlink();
    _scheduleGlance();
    _scheduleContented();
  }

  void _suspendAmbient() {
    _blinkTimer?.cancel();
    _glanceTimer?.cancel();
    _contentedTimer?.cancel();
    _blinkTimer = null;
    _glanceTimer = null;
    _contentedTimer = null;
    _blinkController
      ..stop()
      ..value = 0;
    _microController
      ..stop()
      ..value = 0;
    _microBehavior = null;
  }

  void _scheduleBlink({Duration? delay}) {
    _blinkTimer?.cancel();
    if (!_ambientAvailable) return;
    final milliseconds = delay?.inMilliseconds ?? 2500 + _random.nextInt(2501);
    _blinkTimer = Timer(Duration(milliseconds: milliseconds), _runBlink);
  }

  Future<void> _runBlink() async {
    if (!mounted || !_ambientAvailable) return;
    if (_microBehavior == _MicroBehavior.contented) {
      _scheduleBlink(delay: const Duration(milliseconds: 800));
      return;
    }
    await _blinkController.forward(from: 0);
    if (!mounted || !_ambientAvailable) return;
    if (_random.nextDouble() < 0.12) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted || !_ambientAvailable) return;
      await _blinkController.forward(from: 0);
      if (!mounted || !_ambientAvailable) return;
    }
    _scheduleBlink();
  }

  void _scheduleGlance({Duration? delay}) {
    _glanceTimer?.cancel();
    if (!_ambientAvailable) return;
    final milliseconds = delay?.inMilliseconds ?? 7000 + _random.nextInt(5001);
    _glanceTimer = Timer(Duration(milliseconds: milliseconds), _runGlance);
  }

  void _runGlance() {
    if (!_ambientAvailable || _microBehavior != null) {
      _scheduleGlance(delay: const Duration(seconds: 2));
      return;
    }
    _glanceDirection = _random.nextBool() ? 1 : -1;
    _microBehavior = _MicroBehavior.glance;
    _microController.duration = const Duration(milliseconds: 820);
    _microController.forward(from: 0);
  }

  void _scheduleContented({Duration? delay}) {
    _contentedTimer?.cancel();
    if (!_ambientAvailable) return;
    final milliseconds =
        delay?.inMilliseconds ?? 14000 + _random.nextInt(10001);
    _contentedTimer = Timer(
      Duration(milliseconds: milliseconds),
      _runContented,
    );
  }

  void _runContented() {
    if (!_ambientAvailable || _microBehavior != null) {
      _scheduleContented(delay: const Duration(seconds: 3));
      return;
    }
    _microBehavior = _MicroBehavior.contented;
    _microController.duration = const Duration(milliseconds: 940);
    _microController.forward(from: 0);
  }

  void _handleExpressionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scheduleAmbient();
  }

  void _handleMicroStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final finished = _microBehavior;
    setState(() => _microBehavior = null);
    switch (finished) {
      case _MicroBehavior.glance:
        _scheduleGlance();
      case _MicroBehavior.contented:
        _scheduleContented();
      case null:
        break;
    }
  }

  Future<void> _playReaction(MoonReaction reaction) {
    _interruptReaction();
    if (!_motionActive) return Future<void>.value();
    _suspendAmbient();
    final completer = Completer<void>();
    _reactionCompleter = completer;
    setState(() => _reaction = reaction);
    _reactionController.duration = switch (reaction) {
      MoonReaction.acknowledge => const Duration(milliseconds: 520),
      MoonReaction.celebrate => const Duration(milliseconds: 900),
    };
    _reactionController.forward(from: 0);
    return completer.future;
  }

  void _handleReactionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _reaction = null);
    final completer = _reactionCompleter;
    _reactionCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    _scheduleAmbient();
  }

  void _interruptReaction() {
    _reactionController
      ..stop()
      ..value = 0;
    _reaction = null;
    final completer = _reactionCompleter;
    _reactionCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  double get _blinkOpenness {
    final t = _blinkController.value;
    if (t <= 0) return 1;
    if (t < 0.42) {
      final closingProgress = (t / 0.42).clamp(0.0, 1.0);
      return 1 - Curves.easeInCubic.transform(closingProgress);
    }
    if (t <= 0.58) return 0;
    final openingProgress = ((t - 0.58) / 0.42).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(openingProgress);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _blinkController,
            _idleController,
            _expressionController,
            _microController,
            _reactionController,
          ]),
          builder: (context, child) {
            final idlePhase = _idleController.value * math.pi * 2;
            final idleBob = _motionActive
                ? math.sin(idlePhase) * widget.size * 0.009
                : 0.0;
            final idleBreath = _motionActive
                ? 1 + math.sin(idlePhase - math.pi / 2) * 0.006
                : 1.0;
            final microWave = math.sin(_microController.value * math.pi);
            final eyeOffset = _microBehavior == _MicroBehavior.glance
                ? _glanceDirection * 18.0 * microWave
                : 0.0;
            final contentedEyeFactor =
                _microBehavior == _MicroBehavior.contented
                ? 1 - 0.78 * microWave
                : 1.0;
            final contentedSmileBoost =
                _microBehavior == _MicroBehavior.contented
                ? 12.0 * microWave
                : 0.0;

            final reactionT = _reactionController.value.clamp(0.0, 1.0);
            var reactionY = 0.0;
            var reactionRotation = 0.0;
            var scaleX = idleBreath;
            var scaleY = idleBreath;
            var glowBoost = 0.0;
            var celebrationProgress = 0.0;
            switch (_reaction) {
              case MoonReaction.acknowledge:
                final nod = math.sin(reactionT * math.pi);
                reactionY = widget.size * 0.024 * nod;
                reactionRotation = math.sin(reactionT * math.pi * 2) * 0.012;
                scaleX *= 1 + 0.007 * nod;
                scaleY *= 1 - 0.017 * nod;
              case MoonReaction.celebrate:
                final bounce = math.sin(reactionT * math.pi * 2).abs();
                reactionY = -widget.size * 0.045 * bounce;
                scaleX *= 1 - 0.009 * bounce;
                scaleY *= 1 + 0.019 * bounce;
                glowBoost = 0.20 * math.sin(reactionT * math.pi);
                celebrationProgress = reactionT;
              case null:
                break;
            }

            final glow =
                (0.18 +
                        (_motionActive ? math.sin(idlePhase) * 0.035 : 0) +
                        glowBoost)
                    .clamp(0.0, 1.0);
            final glowColor = widget.appearance != null
                ? _withHue(const Color(0xFF55D9FF), widget.appearance!.glowHue)
                : switch (widget.palette) {
                    MoonPalette.original => const Color(0xFF55D9FF),
                    MoonPalette.app ||
                    MoonPalette.gold => const Color(0xFFF2B84B),
                  };
            return Transform.translate(
              offset: Offset(0, idleBob + reactionY),
              child: Transform.rotate(
                angle: reactionRotation,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: widget.appearance?.showOuterGlow ?? true
                            ? [
                                BoxShadow(
                                  color: glowColor.withValues(
                                    alpha:
                                        widget.appearance == null &&
                                            widget.palette == MoonPalette.app
                                        ? glow * 0.56
                                        : glow,
                                  ),
                                  blurRadius: widget.size * 0.105,
                                  spreadRadius: widget.size * 0.012,
                                ),
                              ]
                            : const [],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.appearance case final appearance?)
                            CustomPaint(painter: _MoonBodyPainter(appearance))
                          else
                            SvgPicture.asset(
                              switch (widget.palette) {
                                MoonPalette.original => _originalBodyAsset,
                                MoonPalette.app => _appBodyAsset,
                                MoonPalette.gold => _goldBodyAsset,
                              },
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          CustomPaint(
                            painter: _MoonFacePainter(
                              pose: _currentPose,
                              blinkOpenness:
                                  _blinkOpenness * contentedEyeFactor,
                              ambientEyeOffset: eyeOffset,
                              smileBoost: contentedSmileBoost,
                              celebrationProgress: celebrationProgress,
                              palette: widget.palette,
                              appearance: widget.appearance,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(this);
    _blinkTimer?.cancel();
    _glanceTimer?.cancel();
    _contentedTimer?.cancel();
    if (!(_reactionCompleter?.isCompleted ?? true)) {
      _reactionCompleter?.complete();
    }
    _expressionController.removeStatusListener(_handleExpressionStatus);
    _microController.removeStatusListener(_handleMicroStatus);
    _reactionController.removeStatusListener(_handleReactionStatus);
    _blinkController.dispose();
    _idleController.dispose();
    _expressionController.dispose();
    _microController.dispose();
    _reactionController.dispose();
    super.dispose();
  }
}

@immutable
class _FacePose {
  const _FacePose({
    required this.eyeOpen,
    required this.eyeOffsetX,
    required this.leftBrowLift,
    required this.rightBrowLift,
    required this.leftBrowTilt,
    required this.rightBrowTilt,
    required this.smileDepth,
    required this.mouthWidth,
    required this.mouthOpen,
    required this.blushOpacity,
  });

  factory _FacePose.forExpression(MoonExpression expression) =>
      switch (expression) {
        MoonExpression.neutral => const _FacePose(
          eyeOpen: 1,
          eyeOffsetX: 0,
          leftBrowLift: 0,
          rightBrowLift: 0,
          leftBrowTilt: 0,
          rightBrowTilt: 0,
          smileDepth: 55,
          mouthWidth: 120,
          mouthOpen: 0,
          blushOpacity: 0.30,
        ),
        MoonExpression.happy => const _FacePose(
          eyeOpen: 0.82,
          eyeOffsetX: 0,
          leftBrowLift: 12,
          rightBrowLift: 12,
          leftBrowTilt: 5,
          rightBrowTilt: 5,
          smileDepth: 82,
          mouthWidth: 142,
          mouthOpen: 0,
          blushOpacity: 0.47,
        ),
        MoonExpression.sleepy => const _FacePose(
          eyeOpen: 0.20,
          eyeOffsetX: 0,
          leftBrowLift: -4,
          rightBrowLift: -4,
          leftBrowTilt: -7,
          rightBrowTilt: -7,
          smileDepth: 31,
          mouthWidth: 100,
          mouthOpen: 0,
          blushOpacity: 0.18,
        ),
        MoonExpression.curious => const _FacePose(
          eyeOpen: 0.94,
          eyeOffsetX: 12,
          leftBrowLift: 18,
          rightBrowLift: 4,
          leftBrowTilt: 7,
          rightBrowTilt: -2,
          smileDepth: 43,
          mouthWidth: 108,
          mouthOpen: 0,
          blushOpacity: 0.27,
        ),
        MoonExpression.concerned => const _FacePose(
          eyeOpen: 0.76,
          eyeOffsetX: 0,
          leftBrowLift: 7,
          rightBrowLift: 7,
          leftBrowTilt: 11,
          rightBrowTilt: 11,
          smileDepth: -20,
          mouthWidth: 104,
          mouthOpen: 0,
          blushOpacity: 0.16,
        ),
        MoonExpression.surprised => const _FacePose(
          eyeOpen: 1.10,
          eyeOffsetX: 0,
          leftBrowLift: 28,
          rightBrowLift: 28,
          leftBrowTilt: 0,
          rightBrowTilt: 0,
          smileDepth: 0,
          mouthWidth: 58,
          mouthOpen: 1,
          blushOpacity: 0.24,
        ),
      };

  final double eyeOpen;
  final double eyeOffsetX;
  final double leftBrowLift;
  final double rightBrowLift;
  final double leftBrowTilt;
  final double rightBrowTilt;
  final double smileDepth;
  final double mouthWidth;
  final double mouthOpen;
  final double blushOpacity;

  static _FacePose lerp(_FacePose a, _FacePose b, double t) => _FacePose(
    eyeOpen: _lerp(a.eyeOpen, b.eyeOpen, t),
    eyeOffsetX: _lerp(a.eyeOffsetX, b.eyeOffsetX, t),
    leftBrowLift: _lerp(a.leftBrowLift, b.leftBrowLift, t),
    rightBrowLift: _lerp(a.rightBrowLift, b.rightBrowLift, t),
    leftBrowTilt: _lerp(a.leftBrowTilt, b.leftBrowTilt, t),
    rightBrowTilt: _lerp(a.rightBrowTilt, b.rightBrowTilt, t),
    smileDepth: _lerp(a.smileDepth, b.smileDepth, t),
    mouthWidth: _lerp(a.mouthWidth, b.mouthWidth, t),
    mouthOpen: _lerp(a.mouthOpen, b.mouthOpen, t),
    blushOpacity: _lerp(a.blushOpacity, b.blushOpacity, t),
  );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

Color _withHue(Color color, double hue) =>
    HSLColor.fromColor(color).withHue(hue.clamp(0.0, 360.0)).toColor();

class _MoonBodyPainter extends CustomPainter {
  const _MoonBodyPainter(this.appearance);

  final MoonAppearance appearance;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 1024;
    canvas.save();
    canvas.scale(scale, scale);

    if (appearance.showRim) {
      final rimRect = const Rect.fromLTWH(88, 88, 848, 848);
      canvas.drawCircle(
        const Offset(512, 512),
        424,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _withHue(const Color(0xFFC9FAFF), appearance.rimHue),
              _withHue(const Color(0xFF51CFFF), appearance.rimHue),
              _withHue(const Color(0xFF386FE2), appearance.rimHue),
              _withHue(const Color(0xFF162F73), appearance.rimHue),
            ],
            stops: const [0, 0.38, 0.75, 1],
          ).createShader(rimRect),
      );
    }

    final bodyRect = const Rect.fromLTWH(101, 101, 822, 822);
    final bodyPaint = Paint();
    if (appearance.useBodyGradient) {
      bodyPaint.shader = RadialGradient(
        center: const Alignment(-0.06, -0.22),
        radius: 0.72,
        colors: [
          _withHue(const Color(0xFFE9FEFF), appearance.bodyHue),
          _withHue(const Color(0xFF9DEEFF), appearance.bodyHue),
          _withHue(const Color(0xFF4B9EF4), appearance.bodyHue),
          _withHue(const Color(0xFF2860CF), appearance.bodyHue),
          _withHue(const Color(0xFF173982), appearance.bodyHue),
        ],
        stops: const [0, 0.30, 0.62, 0.84, 1],
      ).createShader(bodyRect);
    } else {
      bodyPaint.color = _withHue(const Color(0xFF4B9EF4), appearance.bodyHue);
    }
    canvas.drawCircle(const Offset(512, 512), 411, bodyPaint);

    if (appearance.showForeheadShine) {
      const center = Offset(649, 231);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(19 * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
      final shineRect = Rect.fromCenter(
        center: center,
        width: 302,
        height: 150,
      );
      canvas.drawOval(
        shineRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _withHue(
                const Color(0xFFFFFFFF),
                appearance.shineHue,
              ).withValues(alpha: 0.78),
              _withHue(
                const Color(0xFFC4F9FF),
                appearance.shineHue,
              ).withValues(alpha: 0),
            ],
          ).createShader(shineRect),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonBodyPainter oldDelegate) =>
      oldDelegate.appearance != appearance;
}

class _MoonFacePainter extends CustomPainter {
  const _MoonFacePainter({
    required this.pose,
    required this.blinkOpenness,
    required this.ambientEyeOffset,
    required this.smileBoost,
    required this.celebrationProgress,
    required this.palette,
    required this.appearance,
  });

  final _FacePose pose;
  final double blinkOpenness;
  final double ambientEyeOffset;
  final double smileBoost;
  final double celebrationProgress;
  final MoonPalette palette;
  final MoonAppearance? appearance;

  Color get _lineColor => appearance != null
      ? _withHue(const Color(0xFF173477), appearance!.faceHue)
      : palette == MoonPalette.app
      ? const Color(0xFF0D1220)
      : const Color(0xFF173477);
  Color get _eyeDark => appearance != null
      ? _withHue(const Color(0xFF07194E), appearance!.faceHue)
      : palette == MoonPalette.app
      ? const Color(0xFF0D1220)
      : const Color(0xFF07194E);
  Color get _eyeLight => appearance != null
      ? _withHue(const Color(0xFF253F92), appearance!.faceHue)
      : palette == MoonPalette.app
      ? const Color(0xFF232C44)
      : const Color(0xFF253F92);
  Color get _eyeAccent => appearance != null
      ? _withHue(const Color(0xFF28CFFF), appearance!.eyeAccentHue)
      : palette == MoonPalette.app
      ? const Color(0xFF6E8CD8)
      : const Color(0xFF28CFFF);
  Color get _starColor => appearance != null
      ? _withHue(const Color(0xFFE9FEFF), appearance!.starHue)
      : palette == MoonPalette.app
      ? const Color(0xFFF2B84B)
      : Colors.white;
  Color get _blushColor => appearance != null
      ? _withHue(const Color(0xFF9C87F4), appearance!.blushHue)
      : palette == MoonPalette.app
      ? const Color(0xFFF2B84B)
      : const Color(0xFF9C87F4);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 1024;
    canvas.save();
    canvas.scale(scale, scale);
    if (appearance?.showBlush ?? true) _paintBlush(canvas);
    if (appearance?.showBrows ?? true) _paintBrows(canvas);
    _paintEye(canvas, const Offset(382, 514));
    _paintEye(canvas, const Offset(642, 514));
    if (appearance?.showMouth ?? true) _paintMouth(canvas);
    _paintCelebration(canvas);
    canvas.restore();
  }

  void _paintBlush(Canvas canvas) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _blushColor.withValues(alpha: pose.blushOpacity),
          _blushColor.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(251, 548, 164, 106))
      ..color = Colors.white;
    canvas.drawOval(const Rect.fromLTWH(251, 548, 164, 106), paint);
    paint.shader = RadialGradient(
      colors: [
        _blushColor.withValues(alpha: pose.blushOpacity),
        _blushColor.withValues(alpha: 0),
      ],
    ).createShader(const Rect.fromLTWH(609, 548, 164, 106));
    canvas.drawOval(const Rect.fromLTWH(609, 548, 164, 106), paint);
  }

  void _paintBrows(Canvas canvas) {
    final paint = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final left = Path()
      ..moveTo(327, 420 - pose.leftBrowLift + pose.leftBrowTilt)
      ..quadraticBezierTo(
        373,
        381 - pose.leftBrowLift,
        426,
        395 - pose.leftBrowLift - pose.leftBrowTilt,
      );
    final right = Path()
      ..moveTo(598, 395 - pose.rightBrowLift - pose.rightBrowTilt)
      ..quadraticBezierTo(
        651,
        381 - pose.rightBrowLift,
        697,
        420 - pose.rightBrowLift + pose.rightBrowTilt,
      );
    canvas
      ..drawPath(left, paint)
      ..drawPath(right, paint);
  }

  void _paintEye(Canvas canvas, Offset baseCenter) {
    final center = baseCenter.translate(pose.eyeOffsetX + ambientEyeOffset, 0);
    final openness = (pose.eyeOpen * blinkOpenness).clamp(0.0, 1.15);
    if (openness < 0.09) {
      final lid = Path()
        ..moveTo(center.dx - 48, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy + 14,
          center.dx + 48,
          center.dy,
        );
      canvas.drawPath(
        lid,
        Paint()
          ..color = _lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final eyeRect = Rect.fromCenter(
      center: center,
      width: 114,
      height: 144 * openness,
    );
    final eyePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_eyeLight, _eyeDark],
      ).createShader(eyeRect);
    canvas.drawOval(eyeRect, eyePaint);
    final detailOpacity = ((openness - 0.20) / 0.80).clamp(0.0, 1.0);
    if (detailOpacity <= 0) return;
    if (appearance?.showEyeAccent ?? true) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx - 15, center.dy + 45 * openness),
          width: 28,
          height: 18 * math.min(openness, 1),
        ),
        Paint()..color = _eyeAccent.withValues(alpha: 0.88 * detailOpacity),
      );
    }
    if (appearance?.showEyeStars ?? true) {
      canvas.drawPath(
        _starPath(Offset(center.dx, center.dy - 30 * openness), 30, 10),
        Paint()..color = _starColor.withValues(alpha: detailOpacity),
      );
    }
  }

  void _paintMouth(Canvas canvas) {
    final mouthOpen = pose.mouthOpen.clamp(0.0, 1.0);
    final curveOpacity = 1 - mouthOpen;
    if (curveOpacity > 0) {
      final halfWidth = pose.mouthWidth / 2;
      final path = Path()
        ..moveTo(512 - halfWidth, 607)
        ..quadraticBezierTo(
          512,
          607 + pose.smileDepth + smileBoost,
          512 + halfWidth,
          607,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = _lineColor.withValues(alpha: curveOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 19
          ..strokeCap = StrokeCap.round,
      );
    }
    if (mouthOpen > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(512, 625),
          width: 45 + pose.mouthWidth * 0.18,
          height: 54,
        ),
        Paint()..color = _lineColor.withValues(alpha: mouthOpen),
      );
    }
  }

  void _paintCelebration(Canvas canvas) {
    if (!(appearance?.showEyeStars ?? true) ||
        celebrationProgress <= 0 ||
        celebrationProgress >= 1) {
      return;
    }
    final envelope = math.sin(celebrationProgress * math.pi);
    final pulse =
        0.72 + 0.28 * math.sin(celebrationProgress * math.pi * 4).abs();
    final paint = Paint()
      ..color = _starColor.withValues(alpha: envelope * 0.90);
    canvas.save();
    canvas.translate(177, 310);
    canvas.scale(envelope * pulse);
    canvas.drawPath(_starPath(Offset.zero, 38, 13), paint);
    canvas.restore();
    canvas.save();
    canvas.translate(847, 350);
    canvas.scale(envelope * (1.08 - 0.18 * pulse));
    canvas.drawPath(_starPath(Offset.zero, 31, 10), paint);
    canvas.restore();
  }

  Path _starPath(Offset center, double outer, double inner) => Path()
    ..moveTo(center.dx, center.dy - outer)
    ..cubicTo(
      center.dx + inner * 0.45,
      center.dy - inner * 0.45,
      center.dx + inner * 0.45,
      center.dy - inner * 0.45,
      center.dx + outer,
      center.dy,
    )
    ..cubicTo(
      center.dx + inner * 0.45,
      center.dy + inner * 0.45,
      center.dx + inner * 0.45,
      center.dy + inner * 0.45,
      center.dx,
      center.dy + outer,
    )
    ..cubicTo(
      center.dx - inner * 0.45,
      center.dy + inner * 0.45,
      center.dx - inner * 0.45,
      center.dy + inner * 0.45,
      center.dx - outer,
      center.dy,
    )
    ..cubicTo(
      center.dx - inner * 0.45,
      center.dy - inner * 0.45,
      center.dx - inner * 0.45,
      center.dy - inner * 0.45,
      center.dx,
      center.dy - outer,
    )
    ..close();

  @override
  bool shouldRepaint(covariant _MoonFacePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.blinkOpenness != blinkOpenness ||
      oldDelegate.ambientEyeOffset != ambientEyeOffset ||
      oldDelegate.smileBoost != smileBoost ||
      oldDelegate.celebrationProgress != celebrationProgress ||
      oldDelegate.palette != palette ||
      oldDelegate.appearance != appearance;
}
