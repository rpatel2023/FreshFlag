# FreshFlag — Next Work for Codex

> Current objective: finish the notification-only Home Screen Web Push companion, open/land the PR, deploy it safely, and physically validate reminder delivery on iPhone.

## Current known-good state

- production Cloud Functions/Firestore rules for the existing native/Discord feature set are already deployed;
- the app is in normal household use on real devices;
- permanent SideStore release **0.1.0 build 5** is published;
- the permanent SideStore source is installed and managing the current app;
- PR #20 password-recovery hardening is merged to `main`;
- the source-based update path from build 5 to a later build remains unvalidated.

## Active branch

```text
feature/web-push-companion
```

This branch is intentionally isolated from the native product surface.

The PWA may only:

- authenticate an existing Fresh Flag account;
- register/unregister the current browser PushSubscription;
- request notification permission;
- send a test push;
- display expiry reminder notifications.

Do **not** add inventory, household, barcode, Activity, reminder-rule, expiry-calculation, or item-management behavior to the PWA.

See `docs/WEB_PUSH_COMPANION.md` and D-013 in `docs/DECISIONS.md`.

## Branch completion sequence

1. Finish implementation/tests on `feature/web-push-companion`.
2. Include the requested Add/Edit item expiry shortcuts for **+3 months, +6 months, +12 months, +18 months** as the final feature change in the same PR.
3. Run/verify backend CI and Flutter CI.
4. Fix CI failures without stopping for user input unless a genuine product/credential decision is required.
5. Open the PR to `main` with implementation summary, tests, deployment requirements, and physical-validation checklist.

## After merge — deployment

Web Push uses standards-based VAPID directly, not Firebase Messaging in the browser.

From `functions/` after dependencies are installed, generate one VAPID pair:

```bash
npx web-push generate-vapid-keys --json
```

Store the values as Functions secrets:

```bash
firebase functions:secrets:set WEB_PUSH_VAPID_PUBLIC_KEY
firebase functions:secrets:set WEB_PUSH_VAPID_PRIVATE_KEY
```

Then deploy:

```bash
firebase deploy --only functions,hosting
```

No Firestore-rule deployment is required unless the branch later changes `firestore.rules`.

## Physical iPhone validation

1. Open the hosted notification companion in Safari.
2. Share → **Add to Home Screen**.
3. Launch it from the Home Screen.
4. Sign in with an existing Fresh Flag Firebase account.
5. Tap **Enable notifications** and allow notifications.
6. Tap **Send test notification** and confirm it arrives.
7. Confirm disable/re-enable works and does not affect the native app.
8. Create/use a reminder rule due soon and confirm a real backend expiry reminder arrives through Web Push.
9. Confirm existing Discord/local reminder behavior still works independently.

## Then return to SideStore update proof

After Web Push validation, publish a SideStore build higher than `0.1.0 (5)` and verify SideStore surfaces/installs it as an update while preserving app data and expected auth state.

## Validation discipline

Use `AGENTS.md` commands for repository changes. Keep these updated after meaningful implementation/deployment/validation:

- `docs/CURRENT_STATE.md`;
- `docs/NEXT_WORK.md`;
- `docs/DECISIONS.md` when architectural/product decisions change;
- `CHANGELOG.md`.
