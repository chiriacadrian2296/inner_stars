import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google's rendered sign-in button. Pressing it signs in through the
/// authentication events that `AuthService` listens to.
Widget buildGoogleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.filledBlack,
    shape: web.GSIButtonShape.pill,
    minimumWidth: 240,
  ),
);
