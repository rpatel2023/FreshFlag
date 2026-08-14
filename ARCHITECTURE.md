# FreshFlag Architecture

FreshFlag is a Flutter client backed by Firebase. This document describes the implemented architecture; product intent remains defined by `PROJECT_CONTEXT.md` and implementation history by `CHANGELOG.md`.

## Core loop

`scan -> recognize product -> set expiry -> household inventory -> backend reminder -> consume/remove`

## Client

- Flutter / Dart.
- Firebase Authentication: email/password.
- Cloud Firestore: household state, members, inventory, notification rules, device registrations, invites.
- Firebase Cloud Messaging: push registration and notification-tap handling.
- `mobile_scanner`: retail barcode capture.
- Open Food Facts: packaged-product metadata lookup.
- `provider` + ViewModels for authenticated household/inventory state.

### Authoritative state

Inventory belongs to a household, never directly to a user:

```text
households/{householdId}
  members/{uid}
  items/{itemId}
  notificationRules/{ruleId}
```

The selected household is bound to a Firestore snapshot stream so inventory updates propagate in real time between members.

### Expiry representation

`expiryDate` is a calendar date serialized as ISO `YYYY-MM-DD`. It is not stored as a timezone-dependent midnight timestamp.

## Authentication and household flow

1. Firebase Auth establishes the user session.
2. `HouseholdViewModel` loads memberships and selects the preferred/current household.
3. `GroceryViewModel` binds Firestore inventory for that household.
4. Security rules independently verify membership and owner-only operations.

Roles are intentionally minimal: `owner` and `member`.

## Invitations

Owners create non-enumerable 12-character invite codes in `invites/{code}`. A signed-in recipient reads the exact invite document and performs a constrained self-join batch. Firestore Emulator tests prove invalid/revoked/expired invites and owner escalation are rejected.

## Product recognition

A completed scan performs one Open Food Facts lookup. Recognized products prefill Add Item. Network failures, incomplete records, and unknown barcodes fall back to manual entry while retaining the barcode.

## Notification architecture

Expiry reminders are backend-driven only. The client does not schedule authoritative per-item local expiry notifications.

```text
Firestore household/items/rules
        -> scheduled Cloud Function
        -> deterministic delivery claim
        -> FCM multicast to recipient devices
        -> APNs / device notification
```

The scheduled worker runs every five minutes and evaluates each rule in the household IANA timezone.

Delivery identity is deterministic from:

```text
householdId + itemId + ruleId + expiryDate + recipientUid
```

`notificationDeliveries/{deliveryId}` is backend-managed and client-denied. Claims use a lease to prevent duplicate sends while allowing recovery after a stale/crashed claim.

Each installation stores a stable random `deviceId` locally and writes its current FCM token under:

```text
users/{uid}/devices/{deviceId}
```

The backend honors `notificationsEnabled`, drops invalid FCM registrations, and prunes stale registrations.

## Notification deep linking

Expiry FCM data payloads include:

```json
{
  "type": "expiry",
  "householdId": "...",
  "itemId": "..."
}
```

The client buffers terminated-launch targets, listens for background taps, verifies household access, switches households if needed, fetches the scoped item, and opens the shared item-detail screen. Legacy `expiry_reminder` payloads remain accepted during migration.

## Security

Firestore rules are application logic. Emulator-backed tests cover:

- member vs outsider household reads;
- owner-only notification-rule administration;
- self-only device registration;
- valid invite self-join;
- revoked/expired invite rejection;
- owner escalation rejection;
- cross-household item-write rejection;
- client denial of notification-delivery records.

## Backend

`functions/` is a Node 22 TypeScript Firebase Functions v2 package. Top-level dependency versions are pinned. `security-tests/` runs Firestore Emulator authorization tests.

## CI

- Flutter CI: PR-only (plus manual dispatch), client-path filtered.
- Backend CI: PR-only (plus manual dispatch), backend-path filtered.
- Feature-branch pushes do not run Actions automatically.

## iOS/TestFlight status

The Flutter product source is implemented through notification deep linking. Production iOS remains gated by Phase 8 platform configuration:

- unique FreshFlag bundle identifier and Apple signing;
- FreshFlag-owned Firebase project/app configuration;
- modern Flutter Swift Package Manager migration on macOS/Xcode;
- APNs/FCM configuration;
- fresh app icon/splash assets;
- physical-iPhone camera, realtime household, push, and notification-tap validation;
- App Store Connect/TestFlight upload and privacy metadata.

See `docs/testflight.md` for the release procedure.
