import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

/// Browser side of the app lock's fingerprint shortcut: WebAuthn, asking the
/// device to verify the person (fingerprint, face, Windows Hello or the
/// device's own PIN) for a passkey that stays on this device or in the
/// browser's own password manager. Nothing is sent to a server; the app only
/// checks that the verification succeeded, so this is a convenience in front
/// of the PIN, not a security boundary.

JSObject _object(Map<String, JSAny?> values) {
  final result = JSObject();
  values.forEach((key, value) => result.setProperty(key.toJS, value));
  return result;
}

JSUint8Array _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  ).toJS;
}

JSObject? get _credentials {
  final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
  return navigator?.getProperty<JSObject?>('credentials'.toJS);
}

/// Whether this browser can verify the person with the device itself.
Future<bool> webPasskeySupported() async {
  try {
    final credential = globalContext.getProperty<JSObject?>(
      'PublicKeyCredential'.toJS,
    );
    if (credential == null || _credentials == null) return false;
    final available = await credential
        .callMethod<JSPromise<JSBoolean>>(
          'isUserVerifyingPlatformAuthenticatorAvailable'.toJS,
        )
        .toDart;
    return available.toDart;
  } catch (_) {
    return false;
  }
}

/// Creates a passkey for this site on this device and returns its id, or null
/// if the person cancelled or the browser refused.
Future<String?> registerWebPasskey() async {
  try {
    final options = _object({
      'publicKey': _object({
        'challenge': _randomBytes(32),
        'rp': _object({'name': 'Inner Stars'.toJS}),
        'user': _object({
          'id': _randomBytes(16),
          'name': 'inner-stars-lock'.toJS,
          'displayName': 'Inner Stars'.toJS,
        }),
        'pubKeyCredParams': [
          _object({'type': 'public-key'.toJS, 'alg': (-7).toJS}),
          _object({'type': 'public-key'.toJS, 'alg': (-257).toJS}),
        ].toJS,
        'authenticatorSelection': _object({
          'authenticatorAttachment': 'platform'.toJS,
          'userVerification': 'required'.toJS,
          'residentKey': 'preferred'.toJS,
        }),
        'timeout': 60000.toJS,
      }),
    });
    final created = await _credentials!
        .callMethod<JSPromise<JSObject?>>('create'.toJS, options)
        .toDart;
    final rawId = created?.getProperty<JSArrayBuffer?>('rawId'.toJS);
    if (rawId == null) return null;
    return base64Url.encode(rawId.toDart.asUint8List());
  } catch (_) {
    return null;
  }
}

/// Asks the device to verify the person against the passkey [credentialId].
Future<bool> verifyWebPasskey(String credentialId) async {
  try {
    final options = _object({
      'publicKey': _object({
        'challenge': _randomBytes(32),
        'allowCredentials': [
          _object({
            'type': 'public-key'.toJS,
            'id': Uint8List.fromList(base64Url.decode(credentialId)).toJS,
          }),
        ].toJS,
        'userVerification': 'required'.toJS,
        'timeout': 60000.toJS,
      }),
    });
    final result = await _credentials!
        .callMethod<JSPromise<JSObject?>>('get'.toJS, options)
        .toDart;
    return result != null;
  } catch (_) {
    return false;
  }
}
