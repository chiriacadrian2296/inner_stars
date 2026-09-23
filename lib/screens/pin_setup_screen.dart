import 'package:flutter/material.dart';

import '../data/app_lock_repository.dart';
import '../data/biometric_auth_service.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/responsive_content.dart';

/// Creates/changes the app-lock PIN, or just verifies the existing one —
/// pushed from Settings for three cases: the very first PIN
/// (`requireCurrentPin: false`), changing an existing one
/// (`requireCurrentPin: true`), and proving identity for something that
/// isn't itself a PIN change, like turning the lock off
/// (`requireCurrentPin: true, verifyOnly: true` — see
/// `SettingsScreen._verifyIdentity`). Up to three steps in order: verify
/// the current PIN, enter a new one, confirm it — [verifyOnly] stops
/// (and pops `true`) right after a successful verify instead of going on
/// to ask for a new PIN. Pops `true` once either that verification or
/// [AppLockRepository.setPin] has actually happened, or `false`/`null` if
/// the user backs out at any point.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.appLockRepository,
    required this.biometricAuthService,
    this.requireCurrentPin = false,
    this.verifyOnly = false,
  }) : assert(
         !verifyOnly || requireCurrentPin,
         'verifyOnly only makes sense when there is a current PIN to verify',
       );

  final AppLockRepository appLockRepository;
  final BiometricAuthService biometricAuthService;
  final bool requireCurrentPin;
  final bool verifyOnly;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { verifyCurrent, enterNew, confirmNew }

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _keypadKey = GlobalKey<PinKeypadState>();
  late _Step _step;
  String? _newPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.requireCurrentPin ? _Step.verifyCurrent : _Step.enterNew;
  }

  void _onSubmit(String pin) {
    setState(() => _error = null);
    switch (_step) {
      case _Step.verifyCurrent:
        if (widget.appLockRepository.verifyPin(pin)) {
          if (widget.verifyOnly) {
            Navigator.of(context).pop(true);
            return;
          }
          setState(() => _step = _Step.enterNew);
          _keypadKey.currentState?.reset();
        } else {
          setState(() => _error = context.strings.appLockWrongPinError);
          _keypadKey.currentState?.shake();
        }
      case _Step.enterNew:
        _newPin = pin;
        setState(() => _step = _Step.confirmNew);
        _keypadKey.currentState?.reset();
      case _Step.confirmNew:
        if (pin == _newPin) {
          widget.appLockRepository.setPin(pin).then((_) {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          setState(() {
            _error = context.strings.appLockPinMismatchError;
            _step = _Step.enterNew;
            _newPin = null;
          });
          _keypadKey.currentState?.shake();
        }
    }
  }

  String _title(BuildContext context) {
    final strings = context.strings;
    switch (_step) {
      case _Step.verifyCurrent:
        return strings.appLockEnterCurrentPinTitle;
      case _Step.enterNew:
        return strings.appLockSetPinTitle;
      case _Step.confirmNew:
        return strings.appLockConfirmPinTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _title(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.danger, fontSize: 13),
                        ),
                ),
                const SizedBox(height: 20),
                PinKeypad(key: _keypadKey, onSubmit: _onSubmit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
