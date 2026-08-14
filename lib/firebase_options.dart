// Firebase options for the FreshFlag production project.
//
// The iOS app is registered directly with Firebase because FlutterFire CLI
// project discovery currently returns an empty project list for this account
// even though direct Firebase CLI project operations succeed.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FreshFlag Firebase is not configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'FreshFlag Firebase is currently configured for iOS only.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZqlk7yFeSVoOpLD2AE-n2NVnpvXGOfdk',
    appId: '1:765920629957:ios:7e3a403712197ed143ccac',
    messagingSenderId: '765920629957',
    projectId: 'freshflag',
    storageBucket: 'freshflag.firebasestorage.app',
    iosBundleId: 'com.rpatel2023.freshflag',
  );
}
