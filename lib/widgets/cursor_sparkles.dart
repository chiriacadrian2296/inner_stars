import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Where the arrow cursor's *visual* middle sits relative to its hotspot (the
/// raw pointer position, at the arrow's tip). Shared by the hold ring and the
/// hover sparkles so both read as centered on the cursor on the web, where an
/// OS cursor is actually painted.
const kWebCursorCenterOffset = Offset(4, 7.5);

/// Desktop-only hover flourish: while the mouse is over something tappable,
/// tiny white dots fade in around the cursor and twinkle, then fade out.
///
/// "Tappable" is either [isSkyTarget] (the Galaxy's own stars, constellations
/// and supernovas, which aren't widgets) or any widget under the pointer that
/// asks for the click cursor (every `InkWell`/button). Purely decorative:
/// wrapped in [IgnorePointer], so it never joins hit-testing or the gesture
/// arena. Idle when nothing is hovered — its ticker only runs while dots
/// are being spawned or are still fading.
class CursorSparkles extends StatefulWidget {
  const CursorSparkles({
    super.key,
    required this.isSkyTarget,
    this.centerOffset = Offset.zero,
  });

  /// Whether the given *global* position is over a tappable thing that isn't
  /// a widget (a star/constellation/supernova on the sky).
  final bool Function(Offset globalPosition) isSkyTarget;

  /// Added to the pointer position to find the middle the dots orbit — see
  /// [kWebCursorCenterOffset].
  final Offset centerOffset;

  @override
  State<CursorSparkles> createState() => _CursorSparklesState();
}

class _Sparkle {
  _Sparkle({
    required this.origin,
    required this.angle,
    required this.radius,
    required this.born,
    required this.life,
    required this.size,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.isCross,
  });

  /// Where the cursor's middle was when this dot was born — it stays
  /// there for its whole life rather than following the cursor.
  final Offset origin;
  final double angle;
  final double radius;
  final Duration born;
  final double life;
  final double size;
  final double twinklePhase;
  final double twinkleSpeed;
  final bool isCross;
}

class _CursorSparklesState extends State<CursorSparkles>
    with SingleTickerProviderStateMixin {
  static const _spawnPerSecond = 8.0;
  static const _maxSparkles = 7;
  static const _recheckInterval = Duration(milliseconds: 100);

  final _random = math.Random();
  final _repaint = ValueNotifier<int>(0);
  final _sparkles = <_Sparkle>[];
  late final Ticker _ticker = createTicker(_onTick);

  Offset? _pointer;
  bool _hovering = false;
  Duration _now = Duration.zero;
  Duration? _last;
  Duration _lastCheck = Duration.zero;
  double _spawnDebt = 0;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event is PointerRemovedEvent) {
      _hovering = false;
      return;
    }
    if (event is! PointerHoverEvent && event is! PointerMoveEvent) return;
    _pointer = event.position;
    // A page pushed over the Galaxy hides this overlay anyway — don't spawn
    // dots (or run hit tests) for what's happening on top of it.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    _hovering = onTop && _isTappable(event.position);
    if (_hovering && !_ticker.isActive) {
      // A restarted ticker's clock begins at zero again.
      _lastCheck = Duration.zero;
      _ticker.start();
    }
  }

  bool _isTappable(Offset global) =>
      widget.isSkyTarget(global) || _hasClickRegion(global);

  bool _hasClickRegion(Offset global) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      global,
      View.of(context).viewId,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMouseRegion &&
          target.cursor == SystemMouseCursors.click) {
        return true;
      }
    }
    return false;
  }

  void _onTick(Duration elapsed) {
    final dt = _last == null ? 0.0 : (elapsed - _last!).inMicroseconds / 1e6;
    _last = elapsed;
    _now = elapsed;
    _sparkles.removeWhere(
      (s) => (elapsed - s.born).inMicroseconds / 1e6 >= s.life,
    );
    // The cursor can sit still while what's under it moves away (a hold
    // that flies the camera elsewhere, a menu closing) — no pointer event
    // comes then, so re-check on a timer or the dots would keep spawning
    // over empty sky until the mouse moves again.
    if (_hovering &&
        _pointer != null &&
        elapsed - _lastCheck >= _recheckInterval) {
      _lastCheck = elapsed;
      if (!(ModalRoute.of(context)?.isCurrent ?? true) ||
          !_isTappable(_pointer!)) {
        _hovering = false;
      }
    }
    if (_hovering && _pointer != null) {
      _spawnDebt = math.min(_spawnDebt + dt * _spawnPerSecond, 2);
      while (_spawnDebt >= 1 && _sparkles.length < _maxSparkles) {
        _spawnDebt -= 1;
        _sparkles.add(_spawn(elapsed));
      }
    } else if (_sparkles.isEmpty) {
      _ticker.stop();
      _last = null;
      _spawnDebt = 0;
    }
    _repaint.value++;
  }

  _Sparkle _spawn(Duration now) => _Sparkle(
    origin: _pointer! + widget.centerOffset,
    angle: _random.nextDouble() * 2 * math.pi,
    radius: 16 + _random.nextDouble() * 8,
    born: now,
    life: 0.8 + _random.nextDouble() * 0.7,
    size: 0.6 + _random.nextDouble() * 0.6,
    twinklePhase: _random.nextDouble() * 2 * math.pi,
    twinkleSpeed: 0.8 + _random.nextDouble() * 0.8,
    isCross: _random.nextInt(3) == 0,
  );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _SparklePainter(this, _repaint)),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this._state, Listenable repaint) : super(repaint: repaint);

  final _CursorSparklesState _state;

  @override
  void paint(Canvas canvas, Size size) {
    final pointer = _state._pointer;
    if (pointer == null || _state._sparkles.isEmpty) return;
    final now = _state._now;

    for (final s in _state._sparkles) {
      final age = (now - s.born).inMicroseconds / 1e6;
      final t = (age / s.life).clamp(0.0, 1.0);
      final envelope = math.sin(t * math.pi);
      final twinkle =
          0.8 +
          0.2 * math.sin(age * s.twinkleSpeed * 2 * math.pi + s.twinklePhase);
      final alpha = (envelope * twinkle).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final radius = s.radius * (1 + 0.25 * t);
      final center =
          s.origin + Offset(math.cos(s.angle), math.sin(s.angle)) * radius;
      final dotRadius = s.size * (0.6 + 0.4 * envelope);

      canvas.drawCircle(
        center,
        dotRadius * 3,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        center,
        dotRadius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      if (s.isCross) {
        final arm = s.size * 2.6 * envelope;
        final line = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.9)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          center.translate(-arm, 0),
          center.translate(arm, 0),
          line,
        );
        canvas.drawLine(
          center.translate(0, -arm),
          center.translate(0, arm),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => true;
}
