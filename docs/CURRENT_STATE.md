# FreshFlag — Current Implementation State

> Last updated from project conversation: 2026-08-20
> Purpose: Tell a coding agent what is true *now*, not what the original design spec planned.

## Product identity

The project is **FreshFlag**, an iPhone/TestFlight food-expiry tracker built with Flutter and Firebase. The core loop remains:

```text
scan / add item
→ set expiry
→ shared household inventory
→ reminders
→ consume / restore
```

`PROJECT_CONTEXT_ORIGINAL.md` contains the original product definition and architecture intent. This file overrides it where implementation has moved beyond the original phase plan.

## Confirmed working behavior

### TestFlight / real-device use

- The app has moved through the real-device testing phase.
- A second household user has installed/joined successfully.
- The second user can join the same household and see the shared inventory.
- Shared household inventory synchronization works across the tested two-iPhone flows.
- The current phone build includes the PR #15 through PR #18 feature set, including consumed-item navigation, household roles/member management, branding normalization, item editing, and personal favourites.
- The old post-IPA checklist is complete; do not treat deployment/build/acceptance as still pending unless a newer regression says otherwise.

### Item lifecycle

- Marking an item **Consumed** successfully writes the state change.
- After consumption, the item exposes **Restore to inventory**.
- Returning from the item caused it to disappear from the active inventory list, as intended.
- A UI defect was found because there was no navigation path back to consumed items.
- That defect was fixed in **PR #15**.
- PR #15 passed CI and was merged to `main` at commit:

```text
55672e641a1365a4e4604c11b66512b5
```

Do not reintroduce a design where consumed items are unreachable.

### Reminders

- Reminder behavior has been manually tested after the consumed-item work.
- Treat reminders as an existing implemented feature, not a greenfield phase.
- Before changing reminder architecture, inspect the code and existing tests/build history rather than assuming the original Phase 5/6 work is still undone.

### Household roles and member management

- Household member management is implemented in the current phone build.
- The app has a discoverable **Members & access** path.
- The owner can promote a trusted household member from Member to Admin without making them Owner.
- The trusted member/Admin path for reminder-rule and invite management has been tested on device.
- Guest/read-only behavior has been tested: guests can read household data/inventory/reminder rules but cannot perform privileged household or inventory writes.
- Role behavior is enforced in Firestore rules and backend callable functions, not only in Flutter UI.

### Favourites and inventory polish

- Personal favourites are implemented and tested as per-user data, not household-owned data.
- Favourites do not leak between household accounts.
- Guest users can manage personal favourites, but **Add again** is disabled while household access is read-only.
- Existing inventory items can be edited from Item details.
- Edit propagation, expiry shortcuts, inventory search/sort, tappable reminder rows, consumed Undo, and relaunch persistence have been tested on device.

## Source changes after current phone validation

The repository now includes a post-validation source batch that still needs deployment/build/device validation:

- barcode/Open Food Facts lookup now requests English and prefers English product-name fields before falling back to generic localized fields;
- Add/Edit item can create a custom household category from the category picker;
- custom categories are persisted under the household and remain available even before/after matching inventory items exist;
- dashboard category filters include saved household categories plus categories found on actual inventory items;
- Discord settings now include a separate per-user opt-in for item-added notifications;
- a backend item-create trigger sends Discord item-added messages only to household members who configured a Discord webhook and opted into that event.

## Current known gaps / bugs

- No current blocking product gap is documented here after the real-device testing phase and the post-validation source batch above.
- When new bugs are found in normal use, record them here before starting implementation.

## Current priority

Before coding:

1. inspect the current repository, tests, rules, and latest handoff docs;
2. preserve the already-tested production/device behavior listed above;
3. avoid reopening completed acceptance-test work without new evidence;
4. keep future work focused on the Fresh Flag core expiry loop unless the user explicitly prioritizes something else.

## Evidence hierarchy

When documentation disagrees, use this order:

1. current repository behavior + tests + Firestore rules;
2. this `CURRENT_STATE.md` file;
3. `DECISIONS.md`;
4. original `PROJECT_CONTEXT_ORIGINAL.md` phase plan.

The original phase numbering is historical planning context, not proof that a feature remains unimplemented.
