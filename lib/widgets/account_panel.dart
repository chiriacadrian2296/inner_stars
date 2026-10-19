import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../auth/auth_service.dart';
import '../auth/google_button_stub.dart'
    if (dart.library.js_interop) '../auth/google_button_web.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../utils/date_format.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// The Account section of Settings: sign in with Google, or see who is signed
/// in and sign out. Signed out, the app keeps working on this device; signing
/// out leaves the data on the device. Renders nothing without an [AuthScope].
class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key});

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  Future<bool>? _ready;
  bool _busy = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ready ??= AuthScope.maybeOf(context)?.ensureReady();
  }

  Future<void> _signIn(AuthService auth) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await auth.signInWithGoogle();
    } catch (_) {
      // A cancelled picker is not a failure worth a message.
      if (mounted) setState(() => _failed = auth.lastError != null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut(AuthService auth) async {
    setState(() => _busy = true);
    try {
      // One last update while still signed in, so nothing made on this device
      // is left only on it. A failure (offline) does not stop signing out.
      await SyncScope.maybeOf(context)
          ?.syncNow()
          .timeout(const Duration(seconds: 15), onTimeout: () {});
      await auth.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    if (auth == null) return const SizedBox.shrink();
    final colors = context.colors;
    final strings = context.strings;
    return Container(
      key: const ValueKey('account-panel'),
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(colors),
      child: FutureBuilder<bool>(
        future: _ready,
        builder: (context, snapshot) {
          final ready = snapshot.data == true;
          final done = snapshot.connectionState == ConnectionState.done;
          if (auth.isSignedIn) return _signedIn(auth, colors, strings);
          if (done && !ready) {
            return _note(strings.accountUnavailable, colors);
          }
          return _signedOut(auth, colors, strings, ready);
        },
      ),
    );
  }

  Widget _note(String text, AppColors colors) => Text(
    text,
    style: TextStyle(color: colors.muted, fontSize: 13, height: 1.45),
  );

  Widget _signedOut(
    AuthService auth,
    AppColors colors,
    AppStrings strings,
    bool ready,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note(strings.accountSignedOutNote, colors),
        const SizedBox(height: 14),
        if (kIsWeb)
          SizedBox(
            height: 44,
            child: ready ? buildGoogleWebButton() : const SizedBox.shrink(),
          )
        else
          OutlinedButton.icon(
            key: const ValueKey('account-sign-in'),
            onPressed: _busy || !ready ? null : () => _signIn(auth),
            icon: const Icon(Icons.login, size: 18),
            label: AppButtonLabel(strings.accountSignIn),
          ),
        if (_failed || auth.lastError != null) ...[
          const SizedBox(height: 10),
          Text(
            strings.accountSignInFailed,
            key: const ValueKey('account-error'),
            style: TextStyle(color: colors.danger, fontSize: 13, height: 1.4),
          ),
        ],
      ],
    );
  }

  /// Syncing is automatic, so this only reports: updating, a problem, or when
  /// the cloud copy was last brought up to date.
  Widget _syncLine(AppColors colors, AppStrings strings) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return const SizedBox.shrink();
    final last = sync.lastSyncAt;
    final text = switch (sync.status) {
      SyncStatus.syncing => strings.accountSyncing,
      SyncStatus.error => strings.accountSyncError,
      SyncStatus.idle =>
        last == null
            ? strings.accountNeverSynced
            : strings.accountLastSync(formatDisplayDateTime(last, strings)),
    };
    return Text(
      text,
      key: const ValueKey('account-sync-status'),
      style: TextStyle(
        color: sync.status == SyncStatus.error ? colors.danger : colors.muted,
        fontSize: 12,
      ),
    );
  }

  Widget _signedIn(AuthService auth, AppColors colors, AppStrings strings) {
    final name = auth.displayName;
    final photo = auth.photoUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.nightPanel,
              foregroundImage: photo == null ? null : NetworkImage(photo),
              child: Icon(Icons.person_outline, color: colors.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.accountSignedInAs,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                  if (name != null && name.isNotEmpty)
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (auth.email != null)
                    Text(
                      auth.email!,
                      key: const ValueKey('account-email'),
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _syncLine(colors, strings),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('account-sign-out'),
          onPressed: _busy ? null : () => _signOut(auth),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.muted,
            side: BorderSide(color: colors.muted.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: AppButtonLabel(strings.accountSignOut, color: colors.muted),
        ),
        const SizedBox(height: 10),
        _note(strings.accountSignOutNote, colors),
      ],
    );
  }
}
