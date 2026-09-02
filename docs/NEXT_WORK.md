# FreshFlag — Next Work for Codex

> Current objective: verify the updated build's account-recovery behavior and keep SideStore distribution operational.

## Current phase

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

See `docs/PASSWORD_RECOVERY.md` for the recovery procedure.

## SideStore distribution state

Permanent source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

Current published release:

```text
Fresh Flag 0.1.1 (6)
```

Distribution is validated end-to-end: publication, source add, migration from manual IPA, update detection, and update installation.

### SideStore 0.6.3 workaround

A known SideStore 0.6.3 UI bug can show:

```text
Operation Failed
An unknown error occurred. (SideStore/AppManager.swift line 723)
```

when the Update button is tapped twice because the first tap starts work without immediately refreshing the button state.

Validated workaround:

1. tap Update exactly once;
2. immediately switch to **News** or another tab;
3. wait about 20–30 seconds;
4. return to **My Apps**.

Do not diagnose this specific behavior as a FreshFlag release failure.

## Next runtime sequence

Unless the user names another priority:

1. open Fresh Flag 0.1.1 (6) and verify household/inventory/session state survived the update;
2. test **Settings → Change password** on-device;
3. optionally re-test login with the new password;
4. investigate Firebase Auth email delivery separately if forgotten-password recovery by email remains unreliable;
5. prepare concise friend/family onboarding instructions for SideStore when needed.

## Authorization model

```text
owner
  - full household administration
  - member access management
  - notification rule management
  - inventory management

admin
  - normal shared inventory use
  - notification rule management
  - invite and member/guest management within the intended boundary
  - no ownership transfer

member
  - normal shared inventory use
  - no household access management

guest
  - read-only household/inventory/reminder-rule access
```

Authentication administration is deliberately outside this household role model.

## Validation discipline

Use the repository's prescribed commands from `AGENTS.md` for code changes. After meaningful implementation, validation, deployment, or release events, update:

- `docs/CURRENT_STATE.md`;
- `docs/NEXT_WORK.md`;
- `docs/DECISIONS.md` when architectural/product decisions change;
- `CHANGELOG.md` for meaningful implementation, deployment, validation, or release events.
