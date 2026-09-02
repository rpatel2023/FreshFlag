# FreshFlag — Next Work for Codex

> Current objective: finish the notification-only Home Screen Web Push companion, open/land the PR, deploy it safely, and physically validate reminder delivery on iPhone.

## Current known-good state

FreshFlag has completed the permanent SideStore distribution validation path:

- production backend/rules are deployed;
- permanent SideStore source exists;
- existing IPA/iLoader install was migrated into SideStore management;
- release **0.1.0 build 5** installed successfully from the source;
- release **0.1.1 build 6** was detected as an update over build 5;
- the source-based update installation completed successfully.

Do not repeat older source-add/migration/update-proof work unless a regression is reported.

## Password recovery state

PR #20 is merged and shipped in **0.1.1 (6)**.

Preserve these boundaries:

- Login → **Forgot password?** uses Firebase Authentication reset email.
- Production Gmail delivery was not observed during testing even when Firebase Console also triggered a reset; treat this as unresolved email delivery, not a client-wiring failure.
- Fresh Flag's success text must not guarantee inbox delivery.
- Signed-in users have **Settings → Change password**, using current-password reauthentication.
- Emergency project-operator reset remains local/Admin-SDK-only.
- Household Owner/Admin roles must never gain authentication-password reset authority over other users.

## Active branch

```text
feature/web-push-companion
```

The PWA is intentionally isolated from the native product surface. It may only:

- authenticate an existing Fresh Flag account;
- register/unregister the current browser PushSubscription;
- request notification permission;
- send a test push;
- display expiry reminder notifications.

Do **not** add inventory, household, barcode, Activity, reminder-rule, expiry-calculation, or item-management behavior to the PWA.

See `docs/WEB_PUSH_COMPANION.md` and D-013 in `docs/DECISIONS.md`.

## Branch completion sequence

1. Finish implementation/tests on `feature/web-push-companion`.
2. Keep the requested Add/Edit item expiry shortcuts for **+3 months, +6 months, +12 months, +18 months** in this same PR.
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

## Remaining smaller runtime checks

After Web Push validation, useful but non-blocking checks are:

1. confirm build 6 household/inventory/session state remains intact in normal use;
2. test **Settings → Change password** on-device;
3. investigate Firebase Auth email delivery separately if forgotten-password recovery by email remains unreliable.

## Validation discipline

Use `AGENTS.md` commands for repository changes. Keep these updated after meaningful implementation/deployment/validation:

- `docs/CURRENT_STATE.md`;
- `docs/NEXT_WORK.md`;
- `docs/DECISIONS.md` when architectural/product decisions change;
- `CHANGELOG.md`.
