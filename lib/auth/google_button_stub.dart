import 'package:flutter/widgets.dart';

/// Google's own sign-in button only exists on the web; elsewhere the account
/// panel shows its own button, which calls `AuthService.signInWithGoogle`.
Widget buildGoogleWebButton() => const SizedBox.shrink();
