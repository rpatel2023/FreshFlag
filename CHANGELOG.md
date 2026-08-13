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

### Next actions

1. Restore local audit-induced changes to `analysis_options.yaml` and `pubspec.lock` so the working tree returns to the imported upstream state.
2. Pull this changelog commit into the Ubuntu clone.
3. Continue static Phase 0 inspection of barcode scanning, authentication behavior, notification implementation, Firebase configuration/security assumptions, iOS configuration, and README claims versus code.
4. Decide whether an Android SDK install is necessary before closing Phase 0.
5. Produce `docs/BASELINE_AUDIT.md` and `UPSTREAM.md` once the audit is complete.
