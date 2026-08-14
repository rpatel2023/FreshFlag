# FreshFlag Changelog

This file records meaningful project milestones, decisions, audits, migrations, and implementation steps so work can resume without repeating completed investigation.

## Rules

- Update this file after every important project step.
- Record what changed, what was verified, what failed, and what remains unresolved.
- Do not treat exploratory local changes as accepted project changes unless explicitly recorded as such.
- Preserve exact commit SHAs, toolchain versions, and important architectural decisions where useful.

---

## 2026-08-13 — Phase 0 baseline audit started

### Repository established

- FreshFlag created as an independent GitHub repository rather than a GitHub fork.
- Original StayFresh Git history preserved.
- FreshFlag remote model on the development machine:
  - `origin`: `git@github.com:rpatel2023/FreshFlag.git`
  - `upstream`: `https://github.com/Dhiraj706Sardar/stayfresh.git`
- Imported upstream/default branch HEAD at audit start: `7431e9323ec448da843a4871ec94a0604557a224` (`modified : Readme.md`).
- GitHub connector access to `rpatel2023/FreshFlag` confirmed with repository write access.

### Static audit findings so far

- Project is a Flutter application named `stayfresh` in `pubspec.yaml`.
- Firebase dependencies and actual initialization are present:
  - Firebase Core
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Cloud Messaging
- Supabase is also present and conditionally initialized, including a separate Supabase storage service. This creates mixed backend responsibilities that need architectural cleanup for FreshFlag.
- Current Firestore inventory ownership is user-scoped under `users/{userId}/groceryItems/{itemId}` rather than household-scoped.
- `GroceryViewModel` silently signs in anonymously for demo use when no authenticated user exists.
- If Firestore loading fails, `GroceryViewModel` silently substitutes hard-coded dummy grocery items. This means a visually working app does not prove persistence is working.
- `GroceryItem.expiryDate` is a `DateTime` serialized as an ISO timestamp. FreshFlag requires date-only expiry semantics (`YYYY-MM-DD`).
- Notification code exists, but current behavior is primarily client/local notification oriented and will need to be replaced or augmented by household-aware backend push scheduling.
- Test coverage is effectively absent: `test/widget_test.dart` is empty.

### Ubuntu runtime baseline

Development machine used for runtime verification:

- Ubuntu 24.04.4 LTS
- Flutter 3.47.0 stable
- Dart 3.13.0

Initial Flutter Doctor findings:

- Flutter installed successfully.
- Chrome/web target available.
- Android SDK not installed, so Android build is currently unverified.
- Linux desktop toolchain was initially missing.

Linux build prerequisites installed:

- `clang`
- `cmake`
- `ninja-build`
- `g++`
- `pkg-config`
- `libgtk-3-dev`

After installation, Flutter Doctor reports the Linux toolchain as available.

### Dependency resolution behavior

Running `flutter pub get` succeeds, but on the current Flutter/Dart toolchain it modifies dependency resolution substantially:

- 19 dependency entries changed.
- 114 packages report newer versions incompatible with current constraints.
- `pubspec.lock` was rewritten, including SDK constraint resolution.
- Flutter also modified `analysis_options.yaml` to add platform/build-directory analyzer exclusions.

These local modifications are **audit artifacts only** and are not accepted FreshFlag baseline changes at this stage.

### Static analysis

`dart analyze` completes with 30 issues:

- 9 warnings, including unused fields/imports and unreachable switch cases.
- Remaining issues are informational/deprecation findings.
- No analyzer-fatal compile error was observed.

### Tests

`flutter test` fails immediately because `test/widget_test.dart` contains no `main()` method.

Conclusion: upstream does not currently provide a functioning automated test baseline.

### Build verification

#### Linux

`flutter build linux` succeeds.

Produced bundle:

`build/linux/x64/release/bundle/stayfresh`

This proves the imported application can compile as a Linux Flutter application on the audited toolchain.

#### Web

`flutter build web` fails.

Primary failure is incompatibility between the old FlutterFire web packages in the dependency set and the current Dart/Flutter JS interop APIs. Errors include missing `PromiseJsImpl`, `handleThenable`, `dartify`, and `jsify` symbols from `firebase_auth_web` and `firebase_messaging_web`.

This is currently classified as dependency/toolchain incompatibility, not yet as a FreshFlag application-code defect.

#### Android

Not yet tested because the Android SDK is not installed.

#### iOS

Not runtime-tested because the current development machine is Ubuntu and cannot run Xcode/iOS builds.

### Current Phase 0 assessment

StayFresh is viable as source scaffolding because the Flutter app compiles for Linux and contains real Firebase/Auth/Firestore/FCM implementations. It is **not** a trustworthy production baseline as imported.

Confirmed problems include:

- no meaningful automated tests
- dummy-data fallback that masks persistence failures
- anonymous demo authentication behavior
- user-owned instead of household-owned inventory
- mixed Firebase/Supabase responsibilities
- timestamp-based expiry representation
- outdated dependency set with current-toolchain incompatibilities
- web build failure
- unverified Android and iOS builds

---

## 2026-08-14 — Phase 0 static audit continued

### Working tree restored

- Local audit-induced changes to `analysis_options.yaml` and `pubspec.lock` were restored.
- Ubuntu clone fast-forwarded to changelog commit `6026638f72ac68e735714f09975d0a0455101df7`.
- Working tree confirmed clean.

### Upstream provenance documented

- Added `UPSTREAM.md`.
- Recorded original StayFresh repository and imported upstream SHA `7431e9323ec448da843a4871ec94a0604557a224`.
- Recorded that FreshFlag is an independent repository and the upstream remote is retained for provenance/selective reference rather than continuous merging.

### Barcode audit

- Barcode camera scanning is real and uses `mobile_scanner`.
- Manual-entry fallback exists.
- The scanner only captures/displays the barcode value.
- Critical gap: `_proceedWithBarcode()` navigates to `AddItemScreen()` with a TODO stating `Pass barcode value`; the scanned barcode is currently discarded.
- No product lookup is performed from the barcode.
- Therefore README language claiming add-by-scanning is materially overstated: scanning works as a UI interaction, but it does not currently populate an inventory item or identify a product.

### Authentication audit

- Email/password Firebase Auth methods are implemented.
- Anonymous authentication is implemented and used automatically by grocery loading code for demo behavior.
- Authentication service stores a Firebase ID token in `SharedPreferences` and considers token presence alone sufficient for `hasValidToken()`; it does not validate expiry/freshness before returning true.
- Duplicate switch cases exist for `operation-not-allowed` and `requires-recent-login`, matching analyzer unreachable-case warnings.
- Google Sign-In objects are present, but the audited service does not expose a working Google sign-in flow; current README/auth claims should therefore not be expanded beyond email/password without further implementation verification.

### Notification audit

- FCM permission/token plumbing exists.
- FCM token is only printed/read; no audited code persists device tokens into a backend user/device model.
- Expiry reminders are scheduled locally on the device using `flutter_local_notifications`.
- Reminder timing is hard-coded from constants rather than household-configurable rules.
- Notification tap handlers contain TODOs and do not deep-link to the relevant inventory item.
- Timezone scheduling uses `tz.local`; no household IANA timezone model exists.
- Current implementation therefore does not satisfy FreshFlag shared-household/backend reminder requirements.

### Firebase configuration audit

- `lib/firebase_options.dart` exists and was generated by FlutterFire CLI.
- Android Firebase values point to project `stayfresh-36edf` with concrete Android app ID/API key.
- Web configuration contains placeholder values such as `your_web_app_id` and `G-MEASUREMENT_ID`.
- iOS configuration is not usable as committed: `YOUR_IOS_API_KEY` and `your_ios_app_id` placeholders remain.
- macOS configuration also contains placeholders.
- Linux and Windows are explicitly unsupported by `DefaultFirebaseOptions.currentPlatform` even though the Flutter project contains desktop targets.
- This explains why a successful Linux compilation does not prove Firebase runtime functionality on Linux.

### iOS static audit

- iOS Flutter/Xcode project structure is present.
- App branding is still `Stayfresh` / `stayfresh`.
- iOS Firebase options still use bundle ID `com.example.stayfresh` and placeholder credentials.
- `ios/Runner/Info.plist` does not contain an `NSCameraUsageDescription`, despite barcode scanning requiring camera access.
- No `GoogleService-Info.plist` was observed under `ios/Runner` during the audited directory listing.
- iOS therefore cannot be considered configured for a usable Firebase + barcode build even before Xcode/signing verification.

### README versus code

Confirmed README mismatches include:

- README says barcode scanning can add grocery items; code does not pass scanned barcode into Add Item.
- README lists `flutter_barcode_scanner`, while actual dependency/code uses `mobile_scanner`.
- README claims offline support/local data with cloud sync; current grocery loading path primarily reads Firestore and falls back to dummy data on failure. A genuine offline-sync workflow has not been demonstrated.
- README describes Firebase configuration as being handled through platform files/environment, but committed iOS/web Firebase options contain placeholders.
- README describes a `GroceryItem` model containing fields such as `purchaseDate`, `isManualEntry`, and `userId`; the actual model differs substantially.
- README expiry status says expiring soon is 2 days or less, while the model currently defines expiring soon as 3 days or less.

### Updated Phase 0 direction

No further Linux commands are needed to establish basic source viability. The major remaining platform gap is iOS, which cannot be meaningfully runtime-verified from Ubuntu. Android verification is optional for Phase 0 because FreshFlag's primary target is iPhone/TestFlight and Linux already proves the Dart/native project compiles.

---

## 2026-08-14 — Phase 0 completed

### Baseline audit published

- Added `docs/BASELINE_AUDIT.md`.
- Consolidated runtime, static, architecture, README-accuracy, iOS, Firebase, barcode, notification, auth, Firestore, and testing findings.
- Classified each major subsystem as working, partial, misleading, missing, blocked, or unverified.

### Phase 0 decision

**Decision: continue with StayFresh as scaffolding.**

Reasoning:

- The Flutter app compiles successfully for Linux.
- Firebase Auth, Firestore, FCM plumbing, and barcode camera scanning are real implementations rather than pure mocks.
- The current deficiencies are understood and tractable.
- Replacing the entire base with another project is not justified by the audit evidence.

However, FreshFlag must not layer household features onto the current demo behavior. Phase 1 must first establish a trustworthy single-user foundation.

### Important Phase 1 priorities established

1. Establish a supported/reproducible Flutter dependency baseline.
2. Add real automated tests before changing persistence behavior.
3. Remove anonymous automatic sign-in and silent dummy-data fallback.
4. Fix Firestore document/local item ID consistency.
5. Make authenticated single-user Firestore inventory trustworthy.
6. Convert expiry handling to date-only semantics.
7. Remove Supabase from the core architecture unless a concrete requirement justifies it.
8. Create/configure a FreshFlag Firebase project and proper iOS app configuration.
9. Add required iOS permissions, including camera usage description.
10. Defer household collaboration until these foundations are stable.

### Deferred verification

- Actual iOS build/signing/TestFlight verification remains deferred until a macOS/Xcode environment is available.
- Android compile remains optional/deferred because it is not the primary MVP platform.

---

## 2026-08-14 — Phase 1 stabilization slice 1 validated

Branch: `phase1-stabilization`

### Implemented

- Added first real grocery-item tests in place of the empty upstream test file.
- Removed automatic anonymous sign-in from inventory loading.
- Removed silent dummy grocery fallback when Firestore loading fails.
- Consolidated duplicate `GroceryViewModel` provider creation so the app has one coherent inventory state instance.
- Changed Firestore writes to use the application item ID as the Firestore document ID, removing the previous local-ID/document-ID mismatch.
- Updated grocery-item serialization so fields such as notes and consumed state are preserved consistently.
- Added a transitional remote-first persistence bridge so Add Item can no longer report success after only writing to local Hive while the visible inventory reads from Firestore.

### Ubuntu validation

Validated on Flutter 3.47.0 / Dart 3.13.0:

- `flutter test --no-pub`: **3 tests passed**.
- `dart analyze`: **27 issues**, down from the Phase 0 baseline of 30. No analyzer-fatal errors.
- `flutter build linux --no-pub`: **success**.
- Git working tree after validation: **clean**.

Validated branch HEAD before this changelog entry:

`6ff74a9047ca5fdde3eaa6fe2e59da44622bb69f` — `test: add grocery item persistence baseline`

### Result

Slice 1 is accepted as a stable Phase 1 milestone. The application now has a testable, authenticated, Firestore-first single-user inventory path instead of silently masking persistence failures with demo behavior.

### Next slice

- Refactor Add Item to call `GroceryViewModel` directly and remove its remaining direct local-database persistence path.
- Remove stale/duplicate authentication code that generates analyzer warnings.
- Continue reducing warning-level analyzer findings before changing expiry semantics.
