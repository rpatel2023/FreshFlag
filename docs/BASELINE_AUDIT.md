# FreshFlag Phase 0 Baseline Audit

Date: 2026-08-14

Upstream source: `Dhiraj706Sardar/stayfresh`
Imported upstream SHA: `7431e9323ec448da843a4871ec94a0604557a224`
FreshFlag repository: `rpatel2023/FreshFlag`

## Executive conclusion

StayFresh is acceptable as **scaffolding**, but not as a trustworthy product baseline.

The application can compile for Linux on Flutter 3.47.0 / Dart 3.13.0 and contains real Firebase Auth, Firestore, FCM, barcode camera scanning, and local notification code. However, several headline capabilities are incomplete or misleading, the automated test baseline is effectively absent, iOS Firebase configuration is placeholder-only, and current inventory/reminder architecture does not match FreshFlag requirements.

Recommendation: **continue with this codebase, but treat Phase 1 as a cleanup/stabilization phase rather than feature layering.** Do not build household collaboration on top of the current demo fallbacks and user-scoped inventory model.

## Baseline runtime environment

Verified on:

- Ubuntu 24.04.4 LTS
- Flutter 3.47.0 stable
- Dart 3.13.0
- Linux toolchain: clang 18.1.3, CMake 3.28.3, Ninja 1.11.1

## Build and test status

### `flutter pub get`

Result: **PASS with dependency drift**

- Dependency resolution succeeds.
- Running against the current Flutter/Dart toolchain rewrites the lockfile substantially.
- 19 dependency entries changed during the audit run.
- 114 packages report newer versions incompatible with current constraints.
- Audit-induced changes were restored rather than committed.

### `dart analyze`

Result: **PASS WITH ISSUES**

- 30 findings total.
- 9 warnings, including unused members/imports and duplicate/unreachable auth switch cases.
- Remaining findings are deprecation/info items.

### `flutter test`

Result: **FAIL**

`test/widget_test.dart` is empty and has no `main()` method. There is no meaningful automated Dart/Flutter test baseline.

### Linux release build

Result: **PASS**

`flutter build linux` produces:

`build/linux/x64/release/bundle/stayfresh`

This confirms the imported source is compilable as a Flutter native application.

Important limitation: committed Firebase options explicitly reject Linux at runtime, so compilation does not prove Firebase functionality on Linux.

### Web build

Result: **FAIL**

The current old FlutterFire web dependency set is incompatible with the current Dart/Flutter JS interop APIs. Errors include missing `PromiseJsImpl`, `handleThenable`, `dartify`, and `jsify` symbols.

Classification: dependency/toolchain incompatibility rather than a core FreshFlag product requirement. Web is not an MVP target.

### Android build

Result: **UNVERIFIED**

Android SDK is not installed on the audit machine. Android verification is not required to decide whether to continue because FreshFlag's primary target is iPhone/TestFlight and Linux compilation already proves basic source viability.

### iOS build

Result: **BLOCKED / UNVERIFIED**

Cannot compile or sign iOS from Ubuntu. Static inspection also finds iOS configuration blockers described below.

## Capability audit

### Firebase initialization

Classification: **REAL BUT PARTIALLY CONFIGURED**

- `firebase_core`, Firebase Auth, Firestore and FCM are real dependencies.
- `main.dart` initializes Firebase using generated `DefaultFirebaseOptions`.
- Android has concrete Firebase app values.
- Web contains placeholder app/measurement values.
- iOS and macOS contain placeholder API/app IDs.
- Linux and Windows explicitly throw unsupported errors.

### Authentication

Classification: **PARTIAL / DEMO-CONTAMINATED**

Working source exists for:

- email/password sign-in
- email/password registration
- password reset
- anonymous sign-in

Problems:

- Grocery loading automatically signs in anonymously when unauthenticated.
- This demo behavior hides authentication state problems and must be removed for a trustworthy baseline.
- Firebase ID tokens are stored in `SharedPreferences`.
- `hasValidToken()` checks only whether a token string exists, not whether it is current/valid.
- Duplicate switch cases exist in auth error handling.
- Google Sign-In objects are declared but a complete working Google auth flow is not established by the audited service.

### Firestore inventory

Classification: **REAL BUT WRONG OWNERSHIP MODEL**

Current structure:

`users/{userId}/groceryItems/{itemId}`

CRUD and stream methods exist.

Problems:

- FreshFlag requires household-owned inventory.
- Current model is single-user by design.
- Firestore failures can be masked by hard-coded dummy data in `GroceryViewModel`.
- `addGroceryItem()` lets Firestore generate a document ID but the local item retains its pre-existing `item.id`, creating a potential ID mismatch between the stored document and local object used for subsequent updates/deletes.

### Offline support

Classification: **README CLAIM NOT PROVEN**

Hive/local database code exists, but the audited main grocery workflow loads inventory from Firestore and substitutes dummy data on failure. A deliberate local-first/cloud-sync inventory flow was not demonstrated.

The README claim of "Local data with cloud sync" should not be treated as verified functionality.

### Barcode scanning

Classification: **CAMERA SCAN REAL; PRODUCT/ADD FLOW INCOMPLETE**

- `mobile_scanner` is used and actual barcode capture is implemented.
- Manual-entry fallback exists.

Critical gap:

`_proceedWithBarcode()` navigates to `AddItemScreen()` with a TODO to pass the barcode value. The scanned barcode is currently discarded.

There is no product lookup based on the scanned code.

Therefore "add by scanning barcodes" is not a working end-to-end feature.

### Product identification

Classification: **MISSING**

No Open Food Facts integration is present in the audited code path.

This remains FreshFlag Phase 2 work.

### Notifications

Classification: **LOCAL DEVICE REMINDERS EXIST; SHARED BACKEND REMINDERS MISSING**

Current implementation includes:

- notification permission requests
- FCM token retrieval
- FCM foreground/background listeners
- local notification scheduling
- multiple hard-coded expiry reminders

Problems:

- FCM tokens are not persisted into the FreshFlag-required user/device model.
- Expiry reminders are scheduled locally on each phone.
- No household notification rules exist.
- Reminder message templates are not configurable.
- No household timezone exists.
- Notification tap handlers contain TODOs and do not deep-link to an item.
- Local timezone uses `tz.local` rather than a household IANA timezone.

### Grocery expiry model

Classification: **FUNCTIONAL FOR DEMO, INCOMPATIBLE WITH FRESHFLAG SEMANTICS**

- Expiry is stored as `DateTime` and serialized using full ISO timestamp strings.
- FreshFlag requires date-only `YYYY-MM-DD` semantics.
- Model defines "expiring soon" as <= 3 days.
- README says <= 2 days.

### Image storage/backend architecture

Classification: **UNNECESSARILY MIXED**

The app uses Firebase for auth/database/messaging but includes Supabase for image storage and optional initialization.

FreshFlag architecture specifies Firebase as the backend platform. Supabase should be removed unless a concrete requirement justifies keeping it.

## iOS static audit

Classification: **PROJECT EXISTS BUT NOT READY FOR TESTFLIGHT**

Present:

- Xcode project/workspace
- Runner target
- Flutter project structure

Blockers/problems:

- App display/name still uses StayFresh branding.
- Firebase iOS options contain `YOUR_IOS_API_KEY` and placeholder app ID.
- Bundle ID remains `com.example.stayfresh` in generated Firebase configuration.
- No `GoogleService-Info.plist` was observed under `ios/Runner`.
- `ios/Runner/Info.plist` lacks `NSCameraUsageDescription` even though barcode scanning requires camera permission.
- Push notification/APNs capabilities cannot be considered configured from the committed static files alone.
- Actual Xcode build/signing/TestFlight verification must happen later on macOS.

## README accuracy audit

The current README must not be treated as source of truth.

Confirmed mismatches:

- Says barcode scanning can add items; scanned value is discarded before Add Item.
- Lists `flutter_barcode_scanner`; actual implementation uses `mobile_scanner`.
- Claims offline support/local-cloud sync; end-to-end behavior is not established.
- Describes a `GroceryItem` shape that does not match actual code.
- Says expiring soon is <= 2 days; model uses <= 3 days.
- Implies platform Firebase configuration that is not actually complete for iOS/web.

## Dummy/demo behavior that must be removed before Phase 1 exit

1. Automatic anonymous sign-in for grocery loading.
2. Silent hard-coded dummy inventory fallback on Firestore failure.
3. Any UI success state that hides persistence/authentication failures.

## Phase 0 decision

**CONTINUE WITH STAYFRESH AS SCAFFOLDING.**

Rationale:

- It compiles.
- It has a meaningful amount of usable Flutter UI/service code.
- Firebase Auth/Firestore/FCM and barcode camera integration are real rather than completely mocked.
- The defects are visible and tractable.
- Replacing the entire base now is not justified by the audit evidence.

However, Phase 1 must first create a trustworthy single-user foundation. Household work should not begin until the demo fallbacks, persistence identity issues, Firebase/iOS configuration gaps, and core tests are addressed.

## Phase 0 exit status

- [x] Exact upstream state recorded
- [x] Git history preserved
- [x] Flutter/Dart environment captured
- [x] Dependency resolution tested
- [x] Static analysis captured
- [x] Tests assessed
- [x] Native build viability demonstrated on Linux
- [x] Firebase/auth/Firestore audited
- [x] Barcode implementation audited
- [x] Notification implementation audited
- [x] README claims compared with source
- [x] iOS project statically inspected
- [x] Major blockers documented
- [x] Recommendation on starting codebase made
- [ ] Actual iOS compile/signing — deferred until macOS is available
- [ ] Android compile — optional/deferred

Phase 0 is considered complete for the purpose of choosing and understanding the starting codebase.

## Required first work in Phase 1

1. Establish a supported/reproducible Flutter dependency baseline.
2. Add real tests before changing persistence behavior.
3. Remove anonymous auto-login and dummy-data failure fallback.
4. Fix Firestore document/local item ID consistency.
5. Make authenticated single-user Firestore inventory trustworthy.
6. Convert expiry semantics to date-only representation.
7. Decide/remove Supabase dependency from the core architecture.
8. Create/configure a FreshFlag Firebase project and proper iOS app configuration.
9. Fix iOS permissions including camera usage description.
10. Only then proceed to Open Food Facts and household architecture.
