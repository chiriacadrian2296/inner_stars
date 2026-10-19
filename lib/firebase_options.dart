import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase project `inner-stars-5e6d6`. These are client identifiers, not
/// secrets: access is enforced by the Firestore security rules and by the
/// key restrictions in the Google Cloud console. iOS is not registered yet.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform yet.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB45JYbuqt71KgaAdVPC2LnteILOUhe9WM',
    appId: '1:331506513097:web:477a75d3fa3eb360694918',
    messagingSenderId: '331506513097',
    projectId: 'inner-stars-5e6d6',
    authDomain: 'inner-stars-5e6d6.firebaseapp.com',
    storageBucket: 'inner-stars-5e6d6.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCbXWeqv5bzN6Dn17it0yg9f9WIeGjW1CM',
    appId: '1:331506513097:android:1b30e1073bb8f5b6694918',
    messagingSenderId: '331506513097',
    projectId: 'inner-stars-5e6d6',
    storageBucket: 'inner-stars-5e6d6.firebasestorage.app',
  );

  /// The OAuth web client Firebase created. Google Sign-In uses it as the
  /// `serverClientId` on Android and as the `clientId` on the web.
  static const String googleWebClientId =
      '331506513097-nfss0eaacqlvui7nch7ts9jeuuvhq6vr.apps.googleusercontent.com';
}
