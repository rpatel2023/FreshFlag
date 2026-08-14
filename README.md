# FreshFlag

FreshFlag is a Flutter food-expiry tracker built around one household workflow:

`SCAN → SET EXPIRY → SHARE WITH HOUSEHOLD → GET REMINDED → CONSUME / REMOVE`

The primary release target is iPhone through TestFlight.

## Current product state

The source implementation now includes:

- Firebase email/password authentication;
- household-owned Firestore inventory with owner/member roles;
- real-time household inventory updates;
- shareable household invite codes with expiry/revocation;
- barcode scanning with Open Food Facts recognition and manual fallback;
- calendar-date expiry values stored as `YYYY-MM-DD`;
- configurable household reminder rules;
- backend scheduled reminder evaluation in the household IANA timezone;
- deterministic delivery idempotency;
- per-install FCM device registration, opt-out, invalid-token cleanup, and stale-device pruning;
- notification taps that switch to the correct household and open the exact inventory item;
- Firestore Emulator authorization tests;
- PR-only, path-filtered Flutter and backend CI.

Phases 1–7 are source-complete and validated. Phase 8 is active: FreshFlag-owned Firebase/Apple configuration, iOS project migration/signing, physical-device testing, and TestFlight release.

## Architecture

Firebase is the only application backend:

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Cloud Functions v2 / Cloud Scheduler
- Firebase Emulator Suite

Core Firestore shape:

```text
users/{uid}
  devices/{deviceId}

households/{householdId}
  members/{uid}
  items/{itemId}
  notificationRules/{ruleId}

invites/{inviteCode}
notificationDeliveries/{deliveryId}
```

See `ARCHITECTURE.md` for implementation details and `PROJECT_CONTEXT.md` for product constraints.

## Firebase configuration status

The imported StayFresh Firebase project has been deliberately disconnected. `lib/firebase_options.dart` is currently a safe stub and the inherited Android `google-services.json` has been removed.

Before a device/TestFlight build, run FlutterFire configuration against a **FreshFlag-owned Firebase project**. Do not restore or reuse the imported `stayfresh-36edf` configuration.

## Development validation

Validated baseline environment:

- Ubuntu 24.04
- Flutter 3.47.0 stable
- Dart 3.13.0

Typical client validation:

```bash
flutter pub get
flutter test
dart analyze
flutter build linux --release
```

Backend/security validation is automated in `.github/workflows/backend-ci.yml` when relevant PR paths change.

The iOS project can be prepared statically from Linux, but actual Swift Package Manager migration verification, signing, archive creation, APNs validation, and TestFlight upload require macOS/Xcode.

## Phase 8 / TestFlight

Use `docs/testflight.md` as the release runbook. The beta is not considered complete until two real iPhones can join one household, share an item in real time, receive one backend reminder each, open the exact item from the notification, and synchronize consume/remove state.

## Provenance

FreshFlag began from the MIT-licensed StayFresh repository while preserving Git history and is maintained as an independent repository. See:

- `UPSTREAM.md`
- `THIRD_PARTY_NOTICES.md`
- `docs/BASELINE_AUDIT.md`

## Engineering log

`CHANGELOG.md` is the persistent progress log and must be updated after every meaningful implementation, validation, architectural decision, migration, or blocker.
