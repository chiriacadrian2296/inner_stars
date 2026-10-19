import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../sync/sync_service.dart';

/// Google sign-in for the cloud copy of the user's data. Nothing here runs
/// until [ensureReady] is called, so the app stays fully usable offline and
/// without an account (local-first).
///
/// The Google account is verified by `google_sign_in`, which hands over an ID
/// token; Firebase only checks that token (`signInWithCredential`). That is
/// why Firebase's list of authorized domains is not involved on the web.
class AuthService extends ChangeNotifier implements SyncAccount {
  AuthService({
    GoogleSignIn? google,
    FirebaseAuth Function()? auth,
    this.onSignInChanged,
  }) : _google = google ?? GoogleSignIn.instance,
       _authFactory = auth ?? (() => FirebaseAuth.instance);

  /// Told whenever Firebase reports a sign-in or sign-out (not on the first
  /// initialization), so the app can remember that an account exists and
  /// bring Firebase up at launch to resume syncing.
  final void Function(bool signedIn)? onSignInChanged;

  final GoogleSignIn _google;
  final FirebaseAuth Function() _authFactory;

  FirebaseAuth? _auth;
  Future<bool>? _ready;
  StreamSubscription<User?>? _userSub;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;
  User? _user;
  Object? _lastError;

  /// The signed-in Firebase user, or null.
  User? get user => _user;
  bool get isSignedIn => _user != null;
  @override
  String? get uid => _user?.uid;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  /// The last sign-in failure, cleared by the next attempt.
  Object? get lastError => _lastError;

  /// Whether this platform needs Google's own rendered button instead of a
  /// call to [signInWithGoogle] (the web).
  bool get needsGoogleButton => !_google.supportsAuthenticate();

  /// Initializes Firebase and Google Sign-In once. Returns false, without
  /// throwing, when that is not possible (unsupported platform, offline web
  /// SDK, missing configuration).
  Future<bool> ensureReady() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final auth = _authFactory();
      _auth = auth;
      _user = auth.currentUser;
      _userSub = auth.authStateChanges().listen((user) {
        _user = user;
        onSignInChanged?.call(user != null);
        notifyListeners();
      });
      await _google.initialize(
        clientId: kIsWeb ? DefaultFirebaseOptions.googleWebClientId : null,
        serverClientId: kIsWeb
            ? null
            : DefaultFirebaseOptions.googleWebClientId,
      );
      _googleSub = _google.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            unawaited(_exchange(event.user));
          }
        },
        onError: (Object error) {
          _lastError = error;
          notifyListeners();
        },
      );
      notifyListeners();
      return true;
    } catch (error) {
      _ready = null;
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  /// Interactive sign-in (Android). On the web the sign-in comes from
  /// Google's rendered button through the authentication events instead.
  Future<void> signInWithGoogle() async {
    _lastError = null;
    if (!await ensureReady()) {
      throw StateError('Sign-in is not available on this device');
    }
    if (needsGoogleButton) {
      throw UnsupportedError('Use the Google button on this platform');
    }
    final account = await _google.authenticate();
    await _exchange(account);
  }

  Future<void> _exchange(GoogleSignInAccount account) async {
    try {
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google returned no ID token');
      await _auth!.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  /// Firebase only deletes an account that signed in a moment ago.
  bool get hasRecentSignIn {
    final last = _user?.metadata.lastSignInTime;
    return last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 4);
  }

  /// Asks Google for the account again so a sensitive action is allowed
  /// (Android). Returns false where that needs Google's own button (the web):
  /// the person must then sign out and in again.
  Future<bool> reauthenticate() async {
    final user = _auth?.currentUser;
    if (user == null || needsGoogleButton) return false;
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Google returned no ID token');
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return true;
  }

  /// Deletes the Firebase account and revokes this app's Google access. The
  /// caller deletes the cloud data first (the rules need the signed-in user).
  Future<void> deleteAccount() async {
    final user = _auth?.currentUser;
    if (user == null) throw StateError('Not signed in');
    await user.delete();
    try {
      await _google.disconnect();
    } catch (_) {
      // The account is already gone; revoking access is best effort.
    }
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    await _google.signOut();
    await _auth!.signOut();
  }

  @override
  void dispose() {
    unawaited(_userSub?.cancel());
    unawaited(_googleSub?.cancel());
    super.dispose();
  }
}
