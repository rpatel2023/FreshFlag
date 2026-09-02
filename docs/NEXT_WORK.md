# FreshFlag — Next Work for Codex

> Current objective: publish PR #20 password-recovery improvements as the next SideStore release and validate the source-based update path.

## Current phase

FreshFlag is beyond the earlier PR #15–#18 acceptance phase, backend deployment gate, and first permanent SideStore source-install/migration test.

Current known-good state:

- production Cloud Functions/Firestore rules for the current source batch are already deployed;
- the app has been in normal household use on real devices;
- permanent SideStore release **0.1.0 build 5** is published;
- the permanent Fresh Flag source has been added successfully on-device;
- the previous IPA/iLoader-installed FreshFlag was migrated into SideStore management without uninstalling;
- PR #20 password-recovery hardening is merged to `main` as `df32acbfe4e699a27845dff25b40587dc697ffa9`.

Do not repeat older deployment, generic install, or source-add steps unless a regression is reported.

## Password recovery state

Preserve the following design:

- Login → **Forgot password?** uses Firebase Authentication reset email.
- Production testing confirmed Firebase reset emails are sent; they were initially hard to locate, not actually absent.
- The app must not claim guaranteed inbox delivery merely because Firebase accepted the request.
- Signed-in users can use **Settings → Change password**, with current-password reauthentication.
- Emergency project-operator reset remains local/Admin-SDK-only.
- Household Owner/Admin roles must never gain authentication-password reset authority over other users.

See `docs/PASSWORD_RECOVERY.md` for the recovery procedure.

## SideStore distribution state

PR #19 added the publisher-side release path.

Permanent source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

Current published release:

```text
Fresh Flag 0.1.0 (5)
```

Source installation/migration is already validated. The remaining proof is **update detection and update installation**.

## Next runtime sequence

Unless the user names another priority:

1. publish the merged password-recovery change as the next SideStore release, using a version/build greater than `0.1.0 (5)`;
2. refresh/check the Fresh Flag source on an iPhone currently running build 5;
3. confirm SideStore surfaces the new release as an **Update** rather than requiring another manual IPA/source migration;
4. install the update without deleting Fresh Flag;
5. verify household/app data and expected auth state survive the update;
6. test **Settings → Change password** on-device;
7. optionally re-test **Forgot password?** and confirm the Firebase reset email/link path still works;
8. once the update path passes, treat the SideStore distribution mechanism as fully validated for friends/family.

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
