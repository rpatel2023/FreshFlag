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

## 2026-08-14 — Phase 1 stabilization branch

Branch: `phase1-stabilization`

### Slice 1 — trustworthy Firestore inventory — VALIDATED

Implemented:

- Added real `GroceryItem` persistence/serialization tests.
- Removed automatic anonymous sign-in from inventory loading.
- Removed silent dummy-data fallback on Firestore failure.
- Consolidated duplicate `GroceryViewModel` providers.
- Made Firestore document ID equal to application item ID.
- Preserved `notes` and `isConsumed` in serialization.
- Added a temporary remote-first Hive bridge while the inherited UI was being untangled.

Validated at code HEAD `6ff74a9047ca5fdde3eaa6fe2e59da44622bb69f`:

- `flutter test --no-pub`: **3 passed**.
- `dart analyze`: **27 issues**, no fatal errors.
- `flutter build linux --no-pub`: **success**.
- Working tree clean.

### Slice 2 — one write path + barcode handoff — VALIDATED

Implemented:

- Add Item writes through `GroceryViewModel` rather than directly to Hive.
- Scanner passes captured barcode to Add Item.
- Removed anonymous authentication support and stale ViewModel calls.
- Removed duplicate/unreachable Firebase Auth exception cases.
- Cached token presence is no longer treated as a valid session.

An initial runtime pass exposed two compile errors; both were corrected before re-validation.

Validated at HEAD `a4b980f6a27a275f10951398c1d6c98af131c89f`:

- `flutter test --no-pub`: **3 passed**.
- `dart analyze`: **19 issues**, no errors.
- `flutter build linux --no-pub`: **success**.
- Working tree clean.

### Slice 3 — date-only expiry semantics — VALIDATED

Implemented:

- New expiry values normalize to calendar dates.
- Firestore/JSON expiry storage is strict `YYYY-MM-DD`.
- Legacy full ISO timestamp records remain readable and normalize on load.
- Firestore expiry queries were subsequently changed to compare date-only strings as well.
- Expanded persistence tests from 3 to 4 cases.

Validated at HEAD `7bf7b02c1e3c7a21ba1b03bd00c80062066f0747`:

- `flutter test --no-pub`: **4 passed**.
- `dart analyze`: **19 issues**, no errors.
- `flutter build linux --no-pub`: **success**.
- Working tree clean.

### Slice 4 — remove inherited split architecture — VALIDATED

After Slice 3 validation, further audit of the visible app found that inherited login/signup/dashboard/reminders/settings screens still bypassed the stabilized services. This slice removed those parallel demo paths rather than allowing them to survive into household work.

#### Real Firebase authentication flow

- Replaced inherited fake login flow with `AuthViewModel`/Firebase email-password sign-in.
- Password reset now uses Firebase Auth.
- Replaced fake signup/local-user creation with Firebase account creation.
- `AuthWrapper` now routes directly from the real Firebase auth-state stream.
- Inventory loads once per authenticated UID and resets on sign-out/account change.

Key commits:

- `335563af115be8926ff0329d6fcd14021a676c6a` — Firebase login.
- `2159883d3118df32c267f46c665363894459cca2` — Firebase signup.
- `6d9c6757cc31b1df59eab9d187260a3b9dacd34d` — authenticated inventory lifecycle.

#### One authoritative inventory UI

- Dashboard now reads `GroceryViewModel`/Firestore instead of Hive.
- Reminders now derive from the same inventory state.
- Settings shows the Firebase user and supports real Firebase sign-out.
- Main authenticated shell simplified to Inventory / Reminders / Settings.
- Obsolete duplicate/local flows deleted: old splash, onboarding, HomeScreen, profile editor, notification-test screen, and inherited client notification sender widget.

#### Supabase removed from active architecture

- Add Item no longer exposes inherited Supabase image upload.
- `GroceryViewModel` no longer imports or uses Supabase storage.
- App startup no longer initializes Supabase.
- Supabase storage service deleted.
- Supabase dependency removed from `pubspec.yaml`.
- `supabase_setup.sql` and mixed-backend `env_config.dart` deleted.
- Client constants no longer contain placeholder backend credentials.
- FCM service no longer stores tokens in Supabase or attempts client-side FCM HTTP sends. Client-side sending is deliberately disabled; backend delivery is reserved for the notification backend phases.

#### Hive removed from inventory/identity

- `LocalDatabaseService` reduced to device-local `SharedPreferences` only.
- Removed all local grocery CRUD/mirroring and local user identity storage.
- `GroceryItem` is now a plain Dart/Firestore model, not a `HiveObject`.
- Obsolete grocery/user Hive adapters and local `UserModel` deleted.
- Hive/build-runner generator dependencies removed.

#### Firestore and iOS correctness

- Firestore expiry queries now use the same `YYYY-MM-DD` semantics as stored records.
- Added Phase 1 `firestore.rules`: authenticated users may access only their own `/users/{uid}` namespace and grocery items; all unspecified paths are denied.
- Added `firebase.json` pointing at the rules file.
- iOS display name changed to FreshFlag.
- Added `NSCameraUsageDescription` for barcode scanning and photo-library usage text.

#### Package/dependency cleanup

- Dart package renamed from `stayfresh` to `freshflag`.
- Tests updated to import `package:freshflag/...`.
- Inherited unused dependencies removed; remaining core dependencies are Firebase, local notifications, scanner, Provider, SharedPreferences and timezone support.
- README replaced with an accurate FreshFlag status/roadmap instead of inherited claims.

Ubuntu validation after dependency cleanup:

- `flutter pub get`: **118 dependency changes**, primarily removals of inherited packages.
- `flutter test`: **4 passed**.
- `dart analyze`: **6 info-only deprecation findings**, no warnings/errors.
- `flutter build linux`: **success**.

The six remaining deprecations were subsequently removed from `theme_provider.dart` and `app_theme.dart` before Phase 2 work.

## 2026-08-14 — Phase 2 barcode product recognition

### Slice 1 — Open Food Facts lookup — VALIDATED

Implemented:

- Added `ProductLookupResult` model.
- Added `ProductLookupService` using Open Food Facts product API with barcode lookup.
- Lookup requests use a narrow `fields` selection instead of downloading the entire product payload.
- Requests include an identifying FreshFlag `User-Agent`.
- Scanner performs one lookup after a completed barcode capture rather than polling.
- Recognized products prefill Add Item with product name while preserving the barcode.
- Unknown barcode, incomplete product data, or network failure falls back to manual Add Item while retaining the scanned barcode.
- Added parser/recognition tests for successful, unknown, and incomplete product responses.
- Added `http` as the only new runtime dependency required for the lookup service.

Relevant implementation commits include:

- `d821cad45ee5fc2dd0ff52e78086e949ae179de4` — add product lookup result model.
- `29a4078901ab1333a3602ce24df497cc113e6bc2` — add Open Food Facts lookup service.
- `857c1a4251414eb7c6d969c608f4aacade387f7f` — wire recognized product data into Add Item.
- `4e941edc01c41b188a7bd2281cf7a37581da162f` — integrate lookup into scanner flow.
- `d526bee7f5c406ff9fa388743ab4f1a0136d03d3` — add Open Food Facts parser tests.

Ubuntu validation at code HEAD `d526bee7f5c406ff9fa388743ab4f1a0136d03d3`:

- `flutter pub get`: resolved `http 1.6.0`; only one dependency changed relative to the already-cleaned graph.
- `flutter test`: **7 passed**.
- `dart analyze`: **No issues found**.
- `flutter build linux`: **success**.

### Generated dependency metadata pending repository commit

Local Flutter resolution intentionally regenerated:

- `pubspec.lock`
- Linux generated plugin registrant files
- macOS generated plugin registrant
- Windows generated plugin registrant files

Flutter also rewrote `analysis_options.yaml`; that file is an unrelated tool-generated change and must be restored before committing.

The exact generated lockfile/plugin metadata exists only in the Ubuntu working tree and must be committed/pushed from that machine before further dependency-changing work is layered on top.
