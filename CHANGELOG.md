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

## 2026-08-14 — Phase 3 household-owned inventory — AWAITING RUNTIME VALIDATION

Branch: `phase3-households`

### Household domain and ownership

- Added `Household`, `HouseholdMember`, and `HouseholdRole` domain models.
- Household stores name, owner UID, member UID list, IANA timezone, and timestamps.
- Membership uses explicit `owner` / `member` role documents under `households/{householdId}/members/{uid}`.
- Added `HouseholdService` for discovering the caller's households, persisting preferred household, creating the first household, and reading current membership.
- Added `HouseholdViewModel` for active household selection and owner/member state.
- First authenticated user with no household is routed to `HouseholdSetupScreen` rather than silently getting an inferred timezone.
- Settings now displays household name, timezone, role, and supports switching when the user belongs to multiple households.

### Household-owned inventory

- Inventory path changed from user-owned storage to `households/{householdId}/items/{itemId}`.
- `FirebaseFirestoreService` now requires an active household instead of deriving a user-scoped collection.
- `GroceryItem` now carries `householdId`, `createdByUid`, `updatedByUid`, and `updatedAt` audit fields while remaining backward-readable for old records lacking those fields.
- `GroceryViewModel` binds to the selected household and enriches writes with household/audit metadata.
- Inventory state now uses a Firestore snapshot subscription so changes propagate to all active members in real time instead of requiring manual refresh.
- Switching/signing out cancels the previous household subscription and clears in-memory inventory.

### Security rules

- `/users/{uid}` remains self-only.
- Household reads require membership.
- Household creation requires the caller to be the owner and sole initial member.
- Household updates/deletion require owner role.
- Member documents are readable by household members; owner-controlled member mutation is reserved for invite/join work in Phase 4.
- Inventory reads/writes require household membership.
- Item create/update rules enforce household ID and audit UIDs.

### Tests

- Existing persistence and Open Food Facts tests retained.
- Added household serialization/role tests.
- Expanded grocery persistence coverage to include household/audit fields and backward compatibility.

### Current runtime boundary

This slice changes app routing, Firestore paths, snapshot subscriptions, security rules, item serialization, and test expectations. It now requires Flutter tests/analyzer/Linux compilation on Ubuntu before Phase 4 invite logic is layered on top.
