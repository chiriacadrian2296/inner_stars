import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

/// The door to the whole app. Without a signed-in account nothing past the
/// login page opens; with one, [child] is built.
///
/// Three states, decided by [AuthService]: waiting (Firebase has not yet said
/// whether someone is signed in: a plain dark screen, under the startup
/// splash), the login page, or the app. If Firebase cannot start at all
/// (offline on the web) but an account was signed in before, the app opens
/// anyway, since its data is on the device.
///
/// Signing out closes every page opened on top and shows the login page.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.wasSignedIn,
    required this.login,
    required this.childBuilder,
    this.onLoginShown,
    this.onOpened,
    this.offline,
  });

  final AuthService auth;

  /// An account was signed in at an earlier launch.
  final bool wasSignedIn;
  final Widget login;

  /// Builds the app. `startLocked` is true only when the app opened at launch
  /// with the account already there, which is when the PIN lock applies; right
  /// after a fresh sign-in it is false.
  final Widget Function(bool startLocked) childBuilder;

  /// The login page's first frame is up (the startup splash can lift).
  final VoidCallback? onLoginShown;

  /// The app opened, with the same `startLocked` as [childBuilder] got.
  final ValueChanged<bool>? onOpened;

  /// Development builds only: while true the app opens without any account.
  final ValueListenable<bool>? offline;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Door { waiting, login, app }

class _AuthGateState extends State<AuthGate> {
  _Door _door = _Door.waiting;
  bool _sawLogin = false;
  bool _startLocked = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_refresh);
    widget.offline?.addListener(_refresh);
    _door = _decide();
    _entered(null, _door);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_refresh);
    widget.offline?.removeListener(_refresh);
    super.dispose();
  }

  _Door _decide() {
    final auth = widget.auth;
    if (widget.offline?.value ?? false) return _Door.app;
    if (auth.isSignedIn || (auth.initFailed && widget.wasSignedIn)) {
      return _Door.app;
    }
    return auth.isResolved ? _Door.login : _Door.waiting;
  }

  void _refresh() {
    final next = _decide();
    if (next == _door) return;
    final previous = _door;
    setState(() => _door = next);
    _entered(previous, next);
  }

  void _entered(_Door? from, _Door to) {
    switch (to) {
      case _Door.waiting:
        break;
      case _Door.login:
        _sawLogin = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (from == _Door.app) {
            // Signed out: close Settings and anything else left on top.
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          widget.onLoginShown?.call();
        });
      case _Door.app:
        _startLocked = !_sawLogin;
        final startLocked = _startLocked;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onOpened?.call(startLocked);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_door) {
      case _Door.waiting:
        return const ColoredBox(color: Color(0xFF0D1220));
      case _Door.login:
        return widget.login;
      case _Door.app:
        return widget.childBuilder(_startLocked);
    }
  }
}
