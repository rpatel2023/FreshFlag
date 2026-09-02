# Fresh Flag Web Push Companion

## Purpose

Fresh Flag's Home Screen web app is deliberately **not a second Fresh Flag client**. It exists only to register a browser push subscription and receive expiry reminder notifications on devices where the native SideStore build cannot use APNs/FCM remote push.

The native Flutter application and existing Firebase data model remain authoritative for:

- inventory;
- household membership and roles;
- reminder-rule creation/editing;
- expiry calculation and reminder eligibility;
- item lifecycle;
- activity history;
- all other product behavior.

Deleting the web companion must not break the native application.

## Architecture boundary

```text
Native Fresh Flag app
        |
        | inventory + reminder rules
        v
Existing Firestore / Functions
        |
        | scheduled reminder eligibility
        v
processWebPushExpiryReminders
        |
        | standards-based Web Push + VAPID
        v
Home Screen web companion service worker
        |
        v
iPhone notification
```

The web companion does not read household inventory or reminder rules. It uses Firebase Authentication only to prove which Fresh Flag user owns a push subscription.

## Web companion responsibilities

The static app in `web-push/` may only:

1. sign an existing Fresh Flag user in/out;
2. explain the iOS Add-to-Home-Screen requirement;
3. request browser notification permission;
4. create/remove the current browser's `PushSubscription`;
5. register/remove that subscription through authenticated callable Functions;
6. send a test notification;
7. display incoming push payloads through `sw.js`.

Do not add inventory, household, barcode, reminder-rule, activity, or item-management UI here.

## Backend storage

Subscriptions are backend-managed under:

```text
users/{uid}/webPushSubscriptions/{sha256(endpoint)}
```

The client never receives another user's subscription. Regular Firestore clients do not need access to this collection because registration/removal uses authenticated callable Functions.

Reminder deliveries use their own deterministic `webpush` delivery ID. This intentionally does not share the native FCM or Discord delivery ID, so one successful channel cannot suppress another.

## Functions

`functions/src/web_push.ts` exports:

- `getWebPushPublicKey` — authenticated retrieval of the public VAPID key;
- `setWebPushSubscription` — authenticated registration/update of the current browser endpoint;
- `removeWebPushSubscription` — authenticated removal of the current browser endpoint;
- `testWebPushNotification` — authenticated test delivery;
- `processWebPushExpiryReminders` — scheduled five-minute reminder worker using the existing household reminder rules.

Expired push endpoints returning HTTP 404/410 are removed automatically.

## VAPID setup

Web Push requires one project-level VAPID key pair. The private key must never be committed or exposed to the browser.

From `functions/` after dependencies are installed:

```bash
npx web-push generate-vapid-keys --json
```

Store the resulting values as Firebase Functions secrets:

```bash
firebase functions:secrets:set WEB_PUSH_VAPID_PUBLIC_KEY
firebase functions:secrets:set WEB_PUSH_VAPID_PRIVATE_KEY
```

The browser receives only `WEB_PUSH_VAPID_PUBLIC_KEY` through the authenticated callable Function.

These keys are independent of the Firebase Console FCM Web Push key-pair UI because this companion uses standards-based Web Push directly rather than Firebase Messaging in the browser.

## Deployment

`firebase.json` serves `web-push/` as the Firebase Hosting public directory.

After the secrets are set and the branch is merged:

```bash
firebase deploy --only functions,hosting
```

If Firestore rules are unchanged, they do not need redeployment for this feature.

## iPhone setup

On iOS/iPadOS, the user must:

1. open the hosted companion in Safari;
2. use Share → **Add to Home Screen**;
3. open the installed Fresh Flag icon;
4. sign in with their existing Fresh Flag account;
5. tap **Enable notifications**;
6. allow notifications when iOS asks;
7. optionally use **Send test notification** to verify delivery.

The Home Screen web app does not consume a Personal Team/SideStore app slot.

## Maintenance rule

A normal Fresh Flag feature change should require **zero changes** in `web-push/`.

Only change the companion when one of these changes:

- browser push registration mechanics;
- authentication bootstrapping;
- notification payload display behavior;
- explicit web-companion UX.

Do not mirror native-app business logic into the PWA.
