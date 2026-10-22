import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inner_stars/auth/auth_service.dart';

void main() {
  group('a sign-in the person backed out of is not an error', () {
    test('closing Google\'s window or being interrupted needs no message', () {
      for (final code in [
        GoogleSignInExceptionCode.canceled,
        GoogleSignInExceptionCode.interrupted,
      ]) {
        expect(
          AuthService.isCancellation(GoogleSignInException(code: code)),
          isTrue,
          reason: '$code',
        );
      }
    });

    test('real failures still count', () {
      for (final code in [
        GoogleSignInExceptionCode.unknownError,
        GoogleSignInExceptionCode.clientConfigurationError,
        GoogleSignInExceptionCode.providerConfigurationError,
        GoogleSignInExceptionCode.uiUnavailable,
      ]) {
        expect(
          AuthService.isCancellation(GoogleSignInException(code: code)),
          isFalse,
          reason: '$code',
        );
      }
      expect(AuthService.isCancellation(StateError('no token')), isFalse);
    });
  });
}
