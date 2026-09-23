import 'package:flutter/widgets.dart';

import '../data/app_lock_repository.dart';
import '../data/biometric_auth_service.dart';
import '../screens/app_lock_screen.dart';

/// Wraps the whole app and, whenever [AppLockRepository.isEnabled], gates
/// it behind [AppLockScreen] on cold start and every time it comes back
/// from the background — re-locking on [AppLifecycleState.paused]/
/// [.hidden] (same mobile-vs-web split [AudioService] already uses for its
/// own background handling), not on [.inactive], which also fires for a
/// fleeting, non-backgrounding interruption (a system dialog, the
/// notification shade) that re-locking on would just be an annoyance for.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.appLockRepository,
    required this.biometricAuthService,
    required this.child,
  });

  final AppLockRepository appLockRepository;
  final BiometricAuthService biometricAuthService;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  // Set from `widget` in initState rather than as a field initializer:
  // `widget` isn't assigned yet while this State is still being
  // constructed (createState() runs before the framework attaches it).
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.appLockRepository.isEnabled;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (widget.appLockRepository.isEnabled) {
          setState(() => _locked = true);
        }
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return AppLockScreen(
        appLockRepository: widget.appLockRepository,
        biometricAuthService: widget.biometricAuthService,
        onUnlocked: _unlock,
      );
    }
    return widget.child;
  }
}
