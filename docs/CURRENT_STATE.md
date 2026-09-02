# FreshFlag — Current Implementation State

> Last updated from project conversation: 2026-09-02
> Purpose: Tell a coding agent what is true *now*, not what the original design spec planned.

## Product identity

The project is **FreshFlag**, an iPhone food-expiry tracker built with Flutter and Firebase. The current private-distribution path is **SideStore**, using zero-fee unsigned IPA builds that are signed by each user's own Apple Account.

```text
scan / add item
→ set expiry
→ shared household inventory
→ reminders
→ consume / restore
```

`PROJECT_CONTEXT_ORIGINAL.md` contains the original product definition and architecture intent. This file overrides it where implementation has moved beyond the original phase plan.

## Confirmed working behavior

### Real-device use

- FreshFlag has completed its earlier structured real-device acceptance-testing phase.
- A second household user has installed/joined successfully.
- Shared household inventory and realtime two-iPhone synchronization work.
- The app has been in normal household use for several days.
- Do not send the user back through old build/install or PR #15–#18 acceptance gates unless a new regression is reported.

### Item lifecycle and household access

- Consume/restore works across devices.
- Consumed items remain reachable through explicit Active / Consumed views.
- Household roles Owner/Admin/Member/Guest are implemented.
- **Members & access** is implemented.
- Guest household access is read-only and enforced in Firestore/backend rules.
- Personal Favourites remain per-user, not household-owned.

### Reminders and newer source batch

The current app/backend includes:

- English-preferred Open Food Facts lookup;
- household barcode product cache/backfill;
- persistent custom categories;
- granular Discord item activity opt-ins;
- household activity feed and Activity tab;
- SideStore-local expiry reminders from synced inventory.

The corresponding Cloud Functions and Firestore rules are already deployed.

## Password recovery

PR #20 merged to `main` as `df32acbfe4e699a27845dff25b40587dc697ffa9` and is published in **Fresh Flag 0.1.1 (6)**.

Current design:

- Login → **Forgot password?** uses Firebase Authentication reset email.
- Firebase accepts the reset request from both FreshFlag and Firebase Console, but production Gmail delivery was not observed during testing. Treat email delivery as **unresolved**, not confirmed working.
- The login confirmation deliberately avoids claiming guaranteed delivery.
- Signed-in users now have **Settings → Change password**, with current-password reauthentication before updating the password.
- A local-only Firebase Admin SDK operator recovery command exists for emergency account recovery.
- Household Owner/Admin roles do **not** gain the ability to change another user's authentication password.

See `docs/PASSWORD_RECOVERY.md` for the operator procedure and security boundary.

## SideStore distribution

Permanent source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

One-tap source link:

```text
sidestore://source?url=https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

Validated milestones:

- **0.1.0 (5)** published successfully with `FreshFlag.ipa` and `source.json`.
- The permanent Fresh Flag source was added successfully on-device.
- An existing IPA/iLoader-installed FreshFlag was migrated in-place into SideStore management without uninstalling.
- Fresh Flag appeared under **My Apps** with a fresh 7-day signing window.
- **0.1.1 (6)** was published successfully from PR #20.
- SideStore correctly detected 0.1.1 (6) as an update over installed build 5.
- The build 5 → build 6 update completed successfully through the permanent source.

### SideStore 0.6.3 update UI bug

SideStore 0.6.3 has a known UI bug where the first Update tap may begin the update without visually changing the button. Tapping a second time can trigger:

```text
Operation Failed
An unknown error occurred. (SideStore/AppManager.swift line 723)
```

Working workaround validated on-device:

1. tap **Update exactly once**;
2. immediately switch to another tab such as **News**;
3. wait about 20–30 seconds;
4. return to **My Apps**.

The update then completes normally. Do not treat this SideStore UI bug as a FreshFlag packaging failure.

## Current known gaps / validation still useful

- No current blocking product gap is documented.
- SideStore source publication, source migration, update discovery, and update installation are validated end-to-end.
- Password-reset email delivery through Firebase remains unresolved in production Gmail testing.
- **Settings → Change password** still needs a simple on-device functional test.
- After build 6, app data/session continuity should be spot-checked if not already observed in normal use.

## Current priority

Unless the user names another priority:

1. open Fresh Flag after the build 6 update and confirm household data/session state is intact;
2. test **Settings → Change password** on-device;
3. separately investigate Firebase Auth email-delivery reliability if forgotten-password email recovery is still required;
4. then treat SideStore distribution as fully operational for friends/family, with the 0.6.3 workaround documented until SideStore 0.6.4+ is adopted.

Do **not** repeat Firebase deployment or generic source-add/install work unless a newer change requires it.

## Evidence hierarchy

When documentation disagrees, use this order:

1. explicit newer runtime/deployment confirmation from the user;
2. current repository behavior + tests + Firestore rules;
3. this `CURRENT_STATE.md` file;
4. `DECISIONS.md`;
5. original `PROJECT_CONTEXT_ORIGINAL.md` phase plan.
