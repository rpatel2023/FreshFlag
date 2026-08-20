# FreshFlag — Next Work for Codex

> Current objective: preserve the now-tested Fresh Flag core app and pick up only new, explicitly identified bugs or product work.

## Current phase

Fresh Flag is out of the prior real-device acceptance-testing phase.

The current phone build includes and has tested:

- Active / Consumed inventory navigation and Restore;
- household roles and **Members & access** management;
- trusted-member/Admin reminder-rule and invite permissions;
- Guest read-only household behavior;
- item editing and cross-device propagation;
- expiry shortcuts, inventory search/sort, tappable reminder rows, consumed Undo;
- personal Favourites per account, including Guest restrictions;
- relaunch persistence for auth, household selection, inventory, Favourites, Discord configuration, and SideStore refresh.

Do not treat role management, favourites, or the old post-IPA checklist as pending work.

## Pending validation

The newest source batch is implemented but not yet validated on the phones:

- English-preferred Open Food Facts barcode lookup;
- household barcode product cache for manually entered products, including one-time backfill from existing barcode inventory;
- persistent household custom categories in Add/Edit item and dashboard filters;
- per-user Discord item-added notifications.

Next runtime work is to deploy updated Cloud Functions, build/install a fresh IPA, and validate those three items with the existing household accounts.

## Task objective

For the next task, inspect the repo and respond to the user's newest explicit priority. If the user has not named a new bug or feature, the current next step is validation/deployment of the newest source batch above.

## Required investigation before changes

Codex must inspect, not assume:

- current code paths touched by the requested bug/feature;
- current Firestore security rules when changing household, inventory, reminder, favourites, invite, or role behavior;
- current backend callable Functions when changing privileged operations;
- current tests around the affected behavior;
- current branch, HEAD, and clean/dirty working tree.

## Existing authorization model

The implemented authorization model is:

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

## Regression requirements for future work

Do not break already-tested behavior:

- invite/join household;
- shared inventory visibility;
- item add/edit paths;
- consume item;
- restore consumed item;
- navigation to non-active/consumed items added by PR #15;
- reminder behavior;
- household role/member management;
- favourites per account;
- guest read-only restrictions;
- custom categories;
- per-user Discord item-added opt-in behavior.

## Validation

Use the repository's actual prescribed commands from `AGENTS.md` / project config. At a minimum, preserve a clean analyzer/test/build baseline appropriate to the current repo.

After implementation, update:

- `docs/CURRENT_STATE.md`;
- `docs/DECISIONS.md` if role semantics become concrete;
- changelog/release notes if the repository uses them.

Do not mark authorization-related work complete based only on UI rendering. Authorization must be tested.
