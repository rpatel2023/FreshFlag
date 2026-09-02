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

- FreshFlag has moved through its earlier structured real-device acceptance-testing phase.
- A second household user has installed/joined successfully.
- The second user can join the same household and see the shared inventory.
- Shared household inventory synchronization works across the tested two-iPhone flows.
- The current SideStore build is installed and has been in normal household use for several days as of 2026-09-02.
- The current phone build includes the PR #15 through PR #18 feature set plus the newer post-validation source batch described below.
- Do not send the user back through old build/install or PR #15–#18 acceptance gates unless a new regression is reported.

### Item lifecycle

- Marking an item **Consumed** successfully writes the state change.
- After consumption, the item exposes **Restore to inventory**.
- Consumed items remain reachable through the explicit Active / Consumed inventory views added in PR #15.
- Cross-device consume/restore behavior has been validated on real devices.

### Reminders

- Reminder behavior has been manually tested.
- SideStore builds support on-device local expiry reminders from synced household inventory.
- Treat reminders as an existing implemented feature, not a greenfield phase.

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

The current installed build includes the post-validation source batch with:

- English-preferred Open Food Facts product-name lookup;
- household barcode product cache and one-time backfill from existing barcode inventory;
- persistent household custom categories and dashboard category filters;
- granular per-user Discord activity opt-ins;
- backend item create/update/delete activity fanout and household activity feed;
- an in-app **Activity** tab;
- SideStore-local expiry reminders from synced inventory, exposed as **Expiry reminders on this iPhone**.

**Backend deployment is complete.** The updated Cloud Functions and Firestore rules for this source batch have already been deployed.

**Build/install is also complete.** The resulting SideStore build has been installed and used in normal household operation for several days. This is enough to close the old generic "build/install current IPA" gate. Do not repeat it merely because older notes say the batch is awaiting installation.

Do not overstate feature-specific validation: normal use confirms the current build is viable, while any individual feature that has not been explicitly exercised should still be tested when that feature becomes relevant.

## SideStore distribution

PR #19 added the publisher-side distribution path.

The first permanent SideStore release was successfully published on 2026-09-02:

- release: **Fresh Flag 0.1.0 (5)**;
- tag: `sidestore-v0.1.0-b5`;
- target commit: `b161bf76b2f5b267436fe0c4c388c15cb6003f21`;
- release assets: `FreshFlag.ipa` and `source.json`;
- workflow run `33643532182`: **success**;
- the workflow's post-publish verification step successfully validated both the source JSON and IPA URL.

Permanent source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

One-tap SideStore source link:

```text
sidestore://source?url=https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

On-device source migration has now also passed:

- the permanent **Fresh Flag** source was added successfully in SideStore;
- SideStore showed one Fresh Flag app in that source;
- the existing FreshFlag install had originally been installed from the IPA/iLoader path and was not listed under **My Apps**;
- installing Fresh Flag from the new source over the existing app succeeded without uninstalling first;
- Fresh Flag now appears under **My Apps** as a SideStore-managed app with a fresh 7-day signing window.

This proves the source-based install/migration path. The only remaining distribution proof is a future update-detection/update-install test using a later release with a higher build number.

## Current known gaps / bugs

- No current blocking product gap is documented after existing real-device testing, backend deployment, and several days of normal use of the current build.
- The first permanent SideStore release is published successfully.
- Source add/install/migration into SideStore management is validated on-device.
- A future source-based update from build 5 to a higher build still needs validation.
- When new bugs are found in normal use, record them here before starting implementation.

## Current priority

Unless the user names a higher-priority bug or feature:

1. preserve the working permanent Fresh Flag SideStore source;
2. on the next meaningful app release, use a higher build number and verify SideStore surfaces the update;
3. once that update path is proven, treat the SideStore distribution flow as fully validated for friends/family.

Do **not** create a throwaway release solely to satisfy the update test unless the user explicitly wants to; the next real app change can provide that proof.

Do **not** repeat Firebase deployment or another generic current-build install/validation cycle unless there is a newer code change or evidence of a regression.

## Evidence hierarchy

When documentation disagrees, use this order:

1. explicit newer runtime/deployment confirmation from the user;
2. current repository behavior + tests + Firestore rules;
3. this `CURRENT_STATE.md` file;
4. `DECISIONS.md`;
5. original `PROJECT_CONTEXT_ORIGINAL.md` phase plan.

The original phase numbering is historical planning context, not proof that a feature remains unimplemented.
