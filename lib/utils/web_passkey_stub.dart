/// Not on the web: the phone's own biometric prompt is used instead.
Future<bool> webPasskeySupported() async => false;

/// Not on the web.
Future<String?> registerWebPasskey() async => null;

/// Not on the web.
Future<bool> verifyWebPasskey(String credentialId) async => false;
