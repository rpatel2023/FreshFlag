# FreshFlag Changelog

This file is the persistent project progress log. Update it after every important implementation, validation, architectural decision, or blocker so work never repeats unnecessarily.

## 2026-08-13 — Repository and Phase 0 baseline

- Created independent repository `rpatel2023/FreshFlag` while preserving StayFresh Git history.
- Development remotes: `origin` = `git@github.com:rpatel2023/FreshFlag.git`; `upstream` = `https://github.com/Dhiraj706Sardar/stayfresh.git`.
- Imported upstream SHA: `7431e9323ec448da843a4871ec94a0604557a224`.
- Added `UPSTREAM.md` and `docs/BASELINE_AUDIT.md`.
- Baseline environment: Ubuntu 24.04.4, Flutter 3.47.0 stable, Dart 3.13.0.
- Initial analyzer count: 30 issues. Initial upstream test file was empty.
- Decision: retain StayFresh only as scaffolding and establish a trustworthy FreshFlag foundation before household work.

## 2026-08-14 — Phase 1 stabilization — VALIDATED

- Replaced demo/anonymous auth with real Firebase email/password auth.
- Unified Add Item, Dashboard and Reminders around one Firestore-backed inventory state.
- Fixed deterministic document IDs and item serialization.
- Enforced date-only expiry (`YYYY-MM-DD`) with legacy timestamp compatibility.
- Removed Supabase and Hive inventory/user identity.
- Renamed package to `freshflag`; added initial Firestore rules and iOS camera permission/branding.
- Analyzer reduced from 30 issues to zero.
- Validation progressed from 3 to 4 tests through the stabilization slices with successful Linux builds.

## 2026-08-14 — Phase 2 barcode product recognition — VALIDATED

- Added Open Food Facts barcode lookup with narrow field selection and FreshFlag User-Agent.
- Recognized products prefill Add Item; unknown/incomplete/network failures fall back to manual entry while preserving barcode.
- Added `http` dependency and parser coverage.
- Ubuntu validation: **7 tests**, **0 analyzer issues**, Linux release build success.
- Generated dependency metadata committed as `50fccd5`.
- PR #1 merged to `main` as `7c85d1d434b9f64800808581f3e3717a926ca128`.

## 2026-08-14 — Phase 3 household-owned inventory — VALIDATED

- Added household/member domain and owner/member roles.
- Added first-household setup, preferred household selection and switching.
- Moved inventory to `households/{householdId}/items/{itemId}` with audit fields.
- Added Firestore snapshot subscriptions for real-time shared inventory.
- Tightened household/member/item security rules.
- Ubuntu validation: **9 tests**, **0 analyzer issues**, Linux release build success, clean tree.
- PR #2 merged to `main` as `ccf57560b61ba8f2b11fe422d46dd39860fcb982`.

## 2026-08-14 — Phase 4 household invitations — VALIDATED

- Added non-enumerable 12-character invite codes with owner create/copy/revoke.
- Added join-by-code from first-run setup and Settings.
- Invite acceptance atomically adds the signed-in member, updates `memberUids`, and sets `currentHouseholdId`.
- Added invite security constraints and model tests.
- Ubuntu validation: **11 tests**, **0 analyzer issues**, Linux release build success, clean tree.
- PR #3 merged to `main` as `fc41e3dd9ba65ec0ac9233733a273a269464fe34`.
- Emulator-backed rules testing moved into Phase 6 as a release blocker.

## 2026-08-14 — Phase 5 household notification rules — VALIDATED

- Added configurable household reminder rules: days-before, title/body templates, strict household-local `HH:mm` send time, enabled state, timestamps.
- Supported variables: `{item}`, `{days}`, `{expiry_date}`, `{quantity}`, `{location}`.
- Added owner-managed rule UI and snapshot-driven rule service.
- Added stable per-install random `deviceId`; FCM token/platform/`lastSeenAt` persist at `users/{uid}/devices/{deviceId}` and refresh after auth/token rotation.
- Added backend-visible `notificationsEnabled` user preference.
- Added self-only device rules, member-readable/owner-managed notification-rule rules, and client denial for `notificationDeliveries`.
- Added reproducible `.github/workflows/flutter-ci.yml` so ordinary Flutter validation no longer requires the user's Ubuntu machine.
- GitHub Actions run `31812811363` passed end-to-end: dependency resolution/lockfile reproducibility, **14 tests**, **0 analyzer issues**, Linux release build success.
- PR #4 merged to `main` as `35fcdf8aff1ae44e74d45ecae8219ddeae1c81b2`.

## 2026-08-14 — Phase 6 scheduled notification backend — VALIDATED SOURCE

Branch: `phase6-notification-backend`.

### Backend worker

- Added Node 22 / TypeScript Firebase Functions package with strict build configuration and pinned top-level backend dependencies.
- Added pure reminder scheduling helpers using Luxon for household IANA timezones.
- Added deterministic delivery ID exactly from `householdId + itemId + ruleId + expiryDate + recipientUid`.
- Added tests for household-local send windows, cross-midnight windows, template rendering and delivery ID determinism.
- Added `processExpiryReminders` Cloud Functions v2 scheduled worker every five minutes.
- Worker evaluates enabled household rules in household-local time, queries matching unconsumed items, honors user push opt-out, fans out to active device registrations, and records an idempotent delivery ledger.
- Delivery claims use a 15-minute lease so retries do not double-send while crashed/stale claims can recover.
- Invalid FCM registrations are removed after messaging errors.
- Added daily stale-device pruning for registrations older than 45 days.
- Updated `firebase.json` for Functions and Firestore Emulator configuration.
- Removed the inherited client-side expiry scheduling calls and stopped initializing the legacy local reminder scheduler. Backend FCM is now the single expiry-reminder delivery path.

### Security validation harness

- Made invite acceptance an explicit write-only batch: an outsider reads only the invite, creates their own membership and membership-array update atomically, then reads the household only after becoming a member.
- Added Firestore Emulator tests using `@firebase/rules-unit-testing` 5.0.1 and Firebase CLI 15.24.0.
- Authorization coverage proves member-vs-outsider household reads, owner-only reminder management, self-only device registration, valid invite self-join, revoked/expired invite rejection, owner escalation rejection, cross-household item write rejection, and client denial of `notificationDeliveries`.
- Added `.github/workflows/backend-ci.yml` for Functions and Firestore Emulator validation.

### Validation and integration

- Backend CI run `31813905317`: **success** — Functions TypeScript build/tests and all Firestore Emulator authorization tests passed.
- Flutter CI run `31813905459`: **success** — dependency/lockfile check, **14 tests**, analyzer, and Linux release build all passed after removing local reminder scheduling.
- Final pinned backend dependencies revalidated in Backend CI run `31814127517`: Functions tests passed and Firestore Emulator tests passed.
- Final Phase 6 HEAD `614338b` revalidated by Backend CI run `31814348654` and Flutter CI run `31814348291`; both succeeded.
- PR #5 merged to `main` as `0d847e5e0edc263e7c453eb3f584fa9580de4140`.

Result: Phase 6 source is integrated. Real Firebase deployment remains separate because it requires a configured FreshFlag Firebase project, billing/runtime access, and production platform credentials.

## 2026-08-14 — Phase 7 notification deep linking — VALIDATED SOURCE

- Added a narrow `NotificationTarget` parser that accepts only expiry-reminder payloads containing both `householdId` and `itemId`; Phase 6 `expiry_reminder` payloads remain backward compatible.
- FCM preserves terminated-launch notification targets until the authenticated app shell is ready and emits background notification-tap targets to the live shell.
- FCM message/tap listeners are installed before initial token lookup so an early Apple/APNs token timing failure cannot disable deep-link handling for the process lifetime.
- Enabled foreground Apple notification presentation for physical-device validation.
- Notification taps verify target household access, switch households if needed, bind scoped inventory, fetch the exact item, switch to Inventory, and open a reusable item-detail screen.
- Missing/deleted items and lost household access degrade to a user-visible message rather than an invalid route.
- Inventory rows reuse the same item-detail view; users can mark items consumed or restore them there.
- Added notification payload parser tests for canonical, legacy, unrelated, and incomplete payloads.
- CI was changed to PR-only plus manual dispatch with path filters so feature-branch pushes do not consume private-repo Actions runs.

Validation/integration:

- PR #6 (`feature/notification-deep-links`) passed Flutter CI run `31815377661` and Backend CI run `31815377826`, then merged to `main` as `601791f696fa657ada927bb8febf8dc0d79af606`.
- Follow-up PR #7 canonicalized newly emitted backend payloads to `type: expiry` while preserving legacy client parsing.
- PR #7 triggered Backend CI only; Functions tests and Firestore Emulator authorization tests passed in run `31818961866`.
- PR #7 merged to `main` as `6769dbda94dd2ee8b658777769e2fcd9cf64e263`.

Result: Phase 7 source is complete. Foreground/background/terminated notification taps still require physical-iPhone validation in Phase 8.

## 2026-08-14 — Phase 8 iOS/TestFlight preparation — SOURCE CHECKPOINT VALIDATED

Branch: `phase8-testflight-prep`.

### Documentation/source-of-truth baseline

- Restored `PROJECT_CONTEXT.md` to the repository as the product source of truth, updated to reflect the current phase map and preserved product constraints.
- Added `ARCHITECTURE.md` describing the implemented client, household, security, notification, backend, CI, and remaining iOS gates.
- Added `THIRD_PARTY_NOTICES.md` covering StayFresh provenance, Open Food Facts external data, Flutter/Firebase dependencies, and GPL/AGPL reference-only projects.
- Added `docs/testflight.md` with Firebase, Apple signing, Swift Package Manager, backend deployment, physical-device acceptance, App Store Connect, and TestFlight steps.
- Rewrote the stale Phase 1 README so it describes the current Phase 8/TestFlight state.

### Platform audit findings

- `ios/Runner` contains no production `GoogleService-Info.plist` and no Runner entitlements file yet.
- The legacy Xcode project has no existing Swift Package Manager package reference and no legacy CocoaPods `Podfile`.
- Modern Flutter uses Swift Package Manager for current iOS plugin integration; the old Xcode shell will be migrated/validated on macOS rather than manually fabricating package objects in the legacy `.pbxproj`.
- Actual signing, APNs, archive, and TestFlight validation require macOS/Xcode and Apple/Firebase project access.

### Source-only TestFlight preparation completed

- Removed all inherited `stayfresh-36edf` values from `lib/firebase_options.dart` and replaced them with an explicit safe stub that instructs developers to run `flutterfire configure` against the FreshFlag-owned Firebase project.
- Deleted inherited `android/app/google-services.json`, preventing accidental Android writes to the upstream StayFresh Firebase project.
- Removed unused iOS photo-library permission; camera permission remains with FreshFlag-specific usage text.
- Standardized Android namespace/application ID and Kotlin activity package on `com.rpatel2023.freshflag`; Android label is now `FreshFlag` and inherited Google Services Gradle wiring/direct native Firebase declarations were removed.
- Set beta package version to `0.1.0+1`.
- Removed dead `flutter_local_notifications` and `timezone` dependencies after backend FCM became the sole authoritative reminder path.
- Removed the obsolete `flutter_launcher_icons` configuration/dev dependency that still targeted StayFresh artwork.
- Removed inherited `assets/images/logos/stayfresh.png`.
- Added `tool/generate_freshflag_icons.py`, a dependency-free deterministic generator for a FreshFlag flag/sprout master icon and every PNG referenced by the iOS AppIcon asset catalog.
- Added `tool/set_freshflag_bundle_ids.py` to migrate the legacy Xcode app/test bundle identifiers to `com.rpatel2023.freshflag` without manually editing the large Xcode project.
- Added `tool/phase8_local_checkpoint.sh` to perform both deterministic migrations, resolve Flutter dependencies once, run tests/analyzer/Linux release build, and verify inherited Firebase/application identifiers are gone.

### First Ubuntu regeneration checkpoint and source fixes

- Local helper successfully replaced **6** inherited Xcode bundle-ID occurrences with `com.rpatel2023.freshflag`.
- Local helper generated **21** iOS AppIcon PNGs plus `assets/images/logos/freshflag.png`.
- `flutter pub get` removed **17** obsolete transitive/direct packages after the intentional dependency cleanup.
- Flutter tests passed: **17/17**.
- Analyzer initially failed with **55 issues**, all but two caused by one inherited `lib/services/notification_service.dart` file that still imported/used the deliberately removed local-notification/timezone packages.
- Source fix: deleted the unused legacy `NotificationService`; backend FCM remains the sole notification implementation.
- Source fix: auth initialization now reuses the already-resolved `HouseholdViewModel` instance after the async FCM registration step rather than reading it from `BuildContext` after an await.
- Source fix: reminder-rule action layout now uses `OverflowBar` instead of deprecated `ButtonBar`.

### Successful Ubuntu source checkpoint

- Second `tool/phase8_local_checkpoint.sh` run completed successfully.
- Flutter tests: **17/17 passed**.
- `dart analyze`: **No issues found**.
- Linux release build: **success**.
- Identity checks confirmed **no `stayfresh-36edf` Firebase project reference** and **no `com.example.stayfresh` application identifier** remain.
- Xcode app/test bundle identifiers are now materialized as `com.rpatel2023.freshflag` / `.RunnerTests`.
- FreshFlag 1024×1024 master icon and all **21** iOS AppIcon renditions were generated successfully.
- Generated `pubspec.lock`, macOS plugin registrant, Xcode bundle IDs and icon assets were committed/pushed as `4a46ea3`.
- Ubuntu working tree was clean after that commit.
- Added `docs/PHASE8_SOURCE_VALIDATION.md` as the durable source-validation record and explicit list of remaining external Firebase/macOS/Apple gates.
- PR #8 triggered exactly one Flutter CI run (`31825161104`); lockfile reproducibility, tests, analyzer, and Linux release build all passed.
- PR #8 merged to `main` as `2f63b10cd4d03f5c7d11276e731753fe5014bc18`.

Result: Phase 8 source prep is integrated. Remaining external work is FreshFlag Firebase project configuration/deployment and iOS build/signing/sideload validation.

## 2026-08-14 — Discord household reminder channel + dark mode — VALIDATED SOURCE

Branch: `feature/discord-reminders`.

### Distribution decision

- Private-household distribution target is SideStore/free Apple Account first rather than paying the Apple Developer Program annual fee solely for two-person use.
- Ubuntu remains the source machine; Windows may be used for the initial SideStore/iPhone bootstrap; a manually-invoked macOS CI builder can later create the unsigned iOS artifact when required.
- Native FCM/APNs remains supported where available, but reminder reliability must not depend on APNs being available under free sideload signing.
- Discord is therefore implemented as a parallel household reminder delivery channel, not merely as a response to an FCM API failure. An FCM send acknowledgement does not prove that a sideloaded iPhone displayed the notification.

### Backend Discord milestone

- Selected Discord incoming webhooks instead of a persistent bot. One webhook maps a FreshFlag household to a shared Discord channel.
- Added `functions/src/discord_delivery.ts` with strict HTTPS Discord-host/path validation, deterministic Discord delivery IDs, structured embed payloads, and outbound webhook POST support.
- Discord payloads set `allowed_mentions.parse` to an empty list so user-derived item/template text cannot trigger `@everyone`, role, or user mentions.
- Discord reminders are emitted once per household/item/rule/expiry event rather than once per household member, preventing duplicates in the shared channel.
- Discord has its own idempotent `notificationDeliveries` claim while FCM keeps its per-recipient delivery IDs; both reuse the existing 15-minute claim/retry mechanism.
- Added callable backend endpoints for integration status, owner-only save/enable/disable, and owner-only test delivery. Webhook URLs are never returned to the Flutter client.
- Stored Discord secrets at backend-only `householdIntegrations/{householdId}` documents.
- Firestore rules explicitly deny all client reads/writes of `householdIntegrations`, including the household owner. Owners manage the secret only through authenticated callable functions.
- Added Discord helper unit tests and a Firestore Emulator security assertion that the integration secret remains inaccessible to clients.
- Updated Functions test discovery to execute all compiled `*.test.js` files.

### Flutter Discord client milestone

- Added `cloud_functions 4.7.6`, matching the existing FlutterFire generation rather than forcing a broad Firebase SDK upgrade.
- Added `DiscordReminderService` for authenticated callable status/save/test operations; the webhook secret is never read back from the backend.
- Added household Settings UI with owner-only webhook entry/replacement, enable/disable toggle, and test-message action; members can only see integration status.
- Webhook entry is obscured, suggestions/autocorrect are disabled, and the field is cleared after a successful save.
- Added Discord integration-status parser tests.
- First Ubuntu dependency checkpoint after adding `cloud_functions`: **19/19 tests passed**, **0 analyzer issues**, Linux release build succeeded.
- `flutter pub get` added only the expected `cloud_functions`, `cloud_functions_platform_interface`, and `cloud_functions_web` packages. Flutter's incidental `analysis_options.yaml` rewrite was intentionally discarded.

### Dark mode completion

- Dark-mode preference and Settings toggle already existed and persisted through `SharedPreferences`, but several screens still forced light-only backgrounds/text through the inherited `AppTheme` constants.
- Consolidated the active Material theme on the FreshFlag green palette and added complete light/dark `ThemeData` for app bars, cards, inputs, navigation, buttons, dividers, chips, and scaffolds.
- Removed hardcoded light scaffold backgrounds from login/signup, household setup/sharing, inventory, add-item, item detail, reminders, reminder rules, Settings, and Discord Settings.
- Inventory/item-detail/navigation accents now derive from the active color scheme rather than light-only green surfaces.
- Added theme regression tests proving distinct light/dark brightness and surface values.
- Combined Ubuntu validation after the dark-mode cleanup: **21/21 tests passed**, `dart analyze` reported **No issues found**, and the Linux release build succeeded.
- Generated `pubspec.lock` and macOS plugin registrant were committed as `84bc086` after rebasing the local metadata commit onto the latest branch.

### PR #9 validation and integration

- PR #9 (`Add Discord reminder fallback and complete dark mode`) opened from `feature/discord-reminders` to `main`.
- Initial Backend CI exposed one TypeScript compile error: the shared `ReminderItemData.location` is optional while `DiscordReminderPayload.location` incorrectly required explicit `string | null`.
- Fixed the type contract so Discord reminder payloads accept omitted/null locations (`c83fd342`) and added a regression test proving location-less reminders omit the Location field (`09e295a`).
- Final Backend CI run `31828335280`: **success** — Functions TypeScript build/tests and Firestore Emulator authorization tests both passed.
- Final Flutter CI run `31828335313`: **success** — dependency resolution and lockfile reproducibility passed, **21 tests** passed, analyzer passed, and Linux release build succeeded.
- PR #9 merged to `main` as `82fc45c8d11d167a82cc5304433605928e1e8550`.

Result: Discord reminder fallback and app-wide dark mode are integrated and source-validated. Real Discord delivery still requires the FreshFlag Firebase backend to be deployed and a household Discord webhook to be configured; iPhone/SideStore validation remains part of the external deployment phase.

## 2026-08-14 — Discord per-user delivery redesign — VALIDATED SOURCE

Branch: `feature/per-user-discord`.

### Product decision

- Superseded the household-level/shared-channel Discord configuration before production deployment.
- Discord is now a personal delivery preference: each signed-in FreshFlag user may configure their own webhook, independently enable/disable it, and point it to a different Discord channel.
- Household notification rules remain authoritative for **when and what** is due; FCM and Discord are per-recipient delivery channels.
- No production data migration is required because the FreshFlag Firebase project has not yet been deployed.

### Backend and idempotency redesign

- Moved active Discord secret storage from `householdIntegrations/{householdId}` to backend-only `userIntegrations/{uid}`.
- Discord callable status/save/test endpoints now derive the target user solely from authenticated `request.auth.uid`; no household ID or household-owner role is required.
- Webhook URLs are still normalized to approved Discord HTTPS webhook hosts/paths and are never returned to Flutter.
- Scheduled reminder processing enters the household member loop first, lazily loads/caches that member's Discord integration only for actually due reminder events, and sends Discord independently of the FCM/device path.
- A user's FCM `notificationsEnabled` preference and device availability do not suppress that user's enabled Discord delivery.
- Discord delivery IDs now include `recipientUid` plus a Discord channel discriminator, preventing collisions between two household members or with the FCM ledger.
- Added backend regression coverage proving Discord delivery identity changes when the recipient changes.

### Security and Flutter client redesign

- Firestore rules explicitly deny all direct client access to `userIntegrations/{uid}`, including access by the user whose webhook is stored there.
- Retained an explicit deny rule on abandoned `householdIntegrations/{householdId}` for defense-in-depth if old development data ever exists.
- Updated the Firestore Emulator test to prove a user cannot directly read/write their own integration secret or another user's integration document.
- `DiscordReminderService` no longer sends household IDs to status/save/test callable Functions.
- Discord Settings no longer depends on the active household or owner role; every signed-in user gets connect/replace, enable/disable, and test controls for their own webhook.
- Moved the Discord Settings entry from household administration into the personal preferences card beside push notifications and dark mode.
- Updated `ARCHITECTURE.md` and `PROJECT_CONTEXT.md` so per-user Discord is now the authoritative product/technical design.

### PR #10 validation and integration

- PR #10 (`Make Discord reminders per user`) validated the redesign without any dependency/generated-file changes.
- Backend CI run `31829908789`: **success** — Functions TypeScript build/tests and Firestore Emulator authorization tests both passed.
- Flutter CI run `31829908749`: **success** — dependency resolution and lockfile reproducibility passed, **21 tests** passed, analyzer passed, and Linux release build succeeded.
- PR #10 merged to `main` as `dc522d4d2fb1bd9fd9cc8f961767c707c36c74b5`.

Result: per-user Discord reminder delivery is integrated and source-validated. Real delivery still requires deployment of the FreshFlag Firebase backend plus each user's personal Discord webhook configuration; no household-level Discord setup is required.

## 2026-08-14 — Firebase production setup — EXTERNAL CHECKPOINT

- Created Firebase project `FreshFlag` with project ID `freshflag`.
- Enabled Firebase Authentication Email/Password provider.
- Created the `(default)` Cloud Firestore Standard database in `us-central1` using production-mode starter rules.
- Upgraded the Firebase project to the Blaze plan and configured the billing budget alert during setup.
- Ubuntu runtime currently has Node `v20.20.2` and npm `11.12.1`.
- Initial `npm install -g firebase-tools` failed with `EACCES` because npm's global prefix targeted `/usr/lib/node_modules` for the unprivileged user.
- Configured user-owned npm global prefix at `~/.local/npm`, added its `bin` directory to `PATH`, and installed Firebase CLI successfully without `sudo`.
- Firebase CLI version verified as `15.27.0`.
- Next: authenticate the CLI with `firebase login`, confirm the `freshflag` project is visible, then install/verify FlutterFire CLI.

### Firebase CLI, FlutterFire, and iOS app registration

- Firebase CLI authenticated successfully with the Google account that owns the FreshFlag project.
- `firebase projects:list` still returns an empty list even though the request succeeds with HTTP 200; direct project operations against `freshflag` work correctly.
- Confirmed Google Cloud project has `firebase=enabled` and the Firebase Management API enabled.
- Bound the repository to the production Firebase project with `firebase use freshflag`.
- Installed FlutterFire CLI `1.4.1` and added `$HOME/.pub-cache/bin` to the shell `PATH`.
- Synced the Ubuntu checkout to clean `main` at `e803af6`.
- `flutterfire configure --project=freshflag` cannot proceed because FlutterFire depends on the empty Firebase project-list result.
- Bypassed that discovery issue using the Firebase CLI directly.
- Registered Firebase iOS app `FreshFlag` with bundle ID `com.rpatel2023.freshflag`.
- Firebase iOS App ID: `1:765920629957:ios:7e3a403712197ed143ccac`.
- Next: retrieve the iOS Firebase SDK configuration directly with `firebase apps:sdkconfig`.

### Production iOS Firebase configuration — VALIDATED

- Retrieved the production iOS Firebase SDK configuration directly with `firebase apps:sdkconfig`.
- Added `ios/Runner/GoogleService-Info.plist` for Firebase project `freshflag` and bundle ID `com.rpatel2023.freshflag`.
- Replaced the temporary `lib/firebase_options.dart` stub with the real FreshFlag iOS Firebase options.
- Non-iOS platforms remain explicitly unsupported by `DefaultFirebaseOptions` until their own Firebase apps are intentionally registered.
- Ubuntu validation after installing the real Firebase options:
  - `dart analyze`: **No issues found**.
  - `flutter test`: **21/21 passed**.
- Flutter's incidental `analysis_options.yaml` rewrite was discarded; the working tree returned clean.
- Next production deployment step: deploy the tested Firestore security rules before deploying Cloud Functions.

### Cloud Functions dependency audit — REMEDIATED

- Installed the Functions dependency tree under Node 22 and built the TypeScript backend successfully.
- `npm audit --omit=dev` initially reported 7 moderate vulnerabilities through transitive `uuid@9.0.1` dependencies under Google/Firebase packages.
- Did not use `npm audit fix --force` because it proposed a breaking downgrade of `firebase-admin`.
- Added scoped npm overrides so `gaxios` and `teeny-request` resolve `uuid` to `^11.1.1`.
- Reinstalled dependencies from a fresh lockfile.
- Production dependency audit now reports **0 vulnerabilities**.
- Functions validation after the override:
  - backend tests: **9/9 passed**
  - TypeScript build: **success**
- Generated `functions/lib/` and `functions/node_modules/` were removed and are not committed.
- `functions/package-lock.json` is now committed for reproducible backend dependency resolution.

### Production Firebase backend deployment — COMPLETE

- Deployed the tested Firestore security rules to Firebase project `freshflag`.
- Installed and switched the Ubuntu Functions runtime to Node.js 22 using `nvm`.
- Resolved the Functions production dependency audit to **0 vulnerabilities** with scoped `uuid` overrides and a committed `functions/package-lock.json`.
- Initial Cloud Functions deployment partially succeeded because the shared Gen 2 source bucket creation returned HTTP 409 during concurrent first-time provisioning.
- Retried the deployment after the source infrastructure existed; all remaining functions deployed successfully.
- Configured Artifact Registry cleanup to automatically delete container images older than **7 days**.
- Verified the production Functions inventory:
  - `getDiscordIntegrationStatus` — v2 callable, 256 MB, Node.js 22
  - `setDiscordIntegration` — v2 callable, 256 MB, Node.js 22
  - `testDiscordIntegration` — v2 callable, 256 MB, Node.js 22
  - `processExpiryReminders` — v2 scheduled, 512 MB, Node.js 22
  - `pruneStaleDeviceRegistrations` — v2 scheduled, 256 MB, Node.js 22
- All Functions are deployed in `us-central1`.

### SideStore release preparation + item location support — VALIDATED

- Added optional inventory storage location persistence to `GroceryItem`.
- Add Item now accepts an optional storage location such as fridge, freezer, or pantry.
- Item details now display the stored location.
- This completes the inventory data path for reminder template variable `{location}`; the deployed backend already reads `item.location`.
- Added persistence coverage for item location while preserving compatibility with existing records that have no location.
- Added `.github/workflows/ios-sidestore-build.yml`.
  - Manual `workflow_dispatch` only.
  - Uses a GitHub macOS runner only when an iOS artifact is intentionally requested.
  - Runs Flutter tests and analyzer before building.
  - Builds the iOS release without code signing.
  - Verifies bundle ID `com.rpatel2023.freshflag`.
  - Places the production `GoogleService-Info.plist` into the final app bundle.
  - Packages `Payload/FreshFlag.app` as `FreshFlag-unsigned.ipa`.
  - Retains the workflow artifact for 7 days.
- Added `docs/sideload.md` as the SideStore-first private distribution and two-device acceptance runbook.
- PR #11 Flutter CI run `31841194028`: **success**.
- PR #11 merged to `main` as `e77f40669dd948bf4e539f8ec9938e7fe4aded18`.
- Next external gate: run the manual macOS SideStore IPA workflow and validate the resulting unsigned IPA.
