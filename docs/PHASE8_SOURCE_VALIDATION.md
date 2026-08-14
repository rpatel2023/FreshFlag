# Phase 8 Source Validation

Date: 2026-08-14
Branch: `phase8-testflight-prep`

## Ubuntu validation

`tool/phase8_local_checkpoint.sh` completed successfully after the Phase 8 cleanup.

- Flutter tests: **17/17 passed**.
- `dart analyze`: **No issues found**.
- Linux release build: **success**.
- No inherited `stayfresh-36edf` Firebase project reference remains.
- No inherited `com.example.stayfresh` application identifier remains.
- iOS app bundle ID: `com.rpatel2023.freshflag`.
- iOS test bundle ID: `com.rpatel2023.freshflag.RunnerTests`.
- Generated FreshFlag master icon: 1024×1024 PNG.
- Generated all 21 PNGs referenced by the iOS AppIcon asset catalog.
- Generated dependency/plugin/platform metadata committed as `4a46ea3`.
- Working tree clean after commit/push.

## Source safety decisions

- The inherited StayFresh Firebase client configuration was removed instead of reused.
- `lib/firebase_options.dart` intentionally blocks runtime Firebase initialization until `flutterfire configure` is run against a FreshFlag-owned Firebase project.
- The inherited Android `google-services.json` was deleted.
- Backend FCM remains the sole expiry-reminder delivery mechanism; the unused legacy local-notification service and dependencies were removed.

## Remaining external validation gates

These cannot be completed on Ubuntu or from repository source alone:

1. Create/select a FreshFlag-owned Firebase project.
2. Run FlutterFire configuration for bundle ID `com.rpatel2023.freshflag`.
3. Configure Firebase Authentication, Firestore, FCM/APNs and deploy Firestore rules/Functions.
4. Open/migrate the iOS project with modern Flutter + Xcode/Swift Package Manager on macOS.
5. Configure Apple signing and Push Notifications capability/entitlements.
6. Build/archive and distribute through TestFlight.
7. Validate the complete two-user/two-device MVP acceptance flow on physical iPhones.
