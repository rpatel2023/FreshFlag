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

## 2026-08-14 — Phase 7 notification deep linking — IN PROGRESS

Branch: `phase7-notification-deeplinks`.

- Added a narrow `NotificationTarget` parser that accepts only expiry-reminder payloads containing both `householdId` and `itemId`; Phase 6 `expiry_reminder` payloads remain backward compatible.
- New backend notifications now emit the canonical `type: expiry` payload while the client continues accepting the Phase 6 legacy type during migration.
- FCM preserves terminated-launch notification targets until the authenticated app shell is ready and emits background notification-tap targets to the live shell.
- FCM message/tap listeners are installed before initial token lookup so an early Apple/APNs token timing failure cannot disable deep-link handling for the process lifetime.
- Enabled foreground Apple notification presentation so physical-device testing can verify foreground, background, and terminated tap behavior.
- Notification taps verify the target household is one the signed-in user can access, switch households when required, bind the scoped inventory, fetch the exact item, switch to the Inventory tab, and open the item detail screen.
- Missing/deleted items and lost household access degrade to a user-visible message rather than an invalid route.
- Added a reusable item detail view and made ordinary inventory rows open the same view; users can mark an item consumed or restore it from there.
- Added notification payload parsing tests for current, legacy, unrelated, and incomplete payloads.

### CI cost-control decision

- Feature work is accumulated before a PR is opened; CI is not used as an edit-by-edit feedback loop.
- Flutter and Backend workflows are PR-only (plus manual dispatch) with path filters, so ordinary feature-branch pushes do not trigger private-repo Actions runs.
- Phase 7 will use one coherent PR validation cycle after source review; because this slice touches both Flutter deep-link code and the backend payload type, both relevant workflows are expected to run once.

Current checkpoint: source review is complete except for final branch-diff inspection. Open one Phase 7 PR, validate it once, then merge if green. Physical iPhone notification-tap validation remains a Phase 8/TestFlight requirement.
