# FreshFlag — Current Implementation State

> Last updated from project conversation: 2026-09-02
> Purpose: Tell a coding agent what is true *now*, not what the original design spec planned.

## Product identity

The project is **FreshFlag**, an iPhone food-expiry tracker built with Flutter and Firebase. The current private-distribution path is **SideStore**, using zero-fee unsigned IPA builds that are signed by each user's own Apple Account. The core loop remains:

```text
scan / add item
→ set expiry
→ shared household inventory
→ reminders
→ consume / restore
```

`PROJECT_CONTEXT_ORIGINAL.md` contains the original product definition and architecture intent. This file overrides it where implementation has moved beyond the original phase plan.

## Confirmed working behavior

### Real-device use

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

## Newer source batch and deployment state

The repository includes a post-validation source batch with:

- English-preferred Open Food Facts product-name lookup;
- household barcode product cache and one-time backfill from existing barcode inventory;
- persistent household custom categories and dashboard category filters;
- granular per-user Discord activity opt-ins;
- backend item create/update/delete activity fanout and household activity feed;
- an in-app **Activity** tab;
- SideStore-local expiry reminders from synced inventory, exposed as **Expiry reminders on this iPhone**.

**Backend deployment is complete.** The updated Cloud Functions and Firestore rules for this source batch have already been deployed. Do not list backend/rules deployment as pending work.

The remaining gate for this source batch is a fresh SideStore build/install and real-device validation of the newer behavior.

## SideStore distribution

PR #19 added the publisher-side distribution path:

- the existing ad-hoc unsigned SideStore IPA workflow remains available;
- `Publish SideStore Release` can build the zero-fee profile and publish permanent GitHub Release assets;
- each release contains `FreshFlag.ipa` and `source.json`;
- the permanent source URL is `https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json`;
- friends add the source once and SideStore performs per-user signing on their own devices.

The first permanent SideStore release has not yet been published/validated end to end.

## Current known gaps / bugs

- No current blocking product gap is documented after the existing real-device testing and backend deployment.
- The newest source batch still needs fresh-build/device validation.
- The new permanent SideStore release/source pipeline still needs its first end-to-end release validation.
- When new bugs are found in normal use, record them here before starting implementation.

## Current priority

Unless the user names a higher-priority bug or feature:

1. build the current SideStore release from `main`;
2. install it on the existing test iPhone(s);
3. validate the newer source batch on-device;
4. publish the first permanent SideStore release;
5. add the permanent source in SideStore and validate install/update behavior before sharing it with friends.

Do **not** repeat Firebase Functions/Firestore rules deployment unless there is a newer backend change or deployment evidence indicates a regression.

## Evidence hierarchy

When documentation disagrees, use this order:

1. current repository behavior + tests + Firestore rules;
2. explicit newer runtime/deployment confirmation from the user;
3. this `CURRENT_STATE.md` file;
4. `DECISIONS.md`;
5. original `PROJECT_CONTEXT_ORIGINAL.md` phase plan.

The original phase numbering is historical planning context, not proof that a feature remains unimplemented.
