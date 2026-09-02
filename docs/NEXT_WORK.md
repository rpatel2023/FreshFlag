# FreshFlag — Next Work for Codex

> Current objective: publish and validate the permanent SideStore distribution path from the current known-good build.

## Current phase

FreshFlag is beyond both the earlier PR #15–#18 acceptance phase and the later generic "deploy/build/install current source batch" phase.

The current SideStore build:

- is installed on the existing household devices;
- has been used in normal household operation for several days as of 2026-09-02;
- uses the already-deployed current Cloud Functions and Firestore rules;
- includes the newer source batch with local SideStore expiry notifications, Activity, product cache/categories, and granular Discord activity behavior.

Do not repeat Firebase deployment or another generic build/install cycle unless a newer code change requires it or a regression is reported.

## Current known-good behavior

Preserve the already-tested behavior:

- Active / Consumed inventory navigation and Restore;
- invite/join household and realtime shared inventory;
- household roles and **Members & access** management;
- Admin/trusted-member reminder-rule and invite permissions;
- Guest read-only household behavior;
- item add/edit, consume/restore, and cross-device propagation;
- expiry shortcuts, inventory search/sort, tappable reminder rows, consumed Undo;
- personal Favourites per account;
- auth/household/inventory/Favourites/Discord/SideStore refresh persistence;
- SideStore-local expiry reminder support;
- current deployed backend/rules behavior.

## SideStore distribution work

PR #19 added the publisher-side release path.

The repository supports:

- the existing temporary unsigned IPA workflow for ad-hoc development builds;
- a **Publish SideStore Release** workflow for permanent GitHub Releases;
- release assets `FreshFlag.ipa` and `source.json`;
- permanent source URL `https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json`;
- per-user SideStore signing with each tester's own Apple Account.

The remaining milestone is the **first permanent release and source-based install/update validation**.

## Next runtime sequence

Unless the user names another priority:

1. run **Publish SideStore Release** against the current known-good `main` build;
2. confirm the GitHub Release contains `FreshFlag.ipa` and `source.json`;
3. add the permanent FreshFlag source to SideStore on an existing test phone;
4. verify FreshFlag is discoverable/installable from that source;
5. validate the update path with a subsequent build when practical;
6. once the source path is proven, share the one-time SideStore setup/source instructions with friends/family.

Do not gate this on another backend deployment or generic device-validation pass.

## Authorization model

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

## Validation discipline

The user's normal use of the current build closes the old generic install/viability gate. Do not infer that every individual newer feature has been exhaustively exercised; test a specific feature when work touches it or a regression is suspected.

Use the repository's prescribed commands from `AGENTS.md` for code changes. After meaningful implementation, validation, deployment, or release events, update:

- `docs/CURRENT_STATE.md`;
- `docs/NEXT_WORK.md`;
- `docs/DECISIONS.md` when architectural/product decisions change;
- `CHANGELOG.md` for meaningful implementation, deployment, validation, or release events.
