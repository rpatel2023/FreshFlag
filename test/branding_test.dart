import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/config/app_brand.dart';

void main() {
  test('user-facing brand is Fresh Flag', () {
    expect(AppBrand.name, 'Fresh Flag');
  });

  test('platform display names use Fresh Flag', () {
    final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final androidManifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(iosPlist, contains('<string>Fresh Flag</string>'));
    expect(iosPlist, contains('Fresh Flag uses the camera'));
    expect(androidManifest, contains('android:label="Fresh Flag"'));
  });
}
