# FreshFlag Changelog

This file is the persistent project progress log. Update it after every important implementation, validation, architectural decision, or blocker so work never repeats unnecessarily.

## 2026-08-13 — Repository and Phase 0 baseline

- Created independent repository `rpatel2023/FreshFlag` while preserving StayFresh Git history.
- Development remotes:
  - `origin`: `git@github.com:rpatel2023/FreshFlag.git`
  - `upstream`: `https://github.com/Dhiraj706Sardar/stayfresh.git`
- Imported upstream SHA: `7431e9323ec448da843a4871ec94a0604557a224`.
- Added `UPSTREAM.md` and `docs/BASELINE_AUDIT.md`.
- Baseline environment: Ubuntu 24.04.4, Flutter 3.47.0 stable, Dart 3.13.0.
- Linux release build succeeded after installing clang/cmake/ninja/GTK development dependencies.
- Web build failed because inherited FlutterFire web packages were incompatible with the then-current dependency set.
- Android build was not tested because Android SDK is not installed.
- iOS runtime build remains unavailable from Ubuntu.
- Initial `dart analyze`: 30 issues.
- Initial upstream test file was empty.

### Phase 0 architectural findings

- Firebase Auth, Firestore, FCM plumbing and camera barcode scanning were real implementations.
- Supabase was mixed into image/token storage despite Firebase being the intended backend.
- Inventory was split between Hive and Firestore.
- Inventory loading silently created anonymous sessions and substituted dummy data after Firestore failures.
- Firestore document IDs did not match application item IDs.
- Expiry was timestamp-based instead of date-only.
- Barcode scanning captured a value but discarded it before Add Item.
- Notifications were local-device oriented and hard-coded.
- iOS Firebase configuration was incomplete and camera permission was missing.
- README materially overstated capabilities.
- Decision: **retain StayFresh only as scaffolding and establish a trustworthy FreshFlag foundation before household work.**

## 2026-08-14 — Phase 1 stabilization — VALIDATED

Branch: `phase1-stabilization`

- Added real grocery persistence tests.
- Removed anonymous/demo authentication and dummy inventory fallback.
- Unified visible login/signup with real Firebase Auth.
- Unified Add Item, Dashboard and Reminders around one Firestore-backed `GroceryViewModel`.
- Made Firestore document IDs match application item IDs.
- Preserved all item fields in serialization/copy behavior.
- Enforced date-only expiry persistence (`YYYY-MM-DD`) while retaining legacy timestamp compatibility.
- Removed Supabase, Hive inventory/user identity, obsolete demo screens and unused inherited dependencies.
- Renamed the Dart package to `freshflag`.
- Added initial Firestore security rules and corrected iOS camera permission/branding.
- Cleaned analyzer output from 30 issues to zero after modernization cleanup.

Validation milestones:

- Slice 1: 3 tests passed; Linux build succeeded; analyzer 27 issues.
- Slice 2: 3 tests passed; Linux build succeeded; analyzer 19 issues.
- Slice 3: 4 tests passed; Linux build succeeded; analyzer 19 issues.
- Architecture cleanup: 4 tests passed; Linux build succeeded; analyzer only six info-level deprecations, later removed.

## 2026-08-14 — Phase 2 barcode product recognition — VALIDATED

Implemented:

- Added Open Food Facts barcode lookup using a narrow product field selection and identifying FreshFlag User-Agent.
- Added `ProductLookupResult` and parser coverage.
- Scanner performs one product lookup after a completed capture.
- Recognized products prefill Add Item while preserving the barcode.
- Unknown/incomplete/network-failure cases fall back to manual entry with barcode retained.
- Added `http` as the only new runtime dependency.

Ubuntu validation:

- `flutter test`: **7 passed**.
- `dart analyze`: **No issues found**.
- `flutter build linux`: **success**.
- Generated dependency lockfile/plugin metadata was committed locally and pushed as `50fccd5` after a clean rebase.

Repository integration:

- Pull request #1 merged to `main` as `7c85d1d434b9f64800808581f3e3717a926ca128`.
- PR included the validated Phase 1 foundation and initial Phase 2 barcode recognition.

## 2026-08-14 — Phase 3 household-owned inventory — VALIDATED

Branch: `phase3-households`

- Added `Household`, `HouseholdMember`, and `HouseholdRole` domain models.
- Household stores name, owner UID, member UID list, IANA timezone, and timestamps.
- Membership uses explicit `owner` / `member` documents under `households/{householdId}/members/{uid}`.
- Added household discovery, creation, preferred-household selection, first-run setup and switching.
- Inventory moved to `households/{householdId}/items/{itemId}`.
- Grocery items gained household/audit fields.
- Inventory state uses Firestore snapshots for real-time multi-device propagation.
- Firestore rules require household membership and protect household ownership/audit boundaries.

Ubuntu validation:

- `flutter test --no-pub`: **9 passed**.
- `dart analyze`: **No issues found**.
- `flutter build linux --no-pub`: **success**.
- Working tree: **clean**.

Repository integration:

- Pull request #2 merged to `main` as `ccf57560b61ba8f2b11fe422d46dd39860fcb982`.
- Added `docs/PHASE3_VALIDATION.md` with the validation record.

## 2026-08-14 — Phase 4 household invitations — AWAITING RUNTIME VALIDATION

Branch: `phase4-invites`

### Invite model and service

- Added `HouseholdInvite` with active/revoked status, creation/expiry timestamps and normalized share codes.
- Invite codes are 12-character high-entropy values generated with `Random.secure()` from an ambiguity-reduced alphabet.
- Invite documents are stored as `invites/{code}` so joining is a direct lookup rather than an enumerable code query.
- Owners can create seven-day invite codes and revoke them.
- Joining verifies authenticated user, code shape, invite status and expiry before writing membership.
- Join transaction adds the caller to `memberUids`, creates `members/{uid}` with member role/invite provenance, and updates the caller's preferred household.

### UI

- First-run household setup now supports either creating a household or joining with a 12-character code.
- Added Household Sharing screen.
- Owners can create, copy and revoke an invite code.
- Any signed-in user can join another household by code from Settings.

### Security rules

- Signed-in users may fetch a specific active/unexpired invite they already possess; invite collection listing is denied.
- Invite creation/update/revoke requires household owner role.
- Self-join household updates may alter only `memberUids`, `updatedAt`, and `lastJoinInviteId`.
- Self-join requires a valid active/unexpired invite for that exact household and permits exactly one new UID: the caller.
- Member creation during join requires caller UID, `member` role and matching valid invite provenance.
- Household ownership cannot be changed through the invite path.

### Tests

- Existing 9 tests retained.
- Added invite-code normalization coverage.
- Added invite active/revoked lifecycle coverage.
- Expected suite size at the next checkpoint: **11 tests**.

### Current runtime boundary

Phase 4 now changes Firestore transactions/rules, first-run routing UI, settings navigation, household state and test imports. No dependency changed. Flutter tests, analyzer and Linux compile are required before invitations are merged or Phase 5 notification rules are layered on top.
