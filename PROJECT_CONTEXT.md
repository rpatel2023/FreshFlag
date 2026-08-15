# FreshFlag — Project Context & Product Source of Truth

> Primary target: iPhone / private household sideload via SideStore  
> Optional later distribution: TestFlight / App Store Connect  
> Client: Flutter  
> Backend: Firebase  
> Product: shared household food-expiry tracking  
> Implementation history: `CHANGELOG.md`  
> Implemented architecture: `ARCHITECTURE.md`  
> Active iOS distribution procedure: `docs/sideload.md`

This document defines what FreshFlag is and the constraints future implementation must preserve. When source code and this document disagree about product intent, treat this document as authoritative unless a deliberate decision is recorded in `CHANGELOG.md` and reflected here.

## Product objective

FreshFlag helps a household track food expiry with the smallest useful loop:

```text
SCAN
  -> recognize product
  -> SET EXPIRY
  -> SHARE WITH HOUSEHOLD
  -> GET REMINDED
  -> CONSUME / REMOVE
```

Everything else is secondary until that loop is reliable across multiple real iPhones.

FreshFlag is not an ERP, recipe platform, meal planner, nutrition tracker, budgeting system, grocery-store integration, or general household-management suite for the MVP.

## MVP definition of done

The MVP is complete only when this scenario works reliably:

1. User A installs a FreshFlag iOS build through the chosen private distribution path (SideStore/free Apple Account first; TestFlight remains optional later).
2. User A creates/signs into an account.
3. User A creates a household.
4. User A shares a household invite.
5. User B installs/signs in and joins that household.
6. User A scans a packaged-food barcode.
7. Product details are populated when Open Food Facts knows the barcode.
8. User A enters an expiry date.
9. The item appears on both phones without manual refresh.
10. The household has a custom reminder rule.
11. The backend evaluates the rule in the household timezone.
12. Each participating household member can receive the intended reminder through at least one production-capable personal channel; per-user Discord is the supported channel for the zero-fee SideStore profile.
13. In a future standard/paid Apple distribution profile, FCM/APNs may also deliver reminders and notification taps must open the correct household item.
14. Either member marks the item consumed/removed.
15. Both phones reflect the updated shared state.

Source CI alone does not satisfy this definition; the final scenario must pass on physical devices.

## Accounts

MVP authentication:

- Firebase Authentication;
- email/password;
- persistent signed-in session;
- sign out;
- one or more devices per user.

Additional providers such as Sign in with Apple or Google are post-MVP unless a later distribution path forces a change.

## Household ownership invariant

Inventory belongs to a household, never directly to an individual user.

Incorrect:

```text
users/{uid}/items
```

Correct:

```text
households/{householdId}/items
```

Items still carry creator/updater audit fields.

MVP roles:

- `owner`: household administration, invites, notification-rule management;
- `member`: inventory management and rule viewing.

The model may support multiple households even if the UX emphasizes one active household.

## Household capabilities

Users must be able to:

- create and name a household;
- join through an invite;
- switch accessible households;
- see shared inventory in real time.

Owners must be able to create/revoke invitations and manage notification rules.

Member removal, leaving a household, ownership transfer, and richer household administration are valid follow-up work if not complete in the first private iPhone build, but the data/security model must not prevent them.

## Invitations

MVP invitations are shareable codes/links rather than transactional email.

Properties:

- non-enumerable secret/code;
- expiration;
- revocation;
- acceptance only by a signed-in user;
- acceptance must validate the real invite rather than trusting a client-provided household ID;
- the joining user may create only their own membership and may never self-promote to owner.

An iOS share sheet is preferred when link sharing is added.

## Barcode scanning

FreshFlag should support common retail barcode formats provided by the chosen scanner, including UPC/EAN families.

Barcode scanning must never be mandatory. Manual item entry must always remain available.

Expected flow:

```text
scan barcode
  -> normalize barcode
  -> product lookup
  -> recognized: prefill Add Item
  -> unknown/error: manual Add Item with barcode retained
```

A barcode identifies product metadata, not a unique physical inventory instance. Two packages with the same barcode but different expiry dates are separate inventory items.

## Product lookup

Primary metadata source: Open Food Facts.

Only fetch/store fields useful to expiry tracking, initially:

- barcode;
- product name;
- brand where useful;
- image URL where useful;
- category where useful.

Do not turn FreshFlag into a nutrition database merely because the external API exposes nutritional fields.

Lookup/network failure must never block adding an item.

A future `productCache/{normalizedBarcode}` can reduce duplicate external requests. Inventory records should copy the display fields they need so later public-database changes do not unexpectedly rewrite household history or user overrides.

## Inventory item model

Required conceptual fields:

- `id`;
- `householdId`;
- `name`;
- `expiryDate`;
- `createdAt` / creator;
- `updatedAt` / updater.

Useful optional fields:

- barcode;
- brand;
- image URL;
- quantity/unit;
- location;
- purchase date;
- notes.

Suggested locations:

- Pantry;
- Fridge;
- Freezer;
- custom/Other.

Location and quantity must not slow the common scan -> expiry -> add flow.

## Expiry dates

Expiry is a calendar date, not an instant.

Persist it as:

```text
YYYY-MM-DD
```

Do not store an arbitrary midnight UTC timestamp and depend on timezone conversion.

Expiry UI state is derived from the expiry date. Default expiring-soon threshold is conceptually three days and is independent from notification-rule timing.

Default inventory ordering should prioritize active items with the earliest expiry first.

## Item lifecycle

MVP must support active and consumed/removed state. Prefer a soft lifecycle that leaves room for later waste analytics rather than destructive deletion everywhere.

Future lifecycle values may include:

```text
active
consumed
discarded
deleted
```

Do not build analytics before the core loop is stable.

## Shared realtime state

Firestore realtime listeners are the intended synchronization mechanism.

Example:

```text
User A adds milk
  -> household Firestore changes
  -> User B receives snapshot
  -> milk appears without refresh
```

All inventory operations must be scoped to a household the authenticated user is authorized to access.

## Notifications are a core feature

Notifications are backend-authoritative because local scheduling on the phone that added an item cannot reliably notify the whole household.

Implemented architecture:

```text
Firestore items + household rules
  -> scheduled Firebase Function
  -> determine due household members
  -> for each member
       +--------------------+
       |                    |
       v                    v
 FCM/APNs (standard)    personal Discord webhook
 paid/profile path      if that member enabled it
```

Discord is a parallel personal reminder channel, not merely an error fallback after an FCM API call.

For the zero-fee SideStore/free-Apple-Account distribution profile, remote APNs/FCM is deliberately disabled by product policy. The build uses:

```text
--dart-define=FRESHFLAG_SIDESTORE=true
```

That profile must not register or initialize FCM, generate/request FCM tokens, write device tokens, subscribe to FCM notification taps, or let push state block startup/authentication/household loading. `FirebaseMessagingAutoInitEnabled` remains false in the iOS plist. The Push notifications Settings control is disabled and explains that Discord is the supported reminder path.

A future standard/paid Apple distribution profile may omit the SideStore define and use the retained FCM path only after the required Apple Push Notifications/background capabilities and APNs credentials are configured.

Do not reintroduce client-only expiry scheduling as the authoritative reminder path.

## Discord reminder channel

For the zero-fee private distribution profile, Discord is the supported production reminder channel.

Properties:

- one Discord incoming webhook per FreshFlag user;
- each signed-in user manages only their own integration through authenticated callable Functions;
- webhook URL stored only in backend-owned `userIntegrations/{uid}`;
- regular clients, including the user who owns the integration, cannot read/write the secret directly;
- no household-owner permission is required for personal Discord configuration;
- different household members may use different Discord destinations or opt out independently;
- webhook URLs are restricted to valid Discord HTTPS webhook hosts/paths;
- `allowed_mentions` is disabled for user-derived reminder text;
- one Discord reminder is emitted per household/item/rule/expiry/recipient event;
- Discord has its own deterministic delivery identity/ledger claim independent of FCM recipient delivery IDs.

Discord configuration lives in personal Settings and includes save/replace, enable/disable, status, and a test-message action. The abandoned `householdIntegrations/{householdId}` collection remains explicitly client-denied for safety but is no longer part of the active design.

## Notification rules

Households can define rules such as:

```text
7 days before: Use {item} this week — it expires on {expiry_date}
3 days before: {item} expires in {days} days
1 day before: {item} expires tomorrow
0 days before: {item} expires today
```

MVP rule fields conceptually include:

- rule ID;
- household ID;
- enabled;
- days before expiry;
- household-local send time (`HH:mm`);
- title template;
- body template;
- audit timestamps/UIDs.

Initial template variables:

```text
{item}
{days}
{expiry_date}
{quantity}
{location}
```

Missing optional data must degrade gracefully.

Recommended defaults for a newly created household are 3-day, 1-day, and expiry-day reminders, but defaults are editable product configuration, not a permanent hardcoded limitation.

## Timezones

MVP notification semantics use one IANA timezone per household, for example:

```text
America/Toronto
```

Multi-timezone per-user reminder semantics are post-MVP.

## Notification idempotency

Duplicate worker executions must not duplicate a reminder.

FCM recipient delivery identity is deterministically derived from exactly:

```text
householdId + itemId + ruleId + expiryDate + recipientUid
```

Discord uses a separate deterministic channel-specific ID derived from the same household/item/rule/expiry/recipient tuple plus a Discord discriminator.

The backend owns `notificationDeliveries`. Regular clients must not forge delivery records.

Changing an item's expiry naturally yields a new identity while the old expiry no longer qualifies.

## Device registration

For a standard/paid profile that enables FCM, device registrations live under:

```text
users/{uid}/devices/{deviceId}
```

A registration stores at least:

- stable installation/device identifier;
- platform;
- current FCM token;
- last-seen timestamp.

The app refreshes token state and the backend removes invalid/stale registrations where practical. Regular users must never read or modify other users' device registrations.

The SideStore profile does not create/update FCM device registrations.

## Notification tap behavior

Expiry FCM data must include at least:

```json
{
  "type": "expiry",
  "householdId": "...",
  "itemId": "..."
}
```

Desired behavior in the standard/paid profile:

```text
notification tap
  -> app/session ready
  -> verify household access
  -> switch household if required
  -> open exact item detail
```

This must be physically tested with the app foreground, background, and terminated only when a future distribution profile actually enables native push. It is not a SideStore MVP release gate.

## Dark mode

FreshFlag provides a persisted app-level dark-mode toggle in Settings using `SharedPreferences`. The Material theme, core authenticated screens, auth screens, household setup/sharing, inventory, reminders, reminder rules, item details, and Discord settings must all honor the active theme rather than forcing light-only colors.

## Firebase security invariants

Security rules are application logic, not optional hardening.

At minimum:

1. non-members cannot read a household or its inventory;
2. members can manage authorized inventory but cannot modify protected owner fields;
3. members cannot self-promote to owner;
4. a user cannot add arbitrary other users through the invite flow;
5. users can modify only their own device records;
6. device tokens are not publicly readable;
7. notification deliveries are backend-managed;
8. invite acceptance validates a real active invite;
9. server-owned fields are not freely client-writable;
10. integration secrets such as Discord webhook URLs are backend-only and client-denied, even from the user whose integration document contains the secret.

Use Firebase Emulator tests for these boundaries.

## Offline behavior

Basic offline usability is desirable but not an MVP blocker. Firestore's own local persistence should be preferred before inventing a custom synchronization engine.

Possible later behavior:

- view previously loaded inventory offline;
- queue writes while offline;
- cache known product metadata.

## UX principles

Optimize for putting food away quickly.

Preferred common flow:

```text
scan -> recognized product -> expiry date -> Add
```

Quantity, location, notes, purchase date, and similar fields should remain optional or progressively disclosed.

Expiry state must not be communicated by color alone; include text/icons. Maintain reasonable iOS Dynamic Type behavior.

Ask for camera permission when scanning is first used. In a standard/paid profile, ask for notifications when the benefit is clear rather than automatically at cold launch. The SideStore profile must not ask for push permission.

## Technology decisions

- Flutter client; no Swift rewrite for the MVP.
- Firebase Auth + Firestore + Functions/Scheduler + Emulator Suite; FCM retained for the standard/paid distribution profile.
- Discord incoming webhooks as the per-user zero-fee reminder channel.
- Open Food Facts for packaged-product lookup.
- Household-owned inventory.
- Date-only expiry values.
- Backend-owned shared reminder timing with per-user delivery channels.
- SideStore/free Apple Account as the first private iPhone distribution path; compile it with `FRESHFLAG_SIDESTORE=true` and no APNs/FCM runtime dependency.
- TestFlight is optional later rather than an MVP requirement.
- Permissive/MIT-compatible source strategy.

Do not add a second backend such as Supabase without an explicit recorded reason.

## Open-source provenance

Primary imported scaffold:

- `Dhiraj706Sardar/stayfresh` — MIT.

Important implementation/reference source:

- `Thigas-Tech/pantry_app` — MIT.

Conceptual/reference sources:

- Grocy — MIT;
- Grocy SwiftUI — GPL-3.0, reference only unless licensing changes;
- KitchenOwl — AGPL-3.0, reference only unless licensing changes.

Do not copy GPL/AGPL source into the intended permissive codebase casually. Record material third-party use in `THIRD_PARTY_NOTICES.md`.

## MVP non-goals

Do not delay the core loop for:

- recipes or AI recipes;
- meal planning;
- nutrition/calorie tracking;
- grocery price comparison/ordering;
- budgeting;
- OCR expiry-date recognition;
- receipt scanning;
- social features;
- smart-fridge/Home Assistant integrations;
- complex waste analytics;
- web administration;
- Android release.

## Future features worth preserving room for

After MVP:

- per-user notification subscriptions/quiet hours;
- OCR expiry-date capture with confirmation;
- Siri/Shortcuts;
- iOS widgets;
- consumed vs discarded waste tracking;
- shopping-list suggestions;
- richer multi-household administration.

## Engineering rules

For every meaningful implementation change:

- keep `CHANGELOG.md` current;
- add/update tests for domain logic;
- keep `dart analyze` clean;
- keep tests passing;
- keep build state reproducible;
- avoid unnecessary dependencies;
- avoid unnecessary CI runs on private-repo feature commits;
- do not broaden scope silently.

Particularly test:

- date-only expiry calculations;
- barcode/product parsing;
- notification template rendering;
- notification eligibility/timezone windows;
- idempotency identities;
- household/invite authorization;
- notification-target parsing/deep links in the standard/paid profile;
- Discord webhook validation, per-recipient identity, and backend-only integration-secret access;
- SideStore profile capability guards and non-blocking startup/auth paths;
- light/dark theme regression behavior.

## Phase map

- Phase 0: upstream audit/baseline — complete.
- Phase 1: trustworthy single-user inventory — complete.
- Phase 2: barcode/Open Food Facts recognition — complete initial slice.
- Phase 3: household-owned real-time inventory — complete.
- Phase 4: invitations — complete MVP join flow.
- Phase 5: configurable notification rules/device registration — complete source.
- Phase 6: backend scheduled reminder worker/security harness — complete and deployed to production Firebase.
- Phase 7: notification deep linking/item detail — complete source for standard/paid FCM profile; physical native-push validation deferred until that profile is used.
- Phase 8: production Firebase configuration/deployment — complete; SideStore build/physical testing — active.
- Per-user Discord reminder channel and app-wide dark mode — source implementation complete; physical-device acceptance remains.

## Phase 8 release gate

Completed prerequisites:

- FreshFlag-owned Firebase project/app configured;
- unique bundle identifier `com.rpatel2023.freshflag` registered with Firebase;
- production FlutterFire iOS configuration present;
- Firestore rules and Cloud Functions deployed;
- Firebase Authentication email/password and Firestore enabled;
- unsigned iOS artifact workflow proven on macOS 14/Xcode 15.4;
- Windows Apple device stack and initial SideStore bootstrap proven on the first target iPhone;
- first FreshFlag IPA successfully signed/installed through `iloader`;
- first-device white-screen failure diagnosed as FCM-before-`runApp()` behavior;
- SideStore/Personal-Team codebase audit completed and source-validated; zero-fee profile explicitly disables APNs/FCM;
- PR #13 SideStore hardening merged to `main` as `35650bab5bebb0c0fa6bdbded91f926a919dd473`.

Remaining before the first private household release:

- build a new IPA from current `main` using `FRESHFLAG_SIDESTORE=true` and all capability guards;
- update/adopt FreshFlag through SideStore without deleting the existing installation;
- prove FreshFlag reaches authentication promptly on the physical iPhone;
- prove email/password signup/login and session persistence;
- prove household create/invite/join across the two real iPhones;
- prove recognized barcode scan, unknown/manual fallback, expiry/location persistence, realtime shared inventory and consume/restore lifecycle;
- configure each user's personal Discord webhook and prove test plus scheduled due reminders arrive independently;
- prove FreshFlag refresh/update through SideStore preserves the expected app data across the 7-day Personal-Team lifecycle;
- if the project later moves to TestFlight/App Store distribution, complete Apple Developer Program signing, Push Notifications/background capability, APNs production credentials, App Store Connect privacy/beta metadata, archive, upload, and native-push acceptance testing.

When implementation choices become unclear, choose the option that makes the core loop faster, more secure, and more reliable rather than expanding the product surface.
