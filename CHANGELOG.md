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

- Added Node 22 / TypeScript Firebase Functions with household-timezone reminder evaluation, deterministic idempotent delivery claims, FCM device fan-out, push opt-out handling, invalid-token cleanup and 45-day stale registration pruning.
- Removed inherited client-local expiry scheduling so backend FCM is the single expiry-reminder delivery path.
- Added Firestore Emulator authorization coverage for household isolation, owner-only rule management, self-only device records, valid/revoked/expired invites, escalation prevention, cross-household writes and backend-only delivery records.
- Final Phase 6 HEAD `614338b` passed Backend CI `31814348654` and Flutter CI `31814348291`.
- PR #5 merged to `main` as `0d847e5e0edc263e7c453eb3f584fa9580de4140`.
- Real Firebase deployment remains separate because it requires a configured FreshFlag Firebase project and production platform credentials.

## 2026-08-14 — Phase 7 notification deep linking — VALIDATED SOURCE

- Added validated expiry-notification payload routing using `householdId` + `itemId`, with compatibility for existing Phase 6 `expiry_reminder` messages.
- Added terminated-launch buffering and live notification-tap routing after authentication.
- Notification taps verify household access, switch active household when required, bind scoped inventory, fetch the exact item and open one reusable item-detail screen.
- Inventory cards use that same item-detail screen; consume/restore is available there.
- Missing/deleted items and lost household access degrade safely to user-visible messages.
- FCM tap listeners are installed before initial token retrieval so APNs/FCM token timing failures do not disable routing for the process lifetime.
- Added notification-target parser tests.
- CI was deliberately held until the branch was coherent. PR validation ran once: Flutter CI `31815377661` **success** and Backend CI `31815377826` **success**.
- CI workflows are now PR-only with client/backend path filters plus manual dispatch, preventing routine private-repo commits and unrelated subsystems from triggering needless Actions runs.
- PR #6 merged to `main` as `601791f696fa657ada927bb8febf8dc0d79af606`.
- Physical iPhone foreground/background/terminated push-tap behavior remains a TestFlight/device validation requirement.

## 2026-08-14 — MVP/TestFlight source-readiness pass — IN PROGRESS

Branch: `feature/mvp-readiness`.

Audit findings before source freeze:

- Newly created households do not yet receive the recommended default reminder rules, so notifications currently require manual rule setup.
- Household member management is incomplete: invitations exist, but view-members / member-leave / owner-remove-member flows still need completion and matching security tests.
- Notification preference state needs reconciliation with actual OS authorization so the backend does not treat an unset preference as an intentional opt-in.
- iOS project still uses inherited `com.example.stayfresh` bundle identifiers, placeholder iOS Firebase configuration, and has no committed Runner entitlements for Push Notifications. These production identity/credential items must not be guessed because they must match the final Apple/Firebase registration.

Plan: close the remaining source-level MVP gaps on this branch without push CI, then use one relevant PR validation cycle before the external Apple/Firebase provisioning step.
