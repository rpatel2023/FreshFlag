# FreshFlag — Product & Engineering Decisions

> This file captures decisions made after the original project specification so coding agents do not repeatedly reopen settled questions.

## D-001 — FreshFlag remains focused on the core expiry loop

The primary product loop is still:

```text
SCAN / ADD
→ SET EXPIRY
→ SHARE WITH HOUSEHOLD
→ GET REMINDED
→ CONSUME / RESTORE
```

Do not broaden the product into recipes, meal planning, budgeting, grocery ordering, nutrition tracking, or unrelated household administration unless the user explicitly chooses that direction.

## D-002 — Household-owned inventory remains a hard invariant

Inventory belongs to a household, not directly to an individual user.

Do not migrate back to per-user inventory ownership as a shortcut for authorization problems.

## D-003 — Consumed items are recoverable state, not destructive deletion

Consumed items must remain reachable so that **Restore to inventory** is meaningful.

A prior UI bug made consumed items unreachable after they left the active list. PR #15 fixed that. Any future navigation redesign must preserve access to non-active items.

## D-004 — Household access must support different privilege levels

The current role model is:

- **Owner**: full control; only Owner may assign Admin; ownership transfer is not implemented.
- **Admin**: full inventory access; can manage reminder rules, invites, Members, and Guests within the intended boundary.
- **Member**: inventory write access; reminder-rule read access; no household access management.
- **Guest**: read-only household/inventory/reminder-rule access.

This model has been implemented in UI, Firestore rules, and backend callable functions, and has been tested on the current phone build. Do not invent a second parallel authorization system in the client only.

## D-005 — Trusted members need alert/reminder management capability

A trusted household member is represented by the Admin role and can create/manage household reminder rules.

This requirement came from real two-user testing and is implemented/tested in the current phone build.

## D-006 — Security rules are part of the feature

Future role or permission changes are incomplete unless the same permission model is enforced by Firestore/backend authorization.

Hiding a button in Flutter is not authorization.

The implemented PR #16 role-management model follows this decision. Keep future authorization changes covered by Firestore/backend tests.

## D-007 — Real-device behavior beats stale phase documentation

The original project context was written before much of the implementation existed. When it says a feature is a future phase but the repository/tested app already implements it, preserve the working implementation and update documentation rather than rebuilding from scratch.

## D-008 — Barcode lookup prefers English names

Fresh Flag should request English Open Food Facts responses and prefer English product-name fields (`product_name_en`, `generic_name_en`, `abbreviated_product_name_en`) before falling back to generic localized fields.

Manual item naming remains available when lookup data is missing or still not ideal.

When a household member manually names an item with a barcode, Fresh Flag should save that barcode-to-product metadata in a household-owned cache. Future scans of that barcode should prefer the household cache before querying Open Food Facts so users do not repeatedly re-enter the same product.

## D-009 — Categories are open-ended item metadata

Inventory categories are not a closed enum.

The app keeps a curated default category list for convenience, but users can create custom household categories while adding or editing items. Saved custom categories persist under the household and remain available even when no current inventory item uses them.

Dashboard filters should include both saved household categories and categories found on actual household inventory items.

## D-010 — Discord notification types are individually opt-in

Discord delivery remains per user, not household-global.

Expiry reminders and item activity messages are separate opt-ins using the user's saved Discord webhook. Activity notifications should be sent only to household members who explicitly enabled that event type.

Current activity event types are item added, item changed, item consumed, item restored, and item removed.

## D-011 — SideStore uses local expiry reminders, not remote push

Fresh Flag's SideStore/free Personal Team build should not depend on APNs/FCM remote push.

For SideStore, expiry reminders are device-local notifications scheduled from the inventory that has synced to that iPhone. Cross-device household activity alerts remain optional Discord notifications and in-app Activity feed entries.

Standard/paid builds may continue to use FCM/APNs remote push for expiry reminders.

## D-012 — Authentication recovery is separate from household administration

Household roles govern Fresh Flag household data, not Firebase Authentication accounts.

- Household Owner/Admin must **not** be able to reset another user's authentication password.
- A signed-out user normally recovers access through Firebase Authentication's password-reset email/link flow.
- A signed-in email/password user may change their own password after reauthentication.
- A trusted Fresh Flag project operator may perform emergency recovery with privileged Firebase Admin SDK credentials using the local-only repository tool.

Production testing confirmed that Firebase password-reset emails are sent; during testing they were initially hard to locate, so absence from the visible inbox must not be treated as proof that the reset mechanism is broken.

## D-013 — The Home Screen web app is notification-only

The iOS Home Screen web app is a thin Web Push companion, not a second Fresh Flag client.

It may authenticate an existing user, register/unregister the current browser's Web Push subscription, send a test notification, and display expiry reminder pushes. It must not duplicate inventory, barcode, household, activity, reminder-rule, expiry-calculation, or item-lifecycle logic from the Flutter application.

The existing Firebase backend remains authoritative. Web Push is an additional reminder delivery channel and must use its own idempotent delivery identity so it does not suppress Discord, native FCM/APNs, or device-local reminder behavior.

Deleting or disabling the web companion must leave the native Fresh Flag application fully functional.
