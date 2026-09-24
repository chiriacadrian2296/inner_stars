import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'staggered_entrance.dart';

/// A numeric 0-9 + backspace keypad for entering a 4-digit PIN, shared by
/// [PinSetupScreen] (creating/changing a PIN) and [AppLockScreen] (unlocking
/// with one). Purely presentational: it tracks the digits typed so far and
/// calls [onSubmit] once there are 4 of them — the caller decides what that
/// means (verify, confirm, save) and calls [PinKeypadState.reset]/
/// [PinKeypadState.shake] in response.
///
/// Its dots and keys fade in one after another when it first appears,
/// numbered from [entranceStart] so the caller's own header (icon, title)
/// can occupy the indexes before it.
class PinKeypad extends StatefulWidget {
  const PinKeypad({super.key, required this.onSubmit, this.entranceStart = 2});

  final ValueChanged<String> onSubmit;

  /// [StaggeredEntrance] index of the first PIN dot; the keys follow.
  final int entranceStart;

  @override
  State<PinKeypad> createState() => PinKeypadState();
}

class PinKeypadState extends State<PinKeypad>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;

  String _digits = '';
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// Clears the entered digits — called by the parent once it's decided
  /// what to do with a completed PIN (e.g. after a wrong-PIN error, or
  /// between the "enter" and "confirm" steps of setup).
  void reset() {
    if (!mounted) return;
    setState(() => _digits = '');
  }

  /// Plays a short shake to signal a wrong PIN, then clears it.
  void shake() {
    _shakeController.forward(from: 0);
    reset();
  }

  void _onDigit(String digit) {
    if (_digits.length >= _pinLength) return;
    setState(() => _digits += digit);
    if (_digits.length == _pinLength) {
      final pin = _digits;
      widget.onSubmit(pin);
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            // Four back-and-forth cycles, decaying to 0 by the end.
            final offset = math.sin(t * math.pi * 8) * 10 * (1 - t);
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) {
              final filled = i < _digits.length;
              // The dots arrive left to right, one after another. The shake
              // above only moves this whole row, so it is unaffected.
              return StaggeredEntrance(
                index: widget.entranceStart + i,
                axis: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? colors.gold : Colors.transparent,
                      border: Border.all(
                        color: filled ? colors.gold : colors.nightBorder,
                        width: kBorderWidthActive,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        _KeypadGrid(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          entranceStart: widget.entranceStart + 2,
        ),
      ],
    );
  }
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.onDigit,
    required this.onBackspace,
    required this.entranceStart,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// [StaggeredEntrance] index of the top-left key. Each row starts one
  /// step after the row above it and each key one step after its left
  /// neighbour, so the pad fills in as a diagonal wave, top to bottom.
  final int entranceStart;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < _rows.length; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < _rows[r].length; c++)
                  StaggeredEntrance(
                    index: entranceStart + r + c,
                    axis: Axis.horizontal,
                    child: _KeypadButton.digit(_rows[r][c], onDigit),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Matches a real button's own full cell width (72 plus its
            // 12px padding on each side, see [_KeypadButton]) — sized to
            // just 72 like the button itself, this cell would be 24px
            // narrower than the ones above it, and centering the row
            // would then visibly shift "0"/backspace left of the columns
            // they sit under.
            const SizedBox(width: 96, height: 72),
            StaggeredEntrance(
              index: entranceStart + _rows.length + 1,
              axis: Axis.horizontal,
              child: _KeypadButton.digit('0', onDigit),
            ),
            StaggeredEntrance(
              index: entranceStart + _rows.length + 2,
              axis: Axis.horizontal,
              child: _KeypadButton.backspace(onBackspace),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.child, required this.onTap});

  _KeypadButton.digit(String digit, ValueChanged<String> onDigit)
    : child = Text(digit),
      onTap = (() => onDigit(digit));

  const _KeypadButton.backspace(VoidCallback onBackspace)
    : child = const Icon(Icons.backspace_outlined, size: 20),
      onTap = onBackspace;

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: colors.nightPanel,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.nightBorder, width: kBorderWidth),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: colors.text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme(
                data: IconThemeData(color: colors.text),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
