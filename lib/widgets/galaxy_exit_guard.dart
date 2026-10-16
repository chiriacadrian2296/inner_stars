import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_style.dart';
import '../theme/app_colors.dart';
import '../utils/app_modals.dart';
import '../utils/web_back_guard_stub.dart'
    if (dart.library.js_interop) '../utils/web_back_guard_web.dart';

/// Confirm system Back from Galaxy before closing the app.
class GalaxyExitGuard extends StatefulWidget {
  const GalaxyExitGuard({
    super.key,
    required this.child,
    this.consumeBack,
    this.absorbInteractions = false,
  });

  final Widget child;

  /// Close an open Galaxy panel first; true means Back was handled there.
  final bool Function()? consumeBack;

  /// Prevent every pointer interaction with Galaxy while an atomic camera
  /// movement is in progress. System Back is handled separately by
  /// [consumeBack], because it does not participate in pointer hit testing.
  final bool absorbInteractions;

  @override
  State<GalaxyExitGuard> createState() => _GalaxyExitGuardState();
}

class _GalaxyExitGuardState extends State<GalaxyExitGuard> {
  bool _confirming = false;

  Future<void> _onBack(bool didPop, Object? result) async {
    if (didPop || _confirming || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (widget.consumeBack?.call() ?? false) return;
    _confirming = true;
    try {
      final strings = context.strings;
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: Text(strings.exitAppTitle),
          content: Text(strings.exitAppBody),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.muted,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: AppButtonLabel(
                strings.cancel,
                color: dialogContext.colors.muted,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: AppButtonLabel(strings.exitAppConfirm),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        // The browser can't be closed by the app: step back past it instead.
        if (kIsWeb) {
          leaveWebApp();
        } else {
          await SystemNavigator.pop();
        }
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: _onBack,
    child: AbsorbPointer(
      key: const ValueKey('galaxy-flight-interaction-lock'),
      absorbing: widget.absorbInteractions,
      child: widget.child,
    ),
  );
}
