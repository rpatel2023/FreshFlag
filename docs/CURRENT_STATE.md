# FreshFlag — Current Implementation State

> Last updated from project conversation: 2026-09-02
> Purpose: Tell a coding agent what is true *now*, not what the original design spec planned.

## Product identity

The project is **FreshFlag**, an iPhone food-expiry tracker built with Flutter and Firebase. The current private-distribution path is **SideStore**, using zero-fee unsigned IPA builds that are signed by each user's own Apple Account. The core loop remains:

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

- A second household user has installed/joined successfully.
- Shared household inventory synchronization works across the tested two-iPhone flows.
- The current SideStore build is installed and has been in normal household use.
- Core add/edit/consume/restore, reminders, roles, favourites, Activity, barcode lookup/cache, custom categories, and Discord integration have been physically validated.

### Reminders

- Reminder behavior has been manually tested.
- SideStore builds support on-device local expiry reminders from synced household inventory.
- Discord expiry reminders and granular activity notifications are available per user.
- Native FCM/APNs delivery remains available for standard/paid-distribution builds but is intentionally unavailable to the free SideStore build.

### Household roles and member management

- Owner, Admin, Member, and Guest roles are implemented and enforced in backend/Firestore authorization.
- Guest is genuinely read-only for household inventory/reminder-rule data.
- Owner/Admin household authorization does not grant Firebase Authentication password-administration rights.

## Password recovery

PR #20 (`df32acbfe4e699a27845dff25b40587dc697ffa9`) is merged to `main`.

Current behavior:

- **Forgot password?** uses Firebase Authentication reset email.
- Signed-in users can use **Settings → Change password** with current-password reauthentication.
- A local-only Firebase Admin SDK operator tool exists for emergency recovery.
- Household Owner/Admin roles cannot change another user's authentication password.

See `docs/PASSWORD_RECOVERY.md`.

## SideStore distribution

The permanent SideStore source path is established.

Current published release:

```text
Fresh Flag 0.1.0 (5)
```

Permanent source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

The permanent source was added on-device and an existing IPA/iLoader install was migrated into SideStore management without uninstalling. A source-based update from build 5 to a higher build still needs validation.

## Web Push companion — in development

Branch `feature/web-push-companion` adds a deliberately thin Home Screen web app for server-originated expiry reminders without requiring the paid Apple Developer Program.

Architecture boundary:

- existing Firestore/reminder rules stay authoritative;
- a separate scheduled backend worker evaluates the same household reminder rules and sends standards-based Web Push;
- the PWA only signs in, registers/unregisters a browser PushSubscription, sends a test notification, and displays incoming reminder notifications;
- the PWA does **not** duplicate inventory, household, barcode, activity, reminder-rule, expiry, or item-lifecycle logic;
- Web Push uses its own deterministic delivery ID so a successful Web Push does not suppress Discord/FCM/local channels;
- deleting the PWA leaves the native Flutter app functional.

The branch currently includes:

- `functions/src/web_push.ts` authenticated subscription management + Web Push delivery;
- scheduled `processWebPushExpiryReminders` worker;
- stale-endpoint cleanup on 404/410;
- isolated Web Push unit tests;
- static notification-only PWA under `web-push/`;
- Firebase Hosting configuration;
- CI syntax/manifest validation;
- `docs/WEB_PUSH_COMPANION.md` deployment and maintenance instructions.

This work is **not production-deployed yet**. It still needs PR/CI completion, VAPID secret creation, Functions/Hosting deployment, and physical iPhone Home Screen/Web Push validation.

## Current priority

The user explicitly prioritized finishing the notification-only Web Push companion. Finish that work through a PR unless a genuine user decision is required. After merge/deployment, validate on a physical iPhone:

1. Safari → Add to Home Screen;
2. sign in with an existing Fresh Flag account;
3. enable notifications;
4. send a test notification;
5. confirm a real scheduled expiry reminder arrives when the native app does not need to be open.

After that, return to the still-pending SideStore source-update validation from build 5 to a higher build.

## Evidence hierarchy

When documentation disagrees, use this order:

1. explicit newer runtime/deployment confirmation from the user;
2. current repository behavior + tests + Firestore rules;
3. this `CURRENT_STATE.md` file;
4. `DECISIONS.md`;
5. original `PROJECT_CONTEXT_ORIGINAL.md` phase plan.
