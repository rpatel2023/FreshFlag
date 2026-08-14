# FreshFlag Architecture

FreshFlag is a Flutter client backed by Firebase. This document describes the implemented architecture; product intent remains defined by `PROJECT_CONTEXT.md` and implementation history by `CHANGELOG.md`.

## Core loop

`scan -> recognize product -> set expiry -> household inventory -> backend reminder -> consume/remove`

## Client

- Flutter / Dart.
- Firebase Authentication: email/password.
- Cloud Firestore: household state, members, inventory, notification rules, device registrations, invites.
- Firebase Cloud Messaging: push registration and notification-tap handling where the iOS signing path exposes the required capability.
- Firebase callable Functions: authenticated per-user Discord integration status/save/test operations.
- `mobile_scanner`: retail barcode capture.
- Open Food Facts: packaged-product metadata lookup.
- `provider` + ViewModels for authenticated household/inventory state.
- Persisted light/dark theme selection through `SharedPreferences`.

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
        -> determine household members
        -> for each member
             +------------------------+
             |                        |
             v                        v
          FCM delivery           personal Discord webhook
          recipient devices      when that user enabled it
             |
             v
          APNs/device push
          when signing permits
```

The scheduled worker runs every five minutes and evaluates each rule in the household IANA timezone. Household rules decide when and what should be sent; each member independently chooses which personal delivery channels they use.

FCM recipient delivery identity is deterministic from:

```text
householdId + itemId + ruleId + expiryDate + recipientUid
```

Discord uses a channel-specific deterministic identity containing the same household/item/rule/expiry/recipient tuple plus a Discord discriminator. This gives each member one Discord delivery without collisions with FCM or another member's Discord delivery.

`notificationDeliveries/{deliveryId}` is backend-managed and client-denied. Claims use a lease to prevent duplicate sends while allowing recovery after a stale/crashed claim.

Each installation stores a stable random `deviceId` locally and writes its current FCM token under:

```text
users/{uid}/devices/{deviceId}
```

The backend honors the user's FCM `notificationsEnabled` preference, drops invalid FCM registrations, and prunes stale registrations. Discord has a separate enabled preference and remains independent of FCM opt-out/device availability.

## Discord integration

Each FreshFlag user may configure one personal Discord incoming webhook stored in backend-only:

```text
userIntegrations/{uid}
```

Regular Firestore clients cannot read or write this collection, including the user who owns the integration. The signed-in user instead uses authenticated callable Functions to:

- read their configured/enabled status without receiving the secret;
- save/replace and enable/disable their own webhook;
- send a test message to their own destination.

No household-owner permission is required for personal Discord configuration. A household member may enable Discord even if the household owner does not, and different members may point to different Discord channels.

Webhook URLs are normalized and restricted to HTTPS Discord webhook hosts/paths before storage/use. Discord payloads disable `allowed_mentions` so user-controlled item/template text cannot trigger mass mentions.

Discord is a parallel production reminder channel, not an FCM-error fallback. This is important for the zero-fee SideStore/free-Apple-Account distribution path, where native APNs entitlement behavior cannot be assumed.

The abandoned `householdIntegrations/{householdId}` path remains explicitly client-denied so accidental old development data cannot expose secrets.

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

## Dark mode

`ThemeProvider` persists the user's dark-mode choice with `SharedPreferences`. `MaterialApp` switches between FreshFlag light/dark `ThemeData`, and the core auth, household, inventory, reminder, item-detail, Settings, and Discord screens inherit the active color scheme rather than forcing light-only scaffold/card colors.

## Security

Firestore rules are application logic. Emulator-backed tests cover:

- member vs outsider household reads;
- owner-only notification-rule administration;
- self-only device registration;
- valid invite self-join;
- revoked/expired invite rejection;
- owner escalation rejection;
- cross-household item-write rejection;
- client denial of notification-delivery records;
- client denial of backend-only per-user integration secrets, including the user's own webhook document.

## Backend

`functions/` is a Node 22 TypeScript Firebase Functions v2 package. Top-level dependency versions are pinned. `security-tests/` runs Firestore Emulator authorization tests.

The backend contains:

- scheduled expiry-reminder processing;
- per-recipient FCM delivery;
- per-recipient Discord webhook delivery;
- authenticated per-user Discord integration management/test endpoints;
- stale-device pruning;
- deterministic delivery claims/ledger handling.

## CI

- Flutter CI: PR-only (plus manual dispatch), client-path filtered.
- Backend CI: PR-only (plus manual dispatch), backend-path filtered.
- Feature-branch pushes do not run Actions automatically outside an open PR synchronize event.
- Avoid standalone documentation/source commits on an open PR when they would create unnecessary private-repo reruns; record final milestone documentation on `main` after validated merges where practical.

## iOS/private distribution status

Source implementation is complete through per-user Discord fallback, dark mode, and native notification deep linking. Production iPhone use remains gated by external Phase 8 configuration:

- FreshFlag-owned Firebase project/app configuration;
- bundle identifier `com.rpatel2023.freshflag`;
- deploy Firestore rules and Functions;
- modern Flutter Swift Package Manager migration/build on macOS/Xcode;
- create an iOS artifact suitable for private sideloading;
- bootstrap SideStore/free Apple Account on the two target iPhones;
- configure and physically validate each user's Discord reminder destination;
- physically validate camera, realtime household sharing, and item lifecycle;
- test APNs/FCM if the chosen free signing path provides the capability, but do not make native push mandatory for the zero-fee build.

TestFlight/App Store Connect remains an optional later distribution path rather than an MVP requirement. If chosen later, Apple Developer Program signing, APNs production configuration, privacy/beta metadata, archive, and upload become separate release gates.

See `docs/testflight.md` for the existing platform procedure; it should be read together with `PROJECT_CONTEXT.md` for the current SideStore-first distribution decision.
