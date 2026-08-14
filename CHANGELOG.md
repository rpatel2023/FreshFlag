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
- Web build failed because inherited FlutterFire web packages are incompatible with the current Dart/Flutter JS interop APIs.
- Android build was not tested because Android SDK is not installed.
- iOS runtime build remains unavailable from Ubuntu.
- `flutter pub get` on the imported source rewrote dependency resolution; those audit-induced changes were restored and not accepted as baseline changes.
- Initial `dart analyze`: 30 issues.
- Initial test file was empty and `flutter test` failed because there was no `main()`.

### Phase 0 architectural findings

- Firebase Auth, Firestore, FCM plumbing and camera barcode scanning are real implementations.
- Supabase is mixed into image/token storage despite Firebase being the intended FreshFlag backend.
- Inventory was scoped to `users/{uid}/groceryItems/{itemId}` and will later migrate to household ownership.
- Inventory loading automatically created anonymous Firebase sessions and silently substituted dummy grocery items when Firestore failed.
- Add Item wrote to Hive/local storage while the visible inventory ViewModel read Firestore.
- Firestore auto-generated document IDs while the application maintained a separate item ID.
- Expiry values were full ISO timestamps rather than date-only values.
- Barcode scanning captured a value but discarded it before Add Item; there was no product lookup.
- Notifications are primarily local-device schedules with hard-coded timings; no household rules/backend delivery/device-token model exists.
- iOS Firebase configuration contains placeholders, `GoogleService-Info.plist` was not present, and `NSCameraUsageDescription` was missing.
- README materially overstated barcode-add, offline sync, data model, Firebase configuration, and some expiry behavior.
- Decision: **retain StayFresh as scaffolding**, but stabilize single-user behavior before adding household features.

## 2026-08-14 — Phase 1 stabilization branch

Branch: `phase1-stabilization`

### Slice 1 — trustworthy Firestore inventory — VALIDATED

Implemented:

- Replaced empty upstream test file with real `GroceryItem` persistence/serialization tests.
- Removed automatic anonymous sign-in from inventory loading.
- Removed silent dummy-data fallback on Firestore failure.
- Consolidated duplicate `GroceryViewModel` providers into one inventory state instance.
- Made Firestore document ID equal to the application item ID.
- Preserved `notes` and `isConsumed` in item serialization/copy behavior.
- Added transitional remote-first Hive mirroring so a local write cannot report success before Firestore succeeds.

Validated on Ubuntu at code HEAD `6ff74a9047ca5fdde3eaa6fe2e59da44622bb69f`:

- `flutter test --no-pub`: **3 tests passed**.
- `dart analyze`: **27 issues**, down from 30; no fatal errors.
- `flutter build linux --no-pub`: **success**.
- Working tree: clean.

### Slice 2 — single write path + barcode handoff — VALIDATED

Implemented:

- `AddItemScreen` writes inventory only through `GroceryViewModel`; direct Hive/local inventory persistence was removed from the screen.
- Add Item supports `initialBarcode` and stores the supplied barcode on the item.
- Barcode scanner passes the captured barcode into `AddItemScreen` instead of discarding it.
- Barcode product recognition remains deferred to Phase 2.
- Removed anonymous sign-in support from `FirebaseAuthService` and `AuthViewModel`.
- Removed unused Google Sign-In state from the authentication service.
- Removed duplicate/unreachable Firebase Auth exception cases.
- `hasValidToken()` now reflects the actual Firebase authenticated session instead of cached token presence.

The first Ubuntu checkpoint exposed two compile blockers (nullable barcode closure value and a stale anonymous-auth ViewModel call). Both were fixed in commits `e6f299d2b3c7b05982f5420e49f8bba517f8bff5` and `439cca30501524546069221dd6cc551bb346bdd4`.

Final Ubuntu validation at HEAD `a4b980f6a27a275f10951398c1d6c98af131c89f`:

- `flutter test --no-pub`: **3 tests passed**.
- `dart analyze`: **19 issues**, down from 27; **no errors**.
- `flutter build linux --no-pub`: **success**.
- Working tree: clean.

Result: Slice 2 accepted.

### Slice 3 — date-only expiry semantics — AWAITING RUNTIME VALIDATION

Implemented:

- `GroceryItem.expiryDate` remains a `DateTime` for compatibility with inherited Flutter/Hive code, but construction now normalizes it to a calendar date at local midnight.
- Firestore/JSON serialization now stores expiry as strict `YYYY-MM-DD`, matching the FreshFlag data contract.
- Legacy inherited records containing full ISO timestamps remain readable; they are normalized to date-only semantics when loaded.
- Calendar-day expiry calculations now operate directly on the normalized expiry date.
- Expanded tests from 3 to 4 cases, including exact date-only serialization and legacy timestamp migration behavior.

Relevant commits:

- `b3de1228996949185be59dbef8984ad8a43e11ff` — enforce date-only expiry semantics.
- `90f62d6856f73a27a9ed27c9fe535ec53992803c` — cover date-only persistence and legacy migration.

Current constraint: this model/persistence change must now be run through Flutter tests, analyzer, and the Linux compiler before additional architectural changes are layered on top.
