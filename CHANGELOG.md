# Fresh Flag Changelog

This file is the current project handoff and progress log. Detailed historical changes remain permanently available in Git history.

## Current state — 2026-09-02

Fresh Flag is in active real-device household use with the current Firebase backend/rules deployed. The permanent SideStore distribution path is established and the first permanent release has been published.

### Web Push companion — feature branch

`feature/web-push-companion` adds a deliberately thin Home Screen web app for server-originated expiry reminders without adding a second Fresh Flag product surface.

- Existing Firestore inventory and household reminder rules remain authoritative.
- The PWA only authenticates an existing user, registers/removes its Web Push subscription, sends a test notification, and displays reminder notifications.
- Standards-based Web Push uses project VAPID keys stored as Firebase Functions secrets.
- A separate scheduled `processWebPushExpiryReminders` worker evaluates the existing reminder rules every five minutes.
- Web Push uses its own deterministic delivery IDs so it does not suppress Discord, native FCM/APNs, or SideStore local-notification channels.
- Expired Web Push endpoints are cleaned up after 404/410 responses.
- Firebase Hosting serves only the small notification companion under `web-push/`.
- Backend CI validates Functions tests/build plus the PWA JavaScript and manifest.
- Add/Edit item expiry shortcuts now also include **+3 months, +6 months, +12 months, +18 months** using calendar-month arithmetic with end-of-month clamping.

This branch is not production-deployed yet. It still needs PR/CI completion, VAPID secret setup, Functions/Hosting deployment, and physical iPhone Home Screen/Web Push validation.

See `docs/WEB_PUSH_COMPANION.md` and D-013 in `docs/DECISIONS.md`.

### Distribution milestones

- Permanent SideStore release **Fresh Flag 0.1.0 (5)** published successfully.
- Release assets include `FreshFlag.ipa` and `source.json`.
- Permanent source URL: `https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json`.
- The permanent source was added successfully on-device.
- An existing FreshFlag install originally installed through the IPA/iLoader path was upgraded in place into SideStore management without uninstalling.
- Fresh Flag now appears under SideStore **My Apps** with a normal 7-day signing window.
- The remaining distribution proof is a source-based update from build 5 to a later build.

### Password recovery hardening — PR #20

PR #20 merged to `main` as `df32acbfe4e699a27845dff25b40587dc697ffa9`.

It adds:

- signed-in **Settings → Change password**;
- Firebase reauthentication with the current password before setting a new password;
- safer Forgot-password confirmation wording that does not claim guaranteed inbox delivery merely because Firebase accepted a reset request;
- a local-only Firebase Admin SDK operator recovery command for emergency account resets;
- documentation separating household authorization from authentication administration.

Production testing confirmed the normal Firebase password-reset email/link flow works. Reset emails were sent from both the app and Firebase Console; they were initially hard to locate, which made delivery appear broken. The normal forgotten-password path therefore remains Firebase reset email/link.

Household Owner/Admin roles do **not** gain the ability to change another user's Firebase Authentication password.

See `docs/PASSWORD_RECOVERY.md` for the exact recovery procedure and security boundary.

## Historical implementation state — 2026-08-20

Fresh Flag had completed two-iPhone SideStore/private-distribution acceptance testing for the core feature set, including:

- Firebase email/password sign-in;
- camera barcode scanning and Open Food Facts lookup;
- shared household inventory and two-iPhone realtime synchronization;
- consume/restore lifecycle and consumed-item recovery navigation;
- reminder rules and Discord reminder delivery;
- household invites and role management (Owner/Admin/Member/Guest);
- Guest read-only enforcement;
- personal Favourites;
- inventory editing/search/sort/expiry shortcuts;
- SideStore-local expiry reminders;
- Activity feed and granular Discord item activity notifications;
- household product cache and custom categories.

The detailed PR #15–#18 validation history and earlier implementation notes remain available in Git history and should not be treated as pending work.
