import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Temporary Firebase options used to satisfy compile-time references.
///
/// Replace with generated values from:
/// `flutterfire configure`
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:web:stub',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:android:stub',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:ios:stub',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
    iosBundleId: 'com.example.circlebn',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:ios:stub-macos',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
    iosBundleId: 'com.example.circlebn',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:web:stub-windows',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: '1:000000000000:web:stub-linux',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
  );
}
