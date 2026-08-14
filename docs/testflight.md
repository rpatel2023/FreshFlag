# FreshFlag TestFlight Runbook

This is the release checklist for the first iPhone/TestFlight beta. Do not mark the MVP complete until the multi-device scenario at the end passes on real iPhones.

## 1. Fixed project identity

Planned beta version:

```text
0.1.0+1
```

Use one explicit bundle identifier consistently in Xcode, Firebase, and App Store Connect. The source-prep branch uses:

```text
com.rpatel2023.freshflag
```

If this identifier cannot be registered in the Apple Developer account, choose another identifier once and update every platform/config reference before proceeding.

## 2. macOS/Xcode prerequisite

A real iOS archive requires macOS and Xcode. Flutter 3.44+ uses Swift Package Manager as the primary iOS/macOS plugin dependency mechanism and can migrate an older Flutter Xcode project when it is run with modern Flutter/Xcode.

On the Mac used for release:

```bash
flutter --version
flutter doctor -v
flutter pub get
flutter build ios --config-only
```

Then open:

```text
ios/Runner.xcworkspace
```

Confirm the Runner project has the generated Flutter Swift package integration and that all Flutter plugins resolve. Do not hand-edit generated SwiftPM package content.

## 3. FreshFlag Firebase project

The inherited `stayfresh-36edf` project must not be used for production/TestFlight.

Create or select a FreshFlag-owned Firebase project and configure:

- Firebase Authentication — Email/Password enabled;
- Cloud Firestore;
- Firebase Cloud Messaging;
- Cloud Functions / Cloud Scheduler billing/runtime support;
- iOS Firebase app with the exact FreshFlag bundle identifier.

Run FlutterFire configuration from the project root so `lib/firebase_options.dart` is regenerated from the FreshFlag project rather than manually typing API/app IDs.

The iOS app also needs the matching Firebase Apple configuration (`GoogleService-Info.plist`) integrated into the Runner target if required by the generated setup.

Never commit service-account JSON or APNs private keys.

## 4. Deploy backend and Firestore rules

From an authenticated Firebase CLI session targeting the FreshFlag project:

```bash
firebase use <freshflag-project-id>
firebase deploy --only firestore:rules,functions
```

Verify both scheduled functions exist:

- `processExpiryReminders`
- `pruneStaleDeviceRegistrations`

Confirm Cloud Scheduler created the scheduled invocations and that function logs show successful execution.

## 5. Apple signing and push

In Apple Developer / Xcode:

- register the explicit FreshFlag bundle identifier;
- select the appropriate development team;
- enable Push Notifications for the app identifier/Runner target;
- configure signing/provisioning for Distribution;
- configure APNs authentication for Firebase Cloud Messaging.

Do not store the APNs `.p8` private key in this repository.

## 6. iOS permissions

Required user-facing permissions:

- Camera — barcode scanning;
- Notifications — expiry reminders.

Camera permission should be requested when scanning is first used. Notification permission should be requested in context when reminders are useful, not blindly at first launch.

Remove permissions that the app does not use before submission.

## 7. Release assets

Before archive:

- replace inherited StayFresh app icon assets with FreshFlag artwork;
- verify icon has no transparency where App Store rules prohibit it;
- verify launch screen branding;
- confirm app display name is `FreshFlag`;
- inspect dark/light mode screens and Dynamic Type at practical sizes.

## 8. Build and archive

Before the archive:

```bash
flutter test
dart analyze
flutter build ios --release
```

In Xcode:

1. select a generic iOS device / distribution destination;
2. Product -> Archive;
3. validate the archive;
4. upload to App Store Connect.

Increment the build number for every subsequent TestFlight upload.

## 9. App Store Connect beta metadata

Prepare at minimum:

- app name and subtitle/description suitable for beta;
- contact information;
- privacy policy/support URL if required for distribution scope;
- App Privacy answers based on actual Firebase/account/device data usage;
- export-compliance answers;
- TestFlight beta description and feedback instructions.

Do not claim features that are not implemented.

## 10. Physical-device acceptance test

Use at least two signed-in accounts on two iPhones.

### Household/realtime

1. User A creates a household.
2. User A creates an invite.
3. User B joins using the code.
4. User A scans/adds an item.
5. User B sees the item without manual refresh.
6. User B edits or consumes the item and User A sees the update.

### Barcode

Test at least:

- known UPC/EAN recognized by Open Food Facts;
- unknown barcode -> manual entry;
- denied camera permission -> recoverable UI;
- no-network product lookup -> manual fallback.

### Push reminders

Create a temporary rule/time/expiry combination that becomes due within a few minutes.

Verify:

- both eligible users receive one notification;
- rerunning/waiting through another worker interval does not duplicate that delivery;
- disabled user push preference is honored;
- notification text renders configured template variables correctly.

### Notification tap

Verify all three states on a physical iPhone:

- app foreground;
- app background;
- app terminated.

For each state:

```text
notification tap
-> authenticate/session restore if necessary
-> correct household selected
-> exact item detail opens
```

Also test a notification whose item was deleted and one whose household access was removed; both must fail gracefully.

## 11. MVP/TestFlight definition of done

The beta is ready only when a non-developer can:

```text
install from TestFlight
-> create/sign into account
-> create or join household
-> scan a product
-> set expiry
-> see shared item on second phone
-> receive configured backend reminder on both eligible phones
-> tap reminder into exact item
-> consume/remove item
-> see the shared state update on both phones
```

Source-level CI is necessary but does not replace this physical-device acceptance test.
