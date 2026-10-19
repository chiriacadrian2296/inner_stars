import 'package:flutter/widgets.dart';

import 'auth_service.dart';

/// Hands the [AuthService] to any screen below the Navigator, so Settings
/// does not need one more constructor argument threaded through the Galaxy.
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({
    super.key,
    required AuthService service,
    required super.child,
  }) : super(notifier: service);

  /// Null when no scope is above [context] (e.g. a widget test), in which case
  /// the account section is simply not shown.
  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
}
