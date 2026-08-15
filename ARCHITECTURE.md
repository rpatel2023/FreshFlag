# FreshFlag Architecture

FreshFlag is a Flutter client backed by Firebase. This document describes the implemented architecture; product intent remains defined by `PROJECT_CONTEXT.md` and implementation history by `CHANGELOG.md`.

## Core loop

`scan -> recognize product -> set expiry -> household inventory -> backend reminder -> consume/remove`

## Client

- Flutter / Dart.
- Firebase Authentication: email/password.
- Cloud Firestore: household state, members, inventory, notification rules, device registrations, invites.
- Firebase Cloud Messaging: retained for a standard/paid Apple distribution profile; deliberately disabled in the SideStore Personal-Team profile.
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

Core authenticated loading never waits for FCM/APNs registration. In the SideStore profile no FCM device registration is attempted at all.

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
      FCM delivery             personal Discord webhook
      standard/paid profile    when that user enabled it
             |
             v
          APNs/device push
```

The scheduled worker runs every five minutes and evaluates each rule in the household IANA timezone. Household rules decide when and what should be sent; each member independently chooses which personal delivery channels they use.

The zero-fee SideStore profile is compiled with:

```text
--dart-define=FRESHFLAG_SIDESTORE=true
```

In that profile APNs/FCM is deliberately unavailable by product policy rather than probed opportunistically at runtime. Firebase Messaging token auto-initialization is disabled in `Info.plist`; the Dart app does not register the FCM background handler, initialize FCM, request an FCM token, write a device token, or subscribe the authenticated shell to FCM notification taps. The Push notifications control is disabled and directs the user to Discord reminders.

A future paid/TestFlight build can omit the SideStore define and use the retained FCM path after the required Apple Push Notifications/background capabilities and APNs credentials are configured.

FCM recipient delivery identity is deterministic from:

```text
householdId + itemId + ruleId + expiryDate + recipientUid
```

Discord uses a channel-specific deterministic identity containing the same household/item/rule/expiry/recipient tuple plus a Discord discriminator. This gives each member one Discord delivery without collisions with FCM or another member's Discord delivery.

`notificationDeliveries/{deliveryId}` is backend-managed and client-denied. Claims use a lease to prevent duplicate sends while allowing recovery after a stale/crashed claim.

For a standard/paid build, each installation stores a stable random `deviceId` locally and may write its current FCM token under:

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

Discord is the supported production reminder channel for the zero-fee SideStore/free-Apple-Account profile. It is also available in the standard/paid profile independently of FCM.

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

In a standard/paid build, the client buffers terminated-launch targets, listens for background taps, verifies household access, switches households if needed, fetches the scoped item, and opens the shared item-detail screen. Legacy `expiry_reminder` payloads remain accepted during migration.

The SideStore profile does not instantiate this FCM tap path because remote push is disabled there.

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
- per-recipient FCM delivery for registered standard/paid-profile devices;
- per-recipient Discord webhook delivery;
- authenticated per-user Discord integration management/test endpoints;
- stale-device pruning;
- deterministic delivery claims/ledger handling.

## CI

- Flutter CI: PR-only (plus manual dispatch), client-path filtered.
- Backend CI: PR-only (plus manual dispatch), backend-path filtered.
- Feature-branch pushes do not run Actions automatically outside an open PR synchronize event.
- SideStore IPA workflow: manual `workflow_dispatch` only, macOS 14/Xcode 15.4, compiled with `FRESHFLAG_SIDESTORE=true`.
- The SideStore workflow fails closed if Runner entitlements/Xcode capabilities or app extensions are introduced, verifies Firebase Messaging auto-init remains disabled, and verifies the application/Firebase bundle IDs match.

## iOS/private distribution status

Production Firebase project configuration, Firestore rules, Cloud Functions deployment, the first successful unsigned IPA build, and the Windows/SideStore bootstrap have been completed.

The first physical FreshFlag install succeeded through `iloader`, but its first launch exposed a white-screen startup blocker because FCM token work was awaited before Flutter rendered. A dedicated SideStore/Personal-Team audit then hardened the zero-fee distribution profile and documented the result in `docs/SIDESTORE_COMPATIBILITY_AUDIT.md`.

Current next gates are:

- merge the source-validated SideStore hardening;
- build a new SideStore-profile IPA;
- update/adopt FreshFlag through SideStore without deleting the existing app;
- verify fresh launch reaches authentication promptly;
- physically validate Firebase email/password auth, household creation/join, camera scan/manual fallback, expiry/location persistence, realtime household sharing, item lifecycle, and each user's personal Discord reminder destination;
- verify SideStore refresh/update preserves the installed app/data through the normal 7-day Personal-Team cycle.

Native FCM/APNs is not a release gate for the zero-fee SideStore profile. It becomes a separate gate only for a future paid/TestFlight distribution profile.

TestFlight/App Store Connect remains an optional later distribution path rather than an MVP requirement. If chosen later, Apple Developer Program signing, APNs production configuration, privacy/beta metadata, archive, and upload become separate release gates.

See `docs/sideload.md` for the active zero-fee procedure and `docs/testflight.md` for the optional later paid path.
