# Household Food Expiry Tracker — Project Context & Development Source

> **Status:** Initial project definition  
> **Last researched/validated:** 2026-08-13  
> **Primary target:** iPhone / TestFlight  
> **Client framework:** Flutter  
> **Backend:** Firebase  
> **Working name:** Household Food Expiry Tracker  
> **Primary open-source starting point:** `Dhiraj706Sardar/stayfresh`  
> **Secondary implementation reference:** `Thigas-Tech/pantry_app`

---

## 1. Purpose of this document

This file is the source of truth for the first implementation of the project.

It is intended to be usable by:

- a human developer;
- Claude Code, OpenCode, Codex, or another coding agent;
- a future contributor who has no prior conversation context.

The implementation should not drift away from the product described here without an explicit decision being recorded in this file.

The core product is deliberately narrow:

> A household member scans a food product, confirms or enters its expiry date, and the item becomes visible to the household. Household members receive configurable notifications before the item expires.

This is **not** intended to become a general household ERP, meal-planning platform, recipe manager, budgeting system, or grocery-store application during the initial development phases.

---

# 2. Product objective

Build an iPhone application that allows a household to keep a shared inventory of food with expiry dates.

The primary user flow is:

```text
Open app
   ↓
Scan barcode
   ↓
Recognize product
   ↓
Enter/confirm expiry date
   ↓
Add to household inventory
   ↓
All household members see item
   ↓
Notification rules are evaluated
   ↓
Members receive expiry reminders
```

The application should eventually be distributed through Apple TestFlight and be suitable for App Store distribution if desired later.

---

# 3. Required MVP capabilities

The first usable TestFlight version must support the following.

## 3.1 Accounts

Users must be able to:

- create an account;
- sign in;
- sign out;
- remain signed in between launches;
- have one or more registered iOS devices.

Initial authentication method:

- email/password through Firebase Authentication.

Possible later additions:

- Sign in with Apple;
- Google sign-in.

Do not delay the MVP for additional sign-in providers.

---

## 3.2 Household

A user must be able to:

- create a household;
- name the household;
- invite another person;
- join a household using an invitation;
- view household members;
- leave a household;
- remove a member if they are the owner/admin.

A household owns the inventory.

**Items must not belong directly to an individual user.**

This is one of the most important architectural rules in the project.

Incorrect model:

```text
user
 └── items
```

Correct model:

```text
household
 ├── members
 └── items
```

Each item still records who created or modified it for audit/history purposes.

---

## 3.3 Barcode scanning

The application must support:

- UPC-A;
- UPC-E where supported;
- EAN-8;
- EAN-13;
- other common retail formats supported by the chosen scanner library.

Primary behavior:

```text
scan barcode
   ↓
search product cache
   ↓
if not cached, query Open Food Facts
   ↓
if product exists:
    pre-fill details
else:
    allow manual product creation
```

Barcode scanning must never be a hard requirement for adding an item.

Manual item creation must always remain possible.

---

# 4. Product lookup

Primary product metadata service:

## Open Food Facts

Repository/reference:

`https://world.openfoodfacts.org/`

The initial app only needs a limited subset of returned data:

- barcode;
- product name;
- brand;
- product image URL if available;
- category if useful.

Do not initially import every nutritional or ingredient field just because the API exposes it.

The app is an expiry tracker, not a nutrition database.

### Lookup behavior

1. User scans a barcode.
2. App normalizes barcode.
3. App checks the product cache.
4. If cache miss and internet is available, query Open Food Facts.
5. If found, populate the Add Item form.
6. If not found, show the manual product form.
7. A failed lookup must never prevent the user from adding the item.

---

# 5. Adding an inventory item

The fastest common flow should require very little typing.

Ideal flow:

```text
Scan barcode
↓
"Natrel 2% Milk" found
↓
Choose/enter expiry date
↓
Add
```

The user should not be forced through unnecessary screens.

## Required item fields

Minimum:

- `id`
- `householdId`
- `name`
- `expiryDate`
- `createdAt`
- `createdBy`
- `updatedAt`
- `updatedBy`

Optional:

- `barcode`
- `brand`
- `imageUrl`
- `quantity`
- `unit`
- `location`
- `purchaseDate`
- `notes`

Possible locations:

- Pantry
- Fridge
- Freezer
- Other/custom

Do not make location mandatory for MVP.

---

# 6. Expiry-date representation

Expiry dates are **calendar dates**, not moments in time.

This matters.

Do not store an expiry date as an arbitrary midnight UTC timestamp and then depend on timezone conversion.

Preferred representation:

```json
{
  "expiryDate": "2026-08-25"
}
```

Use ISO `YYYY-MM-DD`.

This avoids:

- an expiry date moving backward a day due to timezone conversion;
- inconsistent comparisons between devices;
- strange behavior when daylight-saving rules change.

A timestamp may be derived server-side when notification execution is required.

---

# 7. Inventory states

Status should normally be derived rather than permanently stored.

Example:

```text
expiryDate < today
    → expired

expiryDate - today <= household.expiringSoonDays
    → expiringSoon

otherwise
    → good
```

Default `expiringSoonDays`:

```text
3
```

This value is independent of notification rules.

The UI should support at least:

- All
- Expiring Soon
- Expired

Useful future filters:

- Fridge
- Freezer
- Pantry
- Added by
- Date added

---

# 8. Item lifecycle

Users must eventually be able to mark an item as:

- active;
- consumed;
- discarded;
- expired;
- deleted.

For the first MVP, at minimum:

- active;
- consumed/removed.

Prefer a soft-state lifecycle over destructive deletion when practical.

Example fields:

```json
{
  "state": "active",
  "removedReason": null,
  "removedAt": null
}
```

Possible values:

```text
active
consumed
discarded
deleted
```

This gives the project a path toward future food-waste analytics without redesigning the data model.

Do not build analytics in the MVP.

---

# 9. Shared realtime inventory

Household inventory must update across devices without a manual refresh.

Example:

```text
Raj scans milk
        ↓
Firestore household inventory changes
        ↓
Spouse's app receives snapshot update
        ↓
Milk appears automatically
```

Firestore realtime listeners are the intended mechanism.

Every item query must be scoped through a household the current user is authorized to access.

---

# 10. Notifications — core requirement

Notifications are not a cosmetic feature. They are one of the main purposes of the application.

The system must allow the household to define rules such as:

```text
7 days before
"Use {item} this week — it expires on {expiry_date}"

3 days before
"{item} expires in {days} days"

1 day before
"{item} expires tomorrow"

0 days before
"{item} expires today"
```

The number of days and the message must be configurable.

---

# 11. Notification template variables

Initial supported variables:

```text
{item}
{days}
{expiry_date}
{quantity}
{location}
```

Potential future variables:

```text
{brand}
{household}
{added_by}
```

Unknown/missing variables must degrade gracefully.

Example:

Template:

```text
"{item} in the {location} expires in {days} days"
```

Output:

```text
"Amul Paneer in the fridge expires in 3 days"
```

If location is absent, the rendering layer should avoid producing obviously broken text where possible.

---

# 12. Notification rule data model

Example:

```json
{
  "id": "rule_abc",
  "householdId": "house_123",
  "name": "Three day warning",
  "enabled": true,
  "daysBefore": 3,
  "sendAtLocalTime": "09:00",
  "titleTemplate": "{item} expires soon",
  "bodyTemplate": "{item} expires in {days} days",
  "createdAt": "...",
  "createdBy": "...",
  "updatedAt": "...",
  "updatedBy": "..."
}
```

MVP targeting behavior:

```text
all active household members
```

Possible later targeting:

- specific members;
- owners only;
- individual per-user preferences;
- opt-out by device;
- role-based rules.

Do not add complex targeting in the initial version.

---

# 13. Push notifications vs local notifications

The project must **not depend exclusively on notifications scheduled locally on the same phone that added the item**.

That approach breaks the household requirement.

Example of the failure:

```text
Raj adds milk on Raj's phone
↓
Only Raj's phone schedules the reminder
↓
Spouse never receives it
```

The authoritative reminder engine should run on the backend.

Recommended design:

```text
Cloud Firestore
      ↓
Scheduled Firebase function
      ↓
Find eligible household items/rules
      ↓
Create notification deliveries
      ↓
Firebase Cloud Messaging
      ↓
Apple Push Notification Service
      ↓
Household member iPhones
```

Local notifications can exist later as a resilience/offline enhancement, but they must not become the only scheduling mechanism.

---

# 14. Notification execution schedule

Recommended initial implementation:

- scheduled backend function executes hourly;
- each rule contains a preferred local send time;
- the worker calculates which reminder deliveries are due;
- each delivery is idempotent.

The exact schedule may be simplified for the first implementation, for example:

```text
household default notification time: 09:00
```

The key requirement is that the data model must not permanently assume a single hardcoded `2 days before expiry` rule.

---

# 15. Notification idempotency

This must be designed before notifications are deployed.

A scheduled job can execute more than once.

A retry must not send the same reminder repeatedly.

Create a deterministic delivery identifier, conceptually:

```text
householdId
+ itemId
+ ruleId
+ expiryDate
+ recipientUid
```

Example:

```text
house_123:item_456:rule_3:2026-08-25:user_789
```

The backend must atomically ensure that a delivery is sent only once for that key.

Recommended collection:

```text
notificationDeliveries/
```

Example document:

```json
{
  "id": "deterministic-id-or-hash",
  "householdId": "house_123",
  "itemId": "item_456",
  "ruleId": "rule_3",
  "recipientUid": "user_789",
  "expiryDate": "2026-08-25",
  "scheduledFor": "...",
  "status": "sent",
  "sentAt": "...",
  "messageId": "..."
}
```

Possible states:

```text
pending
sent
failed
cancelled
```

---

# 16. Timezones

MVP simplification:

```text
household.timezone
```

Example:

```text
America/Toronto
```

Use an IANA timezone identifier.

All household reminder rules are initially interpreted in the household timezone.

Possible later improvement:

```text
user.notificationTimezone
```

This would allow members travelling or living elsewhere to receive notifications based on their own timezone.

Do not implement multi-timezone notification semantics until the base household workflow works.

---

# 17. Device registration

Each signed-in device must be associated with the user.

Suggested structure:

```text
users/{uid}/devices/{deviceId}
```

Example:

```json
{
  "platform": "ios",
  "fcmToken": "...",
  "enabled": true,
  "lastSeenAt": "...",
  "appVersion": "0.1.0"
}
```

The app must:

- register the current FCM token;
- update it when Firebase refreshes the token;
- disable/delete stale tokens when practical;
- never expose another user's device tokens to regular clients.

---

# 18. Household invitation model

The invitation system should be simple.

## MVP option

Create a shareable invite link/code:

```text
Create household
↓
Generate invitation
↓
Copy/share invitation link
↓
Recipient opens app/link
↓
Signs in or creates account
↓
Accepts invite
↓
Membership created
```

An email-sending backend is **not required for the first MVP**.

The app can use the standard iOS share sheet.

This avoids adding transactional email infrastructure before the actual household system is proven.

## Suggested invite document

```json
{
  "householdId": "house_123",
  "createdBy": "user_abc",
  "tokenHash": "...",
  "expiresAt": "...",
  "maxUses": 1,
  "uses": 0,
  "revoked": false
}
```

Do not store the raw invitation secret if a hash can be used.

---

# 19. Household roles

Keep roles minimal.

MVP roles:

```text
owner
member
```

Owner can:

- rename household;
- create/revoke invites;
- remove members;
- transfer ownership later if implemented.

Member can:

- view inventory;
- add items;
- edit items;
- remove/consume items;
- view household notification rules.

Rule editing can initially be owner-only or available to all household members. Pick one consistent behavior and enforce it both in UI and Firestore rules.

Recommended MVP:

```text
owner: manage household + notification settings
member: manage inventory
```

---

# 20. Proposed Firestore structure

```text
users/
  {uid}/
    displayName
    email
    createdAt

    devices/
      {deviceId}/
        platform
        fcmToken
        enabled
        lastSeenAt
        appVersion

households/
  {householdId}/
    name
    ownerUid
    timezone
    expiringSoonDays
    createdAt
    createdBy

    members/
      {uid}/
        role
        joinedAt
        invitedBy

    items/
      {itemId}/
        barcode
        name
        brand
        imageUrl
        quantity
        unit
        location
        expiryDate
        purchaseDate
        notes
        state
        createdAt
        createdBy
        updatedAt
        updatedBy

    notificationRules/
      {ruleId}/
        name
        enabled
        daysBefore
        sendAtLocalTime
        titleTemplate
        bodyTemplate
        createdAt
        createdBy
        updatedAt
        updatedBy

invites/
  {inviteId}/
    householdId
    tokenHash
    expiresAt
    maxUses
    uses
    revoked
    createdBy
    createdAt

productCache/
  {normalizedBarcode}/
    barcode
    name
    brand
    imageUrl
    source
    sourceUpdatedAt
    cachedAt

notificationDeliveries/
  {deliveryId}/
    householdId
    itemId
    ruleId
    recipientUid
    expiryDate
    status
    scheduledFor
    sentAt
    error
```

This is the default design unless implementation evidence shows a clear reason to change it.

---

# 21. Firestore security invariants

Security rules must be treated as application logic, not as an afterthought.

The client must not be trusted merely because it has a signed-in Firebase user.

Core requirements:

1. A user may read a household only if they are a member.
2. A user may read household inventory only if they are a member.
3. A user may create/update inventory only if they are a member.
4. A regular member may not arbitrarily add themselves to another household.
5. Only owner/admin actions may modify protected household fields.
6. A user may only modify their own device records.
7. FCM tokens must never be publicly readable.
8. Notification delivery records should normally be backend-managed.
9. Invitation acceptance must validate a real invitation rather than trusting a client-supplied household ID.
10. Server-owned fields should not be freely writable by the client.

Use the Firebase Emulator Suite to test authorization rules.

---

# 22. Product cache

The product cache is separate from household inventory.

Multiple households may scan the same barcode.

Do not duplicate Open Food Facts metadata unnecessarily.

Concept:

```text
barcode 066721000123
       ↓
productCache/066721000123
       ↓
Natrel 2% Milk
```

The household inventory item should copy the relevant display fields at creation time.

Why copy instead of only referencing the cache?

- product databases can change;
- products can be renamed;
- users may manually override the display name;
- historical inventory should not unexpectedly change because a public API record changed.

---

# 23. Offline behavior

Offline support is desirable but is **not an MVP blocker**.

The first milestone is a reliable shared household app while online.

However, architecture should not make offline support impossible.

Desired later behavior:

- previously loaded inventory can be viewed offline;
- new item additions can queue while offline;
- Firestore reconciliation occurs after reconnect;
- known barcode metadata can be cached locally.

Do not spend the first development cycle building a complicated synchronization engine.

Firestore already provides local persistence capabilities that may satisfy much of the basic requirement.

---

# 24. Open-source foundation research

## 24.1 Primary base — StayFresh

Repository:

`https://github.com/Dhiraj706Sardar/stayfresh`

License:

```text
MIT
```

Why it is the recommended starting base:

- Flutter app;
- repository contains an `ios/` project;
- Firebase Authentication;
- Firestore;
- Firebase Cloud Messaging dependency;
- barcode scanning;
- local notification dependency;
- expiry tracking;
- account/login structure;
- existing `GroceryItem` model;
- MVVM-ish organization;
- simple codebase that can be reshaped around household ownership.

Current public repository information verified on 2026-08-13:

- Flutter-based;
- email/password authentication;
- Firestore persistence;
- `firebase_messaging`;
- barcode scanning;
- `flutter_local_notifications`;
- expiry alert currently described as two days before expiry;
- current `GroceryItem` model includes `userId`;
- barcode product lookup is listed as requiring external API integration;
- iOS release build is documented;
- repository contains an `ios` directory;
- MIT license.

### Important caution

The StayFresh README contains a contradiction:

It advertises:

```text
Offline Support: Local data with cloud sync
```

but later lists:

```text
Offline mode needs implementation
```

Therefore treat offline support as **unverified/not implemented** until actual code proves otherwise.

The repository is small and currently has very few commits. It should be treated as scaffolding, not a mature production platform.

That is acceptable because this project requires significant architectural changes anyway.

---

# 25. Secondary source — Pantry App

Repository:

`https://github.com/Thigas-Tech/pantry_app`

License:

```text
MIT
```

This is the strongest implementation reference for food-specific features.

Verified public repository functionality on 2026-08-13 includes:

- Flutter;
- iOS directory;
- barcode scanning using `mobile_scanner`;
- Open Food Facts integration;
- product name/brand/nutrition/ingredient lookup;
- SQLite product caching;
- Firestore product cache;
- multiple named pantries;
- expiry tracking;
- two local reminders per item;
- manual product entry;
- fridge/freezer/pantry-style locations;
- shopping list;
- offline-first behavior;
- Riverpod;
- Freezed/json serialization;
- unit/widget tests;
- strict linting conventions;
- MIT license.

Useful code/concepts to study or adapt:

```text
lib/services/off_adapter.dart
lib/services/product_repository.dart
lib/services/firebase_cache_client.dart
lib/services/firebase_cache_service.dart
lib/services/notification_service.dart
lib/database/product_dao.dart
lib/database/inventory_dao.dart
lib/providers/
lib/models/
```

The repository's architecture and test discipline are substantially stronger than StayFresh's.

### Why Pantry App is not automatically the primary base

Its current architecture is strongly built around local inventory and Firestore product caching, rather than the exact shared authenticated household inventory model required here.

This project prioritizes:

```text
shared household state
+
server-originated push notifications
```

over sophisticated offline inventory.

Therefore the initial plan remains:

```text
StayFresh as the base shell
+
Pantry App as the implementation reference/code donor where appropriate
```

This decision should be revisited after Phase 0 repository audits.

If Pantry App turns out to require less work after direct code inspection, switching the primary base is allowed, but the decision must be documented.

---

# 26. Other researched projects

## Grocy

Repository:

`https://github.com/grocy/grocy`

License:

```text
MIT
```

Grocy is a mature self-hosted groceries and household management system.

It is useful for:

- inventory concepts;
- stock lifecycle concepts;
- barcode-oriented workflows;
- API/data model inspiration.

It is not the preferred base for this app because the desired product is intentionally much smaller and more consumer-focused.

The project should not inherit an ERP-style user experience.

---

# 27. Grocy SwiftUI client

Repository:

`https://github.com/supergeorg/Grocy-SwiftUI`

Verified as of 2026-08-13:

- native SwiftUI;
- iOS/macOS;
- barcode quick-scan;
- Grocy stock functionality;
- App Store availability;
- GPL-3.0 license.

This is useful for UX/reference purposes.

## License warning

Do **not** casually copy GPL-3.0 source into this project's MIT-derived codebase.

Use it for high-level design/reference unless the project's licensing strategy is intentionally changed.

---

# 28. KitchenOwl

Repository:

`https://github.com/TomBursch/kitchenowl`

Useful characteristics:

- Flutter client;
- Flask backend;
- iOS support;
- household/multi-user collaboration;
- realtime shared lists;
- self-hosted architecture.

License:

```text
AGPL-3.0
```

Useful as a conceptual reference for household collaboration.

## License warning

Do not copy AGPL source into this project unless the licensing implications are intentionally accepted.

---

# 29. License strategy

Target project license can remain permissive, preferably:

```text
MIT
```

if the project only incorporates compatible code.

When copying or adapting code from MIT projects:

- preserve required copyright notices;
- preserve license notices;
- record major borrowed components in `THIRD_PARTY_NOTICES.md`.

Do not mix in GPL/AGPL code casually.

Potential sources:

| Project | License | Use |
|---|---|---|
| StayFresh | MIT | Base candidate |
| Pantry App | MIT | Code/reference candidate |
| Grocy | MIT | Architecture/reference |
| Grocy-SwiftUI | GPL-3.0 | Reference only unless license decision changes |
| KitchenOwl | AGPL-3.0 | Reference only unless license decision changes |

---

# 30. Recommended client technology

## Flutter

Stay with Flutter for the initial project.

Reasons:

- both main reference repositories are Flutter;
- iOS target is supported;
- TestFlight builds are straightforward once Apple signing is configured;
- Firebase integration is mature;
- barcode libraries are available;
- allows Android support later without rewriting the entire client.

Do not rewrite the application in Swift merely because the first distribution target is iPhone.

A Swift rewrite would throw away most of the reusable open-source work.

---

# 31. Recommended Flutter architecture

The exact state-management library may depend on which repository becomes the final base.

Preferred direction if a meaningful refactor is performed:

```text
presentation
domain
data
services
```

A practical folder structure:

```text
lib/
  app/
    app.dart
    router.dart
    theme/

  auth/
    data/
    domain/
    presentation/

  households/
    data/
    domain/
    presentation/

  inventory/
    data/
    domain/
    presentation/

  products/
    data/
    domain/
    presentation/

  notifications/
    data/
    domain/
    presentation/

  shared/
    widgets/
    services/
    utils/
```

Do not perform a massive architecture rewrite before the app builds.

First obtain a known-good baseline, then refactor feature-by-feature.

---

# 32. Backend technology

Recommended:

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Cloud Functions for Firebase
- Cloud Scheduler / scheduled functions
- Firebase Emulator Suite

Optional later:

- Firebase App Check;
- Crashlytics;
- Analytics.

Do not add Supabase simultaneously unless there is an explicit reason.

Running two backends for the same product would increase complexity with little value.

---

# 33. Firebase server responsibilities

Backend-owned operations should include:

- secure invitation acceptance if rules alone are insufficient;
- scheduled notification evaluation;
- FCM sends;
- notification delivery idempotency;
- cleanup of expired invitations;
- possibly membership administration;
- optional product-cache refresh.

The mobile app should not contain server credentials.

---

# 34. Security/secrets

Never commit:

- Firebase service-account JSON;
- Apple private keys;
- APNs signing keys;
- API secrets;
- backend SMTP credentials;
- Open Food Facts credentials if privileged credentials are ever used.

Firebase client configuration values are not equivalent to server secrets, but Firestore security rules must still protect the backend.

Create:

```text
.env.example
```

Never commit:

```text
.env
```

Where FlutterFire-generated configuration is used, follow the standard Firebase approach rather than inventing a custom secret mechanism.

---

# 35. UX principles

The app must optimize for the action users perform repeatedly:

```text
put food away
```

Adding an item must be quick enough that users actually keep using the system.

Bad workflow:

```text
scan
→ product page
→ category selection
→ unit selection
→ location selection
→ purchase date
→ notes
→ confirmation
→ expiry date
→ final confirmation
```

Preferred workflow:

```text
scan
→ product recognized
→ expiry date
→ Add
```

Everything else should be optional or remembered from prior choices.

---

# 36. Home-screen concept

Initial layout:

```text
Household: Patel Home

Expiring Soon
--------------------------------
Milk                    1 day
Paneer                  2 days
Greek Yogurt            3 days

All Items
--------------------------------
Eggs                    Aug 28
Butter                  Sep 14
Frozen Peas             Nov 04

                    [ Scan ]
```

Recommended navigation:

```text
Inventory
Scan
Settings
```

Possible fourth tab later:

```text
Activity
```

Do not start with excessive navigation.

---

# 37. Add-item screen

When barcode recognized:

```text
[product image]

Natrel 2% Milk
Natrel
066721000123

Expiry date
[ Aug 25, 2026 ]

Quantity        [ 1 ]
Location        [ Fridge ]

[ Add to Household ]
```

Quantity and location may be collapsed under optional details.

When barcode not recognized:

```text
Product not found

Barcode
066721000123

Product name *
[                  ]

Brand
[                  ]

Expiry date *
[                  ]

[ Add ]
```

Failure should be recoverable, not a dead end.

---

# 38. Expiry-date entry UX

The user will enter expiry dates constantly.

The UX deserves special treatment.

Initial options:

- native date picker;
- quick buttons where useful.

Possible future quick actions:

```text
+3 days
+7 days
+14 days
+1 month
```

Do not use OCR/date recognition in the MVP.

A future version may allow photographing the printed expiry date, but OCR accuracy and packaging variation make that a separate feature.

---

# 39. Notification settings UX

Suggested screen:

```text
Expiry Notifications

[ON] 7 days before
     "{item} expires in one week"

[ON] 3 days before
     "{item} expires in {days} days"

[ON] 1 day before
     "{item} expires tomorrow"

[ON] Expiry day
     "{item} expires today"

[ + Add reminder ]
```

Editing a rule:

```text
Days before expiry
[ 3 ]

Notification title
[ {item} expires soon ]

Message
[ {item} expires in {days} days ]

Send around
[ 9:00 AM ]

[ Save ]
```

---

# 40. Default rules for newly created households

A new household should not require configuration before notifications work.

Recommended defaults:

```text
3 days before:
"{item} expires in {days} days"

1 day before:
"{item} expires tomorrow"

0 days:
"{item} expires today"
```

These defaults can be changed or deleted.

This is a product default, not a permanent hardcoded limitation.

---

# 41. Notification preferences per user

Not required for first MVP.

Eventually each user should be able to:

- mute all notifications;
- receive only some household rules;
- disable alerts on one device;
- define quiet hours.

The underlying device model should make this possible without redesign.

---

# 42. Notification tap behavior

Tapping an expiry notification should open the relevant inventory item.

Desired flow:

```text
push notification
↓
tap
↓
app launches
↓
household selected
↓
item detail opens
```

The FCM data payload should include at least:

```json
{
  "type": "expiry",
  "householdId": "...",
  "itemId": "..."
}
```

Do not rely only on notification display text for navigation.

---

# 43. Item editing

Any authorized household member should be able to correct:

- product name;
- expiry date;
- quantity;
- location;
- notes.

If expiry date changes:

- old pending notification deliveries must no longer be considered valid;
- new reminder eligibility should be calculated from the new date.

Using `expiryDate` as part of the idempotency key naturally helps with this.

---

# 44. Duplicate items

Scanning the same product twice does not necessarily mean it is a duplicate.

Example:

```text
Milk carton A expires Aug 20
Milk carton B expires Aug 28
```

Therefore inventory records should represent batches/items, not only unique products.

A barcode identifies product metadata.

It does **not** identify a unique physical inventory instance.

Correct:

```text
product barcode
    ↓
product metadata

inventory item #1 → expiry Aug 20
inventory item #2 → expiry Aug 28
```

---

# 45. Quantity semantics

For MVP, quantity can be simple.

Example:

```text
quantity: 2
unit: "items"
```

Do not build complex lot arithmetic initially.

If a user consumes one of two identical units with the same expiry date, quantity can be decremented.

Different expiry dates should be separate inventory records.

---

# 46. Search

Basic inventory search should eventually support:

- product name;
- brand;
- barcode.

Not necessary for the first backend milestone but should be available before a polished TestFlight beta if the household can accumulate many items.

---

# 47. Sorting

Default inventory sort:

```text
active items
→ earliest expiry first
```

Expired items should not dominate the main inventory view.

This app exists to make upcoming waste visible.

---

# 48. Accessibility

Do not encode expiry state using color alone.

Use:

- text labels;
- icons;
- color as reinforcement.

Example:

```text
⚠ Expires tomorrow
```

Support reasonable Dynamic Type behavior on iOS.

---

# 49. App permissions

Initial iOS permissions:

- Camera — barcode scanning
- Notifications — expiry alerts

Ask for camera permission when scan is first used, not unnecessarily at launch.

Ask for notification permission at a moment where the benefit is clear, preferably during onboarding or when the first item is added.

---

# 50. TestFlight requirements

Before TestFlight:

- unique iOS bundle identifier;
- Apple Developer account configured;
- signing team configured in Xcode;
- Firebase iOS app registered with the matching bundle ID;
- `GoogleService-Info.plist` configured appropriately;
- push-notification capability enabled;
- APNs/Firebase Cloud Messaging integration tested on a physical iPhone;
- camera tested on a physical iPhone;
- release build produced;
- archive uploaded to App Store Connect;
- basic privacy metadata prepared.

Push notifications and camera scanning must be tested on real devices before considering the TestFlight milestone complete.

---

# 51. Development strategy

Do not attempt every feature at once.

Develop vertical slices where each milestone ends in something demonstrably working.

---

# 52. Phase 0 — repository audit and baseline

## Goal

Prove that the starting repository can be built and run before changing architecture.

### Tasks

1. Fork/clone StayFresh.
2. Record upstream commit hash.
3. Run:
   - `flutter doctor`
   - `flutter pub get`
   - `dart analyze`
   - existing tests.
4. Build/run on available development target.
5. Inspect iOS project.
6. Upgrade only dependencies necessary for a stable build.
7. Verify Firebase initialization paths.
8. Verify actual implementations of:
   - authentication;
   - Firestore;
   - barcode scanning;
   - notification service;
   - dummy data.
9. Remove or isolate demo/dummy data.
10. Document any gap between README claims and actual code.
11. Create baseline tag/commit before feature work.

### Exit criteria

- repository builds;
- tests have a known baseline;
- app launches;
- exact upstream state is recorded;
- major broken claims are documented;
- no household feature work starts until baseline exists.

---

# 53. Phase 1 — clean single-user inventory

## Goal

Get the base application trustworthy before multi-user migration.

### Tasks

- reliable authentication;
- real Firestore inventory instead of dummy data;
- add/edit/remove item;
- expiry status calculation;
- manual item entry;
- existing barcode scanner works;
- normalized error handling.

### Exit criteria

One signed-in user can:

```text
add item
→ restart app
→ item still exists
→ edit expiry
→ remove/consume item
```

---

# 54. Phase 2 — Open Food Facts barcode lookup

## Goal

Make scanning useful.

### Tasks

Study/adapt Pantry App implementation.

Implement:

- barcode normalization;
- product repository abstraction;
- Open Food Facts client;
- product cache;
- fallback manual entry;
- product image handling;
- loading/error states.

### Exit criteria

Known barcode:

```text
scan
→ product name automatically populated
```

Unknown barcode:

```text
scan
→ manual form appears
→ item can still be added
```

No lookup error should trap the user.

---

# 55. Phase 3 — household data model

## Goal

Replace user-owned inventory with household-owned inventory.

### Migration concept

Current StayFresh-style model:

```text
GroceryItem.userId
```

must become conceptually:

```text
InventoryItem.householdId
InventoryItem.createdBy
InventoryItem.updatedBy
```

### Tasks

- create Household model;
- create membership model;
- household creation;
- select active household;
- migrate inventory repository queries;
- Firestore rules;
- realtime household listener.

### Exit criteria

Two different user accounts, both household members:

```text
User A adds item
↓
User B sees item without manual refresh
```

A third unauthorized account cannot read the household.

---

# 56. Phase 4 — invitations

## Goal

Allow real households to form without manually editing Firestore.

### Tasks

- invitation model;
- invite generation;
- share sheet;
- invite acceptance;
- expiration/revocation;
- membership creation;
- security tests.

### Exit criteria

```text
Owner creates invite
→ sends link/code
→ second user accepts
→ second user appears as member
→ second user can view inventory
```

---

# 57. Phase 5 — notification-rule engine

## Goal

Replace hardcoded reminder timing.

### Tasks

- NotificationRule model;
- default household rules;
- create/edit/delete rules;
- message template renderer;
- input validation;
- preview rendered notification;
- rule tests.

### Exit criteria

Household can configure:

```text
5 days before
"Finish {item}; it expires in {days} days"
```

and the stored rule renders correctly for sample item data.

---

# 58. Phase 6 — backend push notification worker

## Goal

Make reminders household-aware.

### Tasks

- Cloud Functions project;
- scheduled worker;
- rule eligibility evaluator;
- device token registry;
- FCM send;
- delivery idempotency;
- stale-token handling;
- error logging;
- emulator/unit tests where possible.

### Exit criteria

With two household members:

```text
one shared item
+
one reminder rule
↓
both eligible devices receive one notification
```

Running the worker again must not send the same reminder a second time.

---

# 59. Phase 7 — notification deep linking

## Goal

Notification tap opens the correct item.

### Exit criteria

```text
receive expiry notification
→ tap
→ correct item page opens
```

Test:

- app foreground;
- app background;
- app terminated.

---

# 60. Phase 8 — iPhone polish and TestFlight

### Tasks

- final iOS permissions;
- signing;
- icons/splash;
- production Firebase configuration;
- App Store Connect record;
- TestFlight build;
- test on at least two household accounts/devices;
- crash/error review;
- privacy text;
- beta feedback mechanism.

### Exit criteria

A non-developer can install from TestFlight, join a household, scan an item, and receive a reminder.

---

# 61. MVP definition of done

The MVP is complete when this entire scenario works:

```text
1. Raj installs app through TestFlight.
2. Raj creates an account.
3. Raj creates "Home".
4. Raj shares a household invite.
5. Second user installs/signs in.
6. Second user joins "Home".
7. Raj scans a packaged food barcode.
8. Product details are found automatically when Open Food Facts knows the barcode.
9. Raj enters an expiry date.
10. Item appears on both phones.
11. Household has a custom reminder rule.
12. Backend evaluates the rule.
13. Both eligible members receive the intended push notification.
14. Tapping the alert opens the item.
15. Either household member can mark it consumed.
16. The item disappears from active inventory on both phones.
```

If this scenario is not reliable, the project is not ready for feature expansion.

---

# 62. Non-goals for MVP

Do not build these before the core scenario is stable:

- recipe suggestions;
- AI recipe generation;
- meal planning;
- grocery price comparison;
- budgeting;
- store integrations;
- Instacart/Amazon ordering;
- nutrition analytics;
- calorie tracking;
- social network;
- Home Assistant integration;
- smart-fridge integration;
- OCR expiry-date recognition;
- receipt scanning;
- complex food-waste analytics;
- household chores;
- pantry weight sensors;
- web administration dashboard;
- Android release;
- multi-household enterprise administration.

Some may be valuable later.

They are distractions during MVP development.

---

# 63. Future features worth preserving architectural room for

After MVP:

## 63.1 Per-user notification preferences

Household rules define available alerts, but users can independently mute/subscribe.

## 63.2 OCR expiry date

After scanning barcode:

```text
Take photo of expiry date
→ OCR
→ confirmation
```

Always require user confirmation because printed date formats are inconsistent.

## 63.3 Siri / Shortcuts

Examples:

```text
"Add milk expiring Friday"
"What's expiring this week?"
```

## 63.4 Widgets

Useful iOS widget:

```text
Expiring Soon
Milk — tomorrow
Paneer — 2 days
Yogurt — 3 days
```

## 63.5 Waste tracking

When removing an item:

```text
Consumed
Discarded
Other
```

Can later show:

```text
"You discarded 8 items this month."
```

## 63.6 Shopping-list generation

Optional:

```text
consumed milk
→ add milk to shopping list?
```

## 63.7 Multiple households

Useful for:

- Home
- Parents
- Cottage

But do not complicate the initial onboarding.

The data model should support it even if UI initially focuses on one active household.

---

# 64. Coding-agent operating instructions

Any coding agent working on this project should follow these rules.

## Before modifying code

1. Read this document fully.
2. Inspect repository state.
3. Run current tests.
4. Record current failures.
5. Identify the smallest vertical slice needed for the current phase.

## During implementation

- Do not broaden scope.
- Do not add major dependencies without a concrete benefit.
- Do not replace Firebase casually.
- Do not rewrite Flutter into Swift.
- Do not implement Android-specific features before iOS MVP.
- Do not hardcode notification timing.
- Do not return inventory ownership to `userId`.
- Do not trust client authorization without Firestore rules.
- Do not use timestamps for date-only expiry semantics.
- Do not copy GPL/AGPL code into the MIT codebase.
- Do not silently remove existing working functionality.

## For every significant change

- add/update tests;
- run static analysis;
- run tests;
- keep app buildable;
- update docs if architecture changes.

---

# 65. Definition of acceptable code quality

Before merging a phase:

```text
dart analyze
```

should be clean or have explicitly documented pre-existing exceptions.

Tests should pass.

New domain logic should have unit tests, particularly:

- expiry-date calculations;
- notification eligibility;
- message template rendering;
- idempotency keys;
- barcode normalization;
- membership authorization logic where testable;
- timezone/date handling.

UI logic that can reasonably be widget-tested should be tested.

---

# 66. Required notification engine test cases

At minimum:

## Rule eligibility

```text
expiry = Aug 20
today = Aug 17
daysBefore = 3
→ eligible
```

```text
expiry = Aug 20
today = Aug 16
daysBefore = 3
→ not eligible
```

## Expired item

```text
expiry = Aug 15
today = Aug 17
daysBefore = 3
→ do not send future warning
```

## Consumed item

```text
state = consumed
→ no expiry alerts
```

## Disabled rule

```text
enabled = false
→ no alert
```

## Duplicate worker execution

```text
same item
same rule
same expiry date
same recipient
worker executes twice
→ one notification total
```

## Edited expiry date

```text
old expiry Aug 20
new expiry Aug 25
→ old delivery no longer produces a reminder
→ new expiry can produce new delivery
```

---

# 67. Required security tests

Using Firebase Emulator Suite where practical:

- household member can read household;
- non-member cannot read household;
- member can add inventory;
- non-member cannot add inventory;
- member cannot promote themselves to owner;
- member cannot add arbitrary users as household members;
- user cannot modify another user's device token;
- invalid invite cannot create membership;
- revoked invite cannot create membership;
- expired invite cannot create membership;
- notification delivery records cannot be forged by regular clients if backend-managed.

---

# 68. Suggested initial Git workflow

Branches:

```text
main
develop (optional)
feature/*
fix/*
```

Prefer short-lived feature branches.

Tag milestones:

```text
baseline-upstream
mvp-households
mvp-notification-rules
mvp-push
testflight-0.1.0
```

Record the original upstream commit in:

```text
UPSTREAM.md
```

Example:

```text
Primary upstream:
https://github.com/Dhiraj706Sardar/stayfresh

Original commit:
<commit hash>

Imported:
2026-08-13
```

---

# 69. Suggested repository documentation

Create:

```text
README.md
PROJECT_CONTEXT.md         ← this file
ARCHITECTURE.md
UPSTREAM.md
THIRD_PARTY_NOTICES.md
docs/
  firestore-schema.md
  notifications.md
  testflight.md
```

Avoid duplicating the entire project context across multiple documents.

`PROJECT_CONTEXT.md` remains the product source of truth.

`ARCHITECTURE.md` can evolve with implementation specifics.

---

# 70. Initial engineering decision log

## Decision 001 — Flutter client

**Decision:** Use Flutter.

**Reason:** Best reuse of existing open-source projects and supports iOS/TestFlight while preserving cross-platform capability.

---

## Decision 002 — Firebase backend

**Decision:** Use Firebase Auth + Firestore + FCM + Functions.

**Reason:** Matches the primary base repository and directly supports realtime household inventory and push notifications.

---

## Decision 003 — Household owns inventory

**Decision:** Inventory belongs to households, not users.

**Reason:** Shared household collaboration is a core product requirement.

---

## Decision 004 — Open Food Facts

**Decision:** Use Open Food Facts as the primary barcode product metadata source.

**Reason:** Open database, existing Flutter implementations, and sufficient packaged-food coverage for the intended workflow.

---

## Decision 005 — Backend notification scheduler

**Decision:** Server/backend owns shared reminder execution.

**Reason:** Local-only scheduling cannot reliably notify all household members.

---

## Decision 006 — Date-only expiry values

**Decision:** Store expiry as `YYYY-MM-DD`.

**Reason:** Expiry is a calendar date and should not shift under timezone conversion.

---

## Decision 007 — Primary starting repo

**Decision:** Begin by auditing/forking StayFresh, using Pantry App as the strongest implementation reference.

**Reason:** StayFresh is closer to Firebase account/shared-cloud plumbing; Pantry App is substantially stronger in barcode/product/offline functionality.

**Revisit condition:** If Phase 0 shows StayFresh's Firebase/auth implementation is mostly superficial or broken, compare direct implementation cost against adopting Pantry App as the actual base.

---

# 71. First development task for an AI coding agent

Use the following as the first concrete task.

```text
Read PROJECT_CONTEXT.md completely.

Perform Phase 0 only.

1. Inspect the current repository and identify its upstream commit/state.
2. Do not implement new product features yet.
3. Run Flutter/Dart static analysis and all existing tests.
4. Determine whether the project builds.
5. Inspect the actual implementations of Firebase initialization, authentication,
   Firestore persistence, barcode scanning, local/push notifications, and iOS setup.
6. Identify dummy/demo data and any code paths that are not production-backed.
7. Compare actual behavior against the upstream README claims.
8. Produce docs/BASELINE_AUDIT.md containing:
   - what works;
   - what is incomplete;
   - what is fake/dummy;
   - build/test failures;
   - outdated dependencies;
   - iOS blockers;
   - Firebase blockers;
   - the exact next implementation step.
9. Make only the minimum code/configuration changes required to obtain a clean,
   reproducible baseline build.
10. Do not begin household architecture until the baseline has been committed.
```

---

# 72. Second development task after baseline

Once Phase 0 is complete:

```text
Implement Phase 1: trustworthy single-user inventory.

Requirements:
- Remove dummy inventory behavior.
- Ensure authenticated user inventory persists in Firestore.
- Support add, edit, consume/remove.
- Preserve barcode and expiry fields.
- Expiry status must be derived from date-only semantics.
- Add tests for expiry calculations and core repository behavior.
- Keep the app building for iOS.
- Do not implement household sharing yet.
```

This is intentionally staged.

Building household synchronization on top of unreliable fake inventory will create unnecessary debugging complexity.

---

# 73. Research references

Public sources checked when this project context was created:

### StayFresh

`https://github.com/Dhiraj706Sardar/stayfresh`

Relevant public claims checked:

- Flutter;
- Firebase Auth;
- Firestore;
- Firebase Messaging dependency;
- barcode scanner;
- local notifications;
- iOS directory/build;
- current `userId` inventory ownership;
- two-day expiry notification behavior;
- barcode product lookup gap;
- MIT licensing.

### Pantry App

`https://github.com/Thigas-Tech/pantry_app`

Relevant public claims checked:

- Flutter/iOS;
- Open Food Facts;
- mobile barcode scanning;
- SQLite;
- Firestore product cache;
- expiry tracking;
- local notifications;
- product repository;
- offline-first architecture;
- tests/lint conventions;
- MIT licensing.

### Grocy

`https://github.com/grocy/grocy`

Used as a household inventory/data-model reference.

License checked as MIT.

### Grocy SwiftUI

`https://github.com/supergeorg/Grocy-SwiftUI`

Used only as a native Apple UX/reference candidate.

License checked as GPL-3.0.

### KitchenOwl

`https://github.com/TomBursch/kitchenowl`

Used as a household realtime collaboration reference.

License checked as AGPL-3.0.

---

# 74. Final product constraint

Whenever implementation choices become unclear, prefer the choice that makes this loop faster and more reliable:

```text
SCAN
  ↓
SET EXPIRY
  ↓
SHARE WITH HOUSEHOLD
  ↓
GET REMINDED
  ↓
CONSUME / REMOVE
```

Everything else is secondary until that loop works reliably on multiple real iPhones through TestFlight.

