# FreshFlag

FreshFlag is a Flutter food-expiry tracker being built for iPhone/TestFlight first. The product goal is a shared household inventory where people can scan packaged-food barcodes, set expiry dates, and receive configurable reminders before food expires.

## Product loop

`SCAN → SET EXPIRY → SHARE WITH HOUSEHOLD → GET REMINDED → CONSUME/REMOVE`

The current branch is still in stabilization. Household collaboration and backend reminder scheduling are intentionally not layered onto an untrusted single-user foundation.

## Current implementation

On `phase1-stabilization`, the app currently has:

- Firebase email/password authentication.
- Firestore-backed single-user inventory under `users/{uid}/groceryItems/{itemId}`.
- Manual item entry.
- Camera barcode capture using `mobile_scanner`.
- Barcode value handoff into the saved inventory item.
- Date-only expiry semantics persisted as `YYYY-MM-DD`.
- Backward-compatible parsing of inherited full ISO expiry timestamps.
- Inventory/reminder screens driven from one `GroceryViewModel` rather than a second local grocery database.
- Local reminder scheduling as a temporary Phase 1 capability.
- FCM permission/token plumbing, but no client-side FCM sending.
- Device-local UI preferences using `SharedPreferences` only.
- Phase 1 Firestore ownership rules in `firestore.rules`.

## Deliberately not implemented yet

- Open Food Facts product recognition from barcode — Phase 2.
- Shared household ownership/realtime collaboration — Phase 3.
- Household invites — Phase 4.
- Configurable household notification rules — Phase 5.
- Backend push worker/device-token persistence — Phase 6.
- Notification deep linking — Phase 7.
- Final iPhone/TestFlight configuration and polish — Phase 8.

## Architecture direction

FreshFlag uses Firebase as the backend direction:

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Cloud Functions / scheduled backend work in later phases
- Firebase Emulator Suite for security/rule testing in later phases

The inherited Supabase storage/token path has been removed from the active architecture.

The planned household data model is:

```text
users/{uid}
  devices/{deviceId}
households/{householdId}
  members/{uid}
  items/{itemId}
  notificationRules/{ruleId}
invites/{inviteId}
productCache/{normalizedBarcode}
notificationDeliveries/{deliveryId}
```

Phase 1 intentionally still uses the transitional per-user grocery collection until the household migration.

## Expiry semantics

Expiry is a calendar date, not a timestamp. New data is persisted as:

```text
YYYY-MM-DD
```

This avoids time-of-day/timezone changes altering the expiry day. Legacy StayFresh timestamp records are parsed and normalized on read.

## Development

Current validated environment:

- Ubuntu 24.04
- Flutter 3.47.0 stable
- Dart 3.13.0

Typical validation commands:

```bash
flutter pub get
flutter test
dart analyze
flutter build linux
```

The iOS project can be statically maintained from Linux, but an actual iOS build, signing, and TestFlight verification require macOS/Xcode.

## Project history

FreshFlag was bootstrapped from the MIT-licensed StayFresh repository while preserving its Git history. FreshFlag is maintained as an independent repository rather than a GitHub fork. See `UPSTREAM.md` and `docs/BASELINE_AUDIT.md` for provenance and audit findings.

## Important project log

`CHANGELOG.md` is the persistent engineering log. It records each major implementation, validation result, blocker, and architectural decision so project work can resume without repeating prior investigation.
