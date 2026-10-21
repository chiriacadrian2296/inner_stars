import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/biometric_auth_service.dart';

void main() {
  test('on a phone there is nothing to set up before using the shortcut', () {
    expect(BiometricAuthService().enroll(), completion(isTrue));
  });
}
