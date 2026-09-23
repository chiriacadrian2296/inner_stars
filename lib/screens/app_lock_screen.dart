import 'package:flutter/material.dart';

import '../data/app_lock_repository.dart';
import '../data/biometric_auth_service.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/responsive_content.dart';

/// The actual lock screen — shown by [AppLockGate] on cold start and every
/// time the app comes back from the background, whenever
/// [AppLockRepository.isEnabled] is true. No way out except a correct PIN
/// (or, if enabled, a successful fingerprint check): the back button is
/// swallowed via [PopScope] and there's no app bar to navigate away from.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.appLockRepository,
    required this.biometricAuthService,
    required this.onUnlocked,
  });

  final AppLockRepository appLockRepository;
  final BiometricAuthService biometricAuthService;
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _keypadKey = GlobalKey<PinKeypadState>();
  String? _error;
  bool _authenticatingBiometric = false;

  @override
  void initState() {
    super.initState();
    if (widget.appLockRepository.biometricEnabled) {
      // Post-frame: `context.strings` (used inside) needs an inherited
      // widget already mounted, which isn't guaranteed yet in initState.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    setState(() => _authenticatingBiometric = true);
    final strings = context.strings;
    final success = await widget.biometricAuthService.authenticate(
      reason: strings.appLockBiometricReason,
      title: strings.appLockBiometricReason,
      cancelLabel: strings.cancel,
    );
    if (!mounted) return;
    setState(() => _authenticatingBiometric = false);
    if (success) widget.onUnlocked();
  }

  void _onPinSubmit(String pin) {
    if (widget.appLockRepository.verifyPin(pin)) {
      widget.onUnlocked();
    } else {
      setState(() => _error = context.strings.appLockWrongPinError);
      _keypadKey.currentState?.shake();
    }
  }

  // Shared by the PIN title and the fingerprint label below, so the two
  // section headings read as the same kind of text rather than one
  // looking like a heading and the other like a caption.
  TextStyle _sectionTitleStyle(AppColors colors) => TextStyle(
    color: colors.text,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  Widget _buildPinSection(AppColors colors, AppStrings strings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, color: colors.gold, size: 36),
        const SizedBox(height: 16),
        Text(
          strings.appLockUnlockTitle,
          textAlign: TextAlign.center,
          style: _sectionTitleStyle(colors),
        ),
        // Same 16px as the icon-to-title gap above, doubling as the
        // reserved slot for a wrong-PIN error so the keypad never jumps
        // when one appears.
        SizedBox(
          height: 16,
          child: _error == null
              ? null
              : Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.danger, fontSize: 11),
                ),
        ),
        PinKeypad(key: _keypadKey, onSubmit: _onPinSubmit),
      ],
    );
  }

  // Retries the biometric prompt — a separate block from the PIN section
  // (not a small append to it) so it reads as its own equally-weighted way
  // in, not an afterthought hanging off the keypad. No animation on the
  // glow anymore: it pulsed while `_authenticatingBiometric`, but the
  // system prompt it triggers covers the whole screen on this device
  // (confirmed: Xiaomi/MIUI's own fingerprint sheet), so a pulse timed to
  // that state is never actually seen — a constant "resting lit" glow is
  // both simpler and just as visible.
  Widget _buildBiometricSection(AppColors colors, AppStrings strings) {
    const diameter = 84.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colors.nightPanel,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _authenticatingBiometric ? null : _tryBiometric,
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.nightPanel,
                // Thicker than the app's usual "active" ring
                // (kBorderWidthActive, 2) — the border alone is what
                // gives this button its weight now that there's no glow.
                border: Border.all(color: colors.gold, width: 3),
              ),
              child: Icon(Icons.fingerprint, color: colors.gold, size: 58),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          strings.appLockBiometricToggleLabel,
          style: _sectionTitleStyle(colors),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final biometricEnabled = widget.appLockRepository.biometricEnabled;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.night,
        body: SafeArea(
          child: ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              // Without biometrics there's only the PIN block, so it stays
              // centered same as before. With both, `spaceBetween` is what
              // actually pushes the two toward the screen's own top/bottom
              // rather than leaving them clumped together in the middle —
              // each keeps its `MainAxisSize.min` block above so it doesn't
              // itself stretch to fill the gap.
              child: biometricEnabled
                  ? Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPinSection(colors, strings),
                        _buildBiometricSection(colors, strings),
                      ],
                    )
                  : Center(child: _buildPinSection(colors, strings)),
            ),
          ),
        ),
      ),
    );
  }
}
