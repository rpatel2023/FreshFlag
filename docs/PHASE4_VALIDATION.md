# Phase 4 Validation — Household Invitations

Validated on Ubuntu 24.04.4 with Flutter 3.47.0 / Dart 3.13.0.

## Implemented

- 12-character shareable invite codes.
- Owner create/copy/revoke flow.
- Join-by-code from first-run setup and Settings.
- Atomic membership + household + preferred-household update on acceptance.
- Invite expiry/revocation checks.
- Firestore authorization constraints for invite and membership mutations.

## Runtime validation

At branch HEAD `070520292497a23a800e9a5142e1a0791c761608`:

- `flutter test --no-pub`: 11 tests passed.
- `dart analyze`: no issues found.
- `flutter build linux --no-pub`: success.
- Working tree: clean.

## Deferred security validation

The rule source is present and statically reviewed, but Firestore authorization behavior must still be exercised against the Firebase Emulator Suite before production deployment. Required cases include unauthorized household reads, owner escalation, invalid/revoked/expired invite joins, cross-household writes, and attempts to alter another user's membership.
