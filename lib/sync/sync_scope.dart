import 'package:flutter/widgets.dart';

import 'sync_service.dart';

/// Hands the [SyncService] to the Account section so it can show the time of
/// the last sync, without another constructor argument through the Galaxy.
class SyncScope extends InheritedNotifier<SyncService> {
  const SyncScope({
    super.key,
    required SyncService service,
    required super.child,
  }) : super(notifier: service);

  /// Null when no scope is above [context].
  static SyncService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
