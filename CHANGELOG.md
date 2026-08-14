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

- Added `Household`, `HouseholdMember`, and owner/member roles.
- Added first-household setup, preferred household selection, and household switching.
- Moved inventory to `households/{householdId}/items/{itemId}`.
- Added item audit fields (`householdId`, `createdByUid`, `updatedByUid`, `updatedAt`).
- Added Firestore snapshot subscriptions for real-time shared household inventory.
- Tightened Firestore rules around household membership, owner administration, and item audit fields.
- Added household serialization and role tests.

Ubuntu validation:

- `flutter test --no-pub`: **9 passed**.
- `dart analyze`: **No issues found**.
- `flutter build linux --no-pub`: **success**.
- Working tree: **clean**.

Repository integration:

- Pull request #2 merged to `main` as `ccf57560b61ba8f2b11fe422d46dd39860fcb982`.

## 2026-08-14 — Phase 4 household invitations — VALIDATED

Branch: `phase4-invites`

Implemented:

- Added non-enumerable 12-character household invite codes.
- Owners can create, copy, and revoke active invite codes.
- Invite records carry household ID, creator UID, creation/expiry timestamps, and revoked state.
- Authenticated users can join a household by a valid code from first-run setup or Settings.
- Invite acceptance adds exactly the signed-in user as a `member`, updates household `memberUids`, and persists `currentHouseholdId` atomically.
- Household state refreshes after a successful join so the joined household becomes immediately available/active.
- Firestore rules allow invite reads by exact document ID for signed-in users, owner-only invite creation/revocation, and constrain invite-based household/member updates to the joining authenticated UID.
- Added invite model normalization/expiry tests while retaining all prior household/product/inventory tests.

Ubuntu validation at branch HEAD `070520292497a23a800e9a5142e1a0791c761608`:

- `flutter test --no-pub`: **11 passed**.
- `dart analyze`: **No issues found**.
- `flutter build linux --no-pub`: **success**.
- Working tree: **clean**.

Result: Phase 4 invitation/join source is accepted for integration. Firestore rule behavior still requires emulator-backed authorization tests before production deployment; that security test harness is scheduled as part of the backend phase before release.
