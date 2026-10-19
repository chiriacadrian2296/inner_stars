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
///
/// On cold start the lock stands in for [child], so no frame of real
/// content is ever built behind it. Once the app is running, re-locking
/// pushes the lock as a route on the root navigator instead: this gate
/// sits in the app's home route, so swapping [child] out would leave every
/// page opened on top of it (Settings, a sheet, a dialog) still showing
/// over the lock — and would throw away the Galaxy's state underneath.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.appLockRepository,
    required this.biometricAuthService,
    required this.child,
    this.onLaunchUnlocked,
    this.startLocked,
  });

  final AppLockRepository appLockRepository;
  final BiometricAuthService biometricAuthService;
  final Widget child;
  final VoidCallback? onLaunchUnlocked;

  /// Whether the lock stands in front of the app at first. Defaults to
  /// whether the lock is enabled; false right after signing in, since the
  /// person has just proven who they are.
  final bool? startLocked;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  // Set from `widget` in initState rather than as a field initializer:
  // `widget` isn't assigned yet while this State is still being
  // constructed (createState() runs before the framework attaches it).
  late bool _lockedAtLaunch;

  /// The lock pushed over everything after a trip to the background, while
  /// it's showing.
  Route<void>? _lockRoute;

  @override
  void initState() {
    super.initState();
    _lockedAtLaunch =
        widget.appLockRepository.isEnabled && (widget.startLocked ?? true);
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
        if (widget.appLockRepository.isEnabled) _lock();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _lock() {
    // Already locked: the launch lock is still up, or a pushed one is.
    if (_lockedAtLaunch || _lockRoute != null || !mounted) return;
    final route = PageRouteBuilder<void>(
      // No slide in: the content must already be covered on return.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => PopScope(
        // Back mustn't dismiss the lock and reveal the app.
        canPop: false,
        child: AppLockScreen(
          appLockRepository: widget.appLockRepository,
          biometricAuthService: widget.biometricAuthService,
          onUnlocked: _unlockRoute,
        ),
      ),
    );
    _lockRoute = route;
    Navigator.of(context, rootNavigator: true).push(route);
  }

  void _unlockRoute() {
    final route = _lockRoute;
    _lockRoute = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  void _unlockLaunch() {
    setState(() => _lockedAtLaunch = false);
    widget.onLaunchUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_lockedAtLaunch) {
      return AppLockScreen(
        appLockRepository: widget.appLockRepository,
        biometricAuthService: widget.biometricAuthService,
        onUnlocked: _unlockLaunch,
      );
    }
    return widget.child;
  }
}
