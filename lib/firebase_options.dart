// FreshFlag production Firebase configuration is intentionally not committed yet.
//
// Run `flutterfire configure` against the FreshFlag-owned Firebase project before
// a device/TestFlight build. FlutterFire will replace this file with generated
// platform options. Keeping an explicit stub prevents development builds from
// accidentally writing to the imported StayFresh Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'FreshFlag Firebase configuration is not installed. '
      'Run flutterfire configure against the FreshFlag-owned Firebase project.',
    );
  }
}
