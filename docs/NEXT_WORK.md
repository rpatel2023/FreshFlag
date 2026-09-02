# FreshFlag — Next Work for Codex

> Current objective: validate and publish the current SideStore build without reopening completed backend deployment work.

## Current phase

FreshFlag is out of the earlier real-device acceptance-testing phase for the PR #15 through PR #18 feature set.

The current installed phone build has tested:

- Active / Consumed inventory navigation and Restore;
- household roles and **Members & access** management;
- trusted-member/Admin reminder-rule and invite permissions;
- Guest read-only household behavior;
- item editing and cross-device propagation;
- expiry shortcuts, inventory search/sort, tappable reminder rows, consumed Undo;
- personal Favourites per account, including Guest restrictions;
- relaunch persistence for auth, household selection, inventory, Favourites, Discord configuration, and SideStore refresh.

Do not treat role management, favourites, or the old PR #15–#18 acceptance checklist as pending work.

## Backend/rules deployment

The newer source batch's Cloud Functions and Firestore rules **have already been deployed**.

Do not send the user through another Firebase deployment merely because older documentation says deployment is pending. Re-deploy only when there are newer backend/rules changes or evidence of a deployment problem.

## Newer source batch awaiting phone validation

The current source includes:

- English-preferred Open Food Facts barcode lookup;
- household barcode product cache for manually entered products, including one-time backfill from existing barcode inventory;
- persistent household custom categories in Add/Edit and dashboard filters;
- granular per-user Discord item activity opt-ins;
- household Activity feed backed by backend item create/update/delete triggers;
- SideStore-local expiry reminders from synced inventory.

The remaining gate is to build/install a current IPA and validate these behaviors on the existing real household accounts/devices.

## SideStore distribution work

PR #19 added a permanent publisher-side SideStore release path.

The repository now supports:

- the existing temporary unsigned IPA workflow for ad-hoc development builds;
- a **Publish SideStore Release** workflow for permanent GitHub Releases;
- release assets `FreshFlag.ipa` and `source.json`;
- permanent source URL `https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json`;
- per-user SideStore signing with each tester's own Apple Account.

The first permanent release has not yet been published and validated end to end.

## Next runtime sequence

Unless the user names another priority:

1. build the current SideStore IPA from `main`;
2. install it on the existing test iPhone(s);
3. validate the newer source batch on-device;
4. if validation passes, run **Publish SideStore Release** for the first permanent release;
5. add the permanent FreshFlag source to SideStore;
6. verify install/update behavior through that source;
7. only then share the source with friends/family.

## Existing authorization model

```text
owner
  - full household administration
  - member access management
  - notification rule management
  - inventory management

admin
  - normal shared inventory use
  - notification rule management
  - invite and member/guest management within the intended boundary
  - no ownership transfer

member
  - normal shared inventory use
  - no household access management

guest
  - read-only household/inventory/reminder-rule access
```

Role semantics are enforced in Flutter capability checks, Firestore rules, and backend callable functions. Do not create a parallel client-only authorization system.

## Regression requirements

Do not break already-tested behavior:

- invite/join household;
- shared inventory visibility;
- item add/edit paths;
- consume/restore;
- consumed-item navigation;
- reminder behavior;
- household role/member management;
- favourites per account;
- guest read-only restrictions;
- custom categories;
- Discord integration behavior.

## Validation

Use the repository's prescribed commands from `AGENTS.md`. At minimum preserve the existing analyzer/test/build baseline appropriate to the changed surface.

After meaningful implementation or validation, update:

- `docs/CURRENT_STATE.md`;
- `docs/NEXT_WORK.md`;
- `docs/DECISIONS.md` when architectural/product decisions change;
- `CHANGELOG.md` for meaningful implementation, deployment, validation, or release events.
