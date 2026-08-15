# FreshFlag SideStore distribution runbook

FreshFlag's primary private iPhone distribution path is SideStore with a free Apple Account. TestFlight remains an optional paid path; it is not required for the two-user household deployment.

## SideStore distribution contract

- Ubuntu remains the normal source/development machine.
- GitHub Actions provides a manually triggered macOS build for an **unsigned** FreshFlag IPA.
- SideStore signs that IPA on each iPhone with the Apple Account used for sideloading.
- The workflow compiles with `FRESHFLAG_SIDESTORE=true`.
- Native APNs/FCM is deliberately disabled in this build. FCM token generation, registration, notification-tap plumbing, and the push Settings toggle must not be required for startup, login, household loading, or inventory use.
- Each user's personal Discord webhook is the supported expiry-reminder delivery channel for the zero-fee build.
- The SideStore IPA intentionally contains one app and no app extensions or Apple signing capabilities. The workflow fails closed if entitlements/capabilities/extensions are introduced without an explicit distribution review.
- `FirebaseMessagingAutoInitEnabled` is `false` in the iOS app so the Firebase Messaging SDK does not automatically generate a token at launch.

The iOS workflow is intentionally `workflow_dispatch` only so a macOS runner is used only when a new physical-device artifact is actually needed.

## 1. Build the unsigned FreshFlag IPA

In GitHub:

1. Open the FreshFlag repository.
2. Open **Actions**.
3. Select **Build SideStore IPA**.
4. Choose **Run workflow** and run it from the intended branch/commit.
5. Wait for the job to finish successfully.
6. Download the `FreshFlag-SideStore-IPA` workflow artifact.
7. Extract `FreshFlag-unsigned.ipa`.

The workflow runs Flutter tests/analyzer, verifies the SideStore capability budget, builds iOS release with `--no-codesign --dart-define=FRESHFLAG_SIDESTORE=true`, checks the FreshFlag/Firebase bundle IDs, verifies FCM auto-init is disabled, rejects app extensions, injects the production `GoogleService-Info.plist`, assembles the required `Payload/*.app` IPA structure, and retains the artifact for 7 days.

## 2. Install SideStore on an iPhone

Follow SideStore's current official install guide rather than relying on stale screenshots or copied third-party instructions.

Current prerequisites include an iOS/iPadOS 15+ device with a passcode, a computer for the initial bootstrap, an Apple Account, Wi-Fi, and LocalDevVPN. On Windows, SideStore currently documents iTunes plus `iloader` for the initial SideStore installation.

After SideStore is installed, trust the developer app in iOS Settings, enable Developer Mode when required, connect LocalDevVPN, sign into SideStore, and refresh SideStore once before installing other apps.

Official references:

- Prerequisites: https://docs.sidestore.io/docs/installation/prerequisites
- Installation: https://docs.sidestore.io/docs/installation/install
- FAQ/limits: https://docs.sidestore.io/docs/faq

## 3. Install or update FreshFlag

For the long-lived setup, **SideStore should own FreshFlag**, even if the first copy was installed with `iloader`.

1. Make `FreshFlag-unsigned.ipa` accessible in the iPhone Files app or otherwise openable by SideStore.
2. Connect LocalDevVPN.
3. Open/import the IPA with SideStore and install it.
4. If an older FreshFlag build is already installed, do **not** delete it first. SideStore documents that sideloading the same or an updated IPA through SideStore adds it to SideStore while preserving existing app data.
5. Launch FreshFlag and verify it appears in SideStore's **My Apps** list so SideStore can refresh its 7-day signing period.

`iloader` remains useful for the initial SideStore bootstrap and troubleshooting, but routine FreshFlag updates should go through SideStore once the app has been adopted there.

LocalDevVPN is required for SideStore install/update/refresh operations. FreshFlag itself does not require LocalDevVPN merely to use Firebase, scan items, or access inventory.

## 4. FreshFlag account and household setup

1. Create or sign into a FreshFlag Firebase email/password account.
2. Complete the household create/join flow.
3. Configure that user's personal Discord reminder webhook in FreshFlag Settings.
4. Repeat on the second iPhone with a separate FreshFlag account.

FreshFlag authentication and household membership are independent of the Apple Account used to sign the app with SideStore.

## Push behavior in the SideStore build

The SideStore build intentionally treats remote push as unavailable rather than probing APNs at runtime. This prevents Personal-Team signing limitations from blocking app startup or authenticated flows.

- The **Push notifications** switch is disabled and explains that Discord should be used instead.
- No FCM token is requested or written to Firestore.
- No FCM background handler is registered by the Dart app.
- Notification deep-link code remains in the standard build for a future paid/TestFlight path.

A future paid Apple Developer/TestFlight build can omit `FRESHFLAG_SIDESTORE=true`, add the required Push Notifications/background capabilities and APNs credentials, and use the existing FCM path.

## Free Apple Account limits

Apple and SideStore currently document the normal Personal-Team constraints: provisioning expires after 7 days, only 3 apps may be active on a device, and only 10 App IDs may be registered in a 7-day period. SideStore itself counts toward the active-app limit. FreshFlag intentionally has no extensions, keeping its App ID footprint to the main app only.

Because these limits can change, re-check Apple's Personal Team documentation and SideStore's FAQ when troubleshooting signing or refresh behavior.

## Pairing-file recovery

If a SideStore pairing file expires after an iOS update/reset or otherwise becomes invalid, use SideStore's official pairing-file replacement procedure in `iloader`:

https://docs.sidestore.io/docs/advanced/pairing-file

## FreshFlag acceptance test on both phones

Before calling the private release complete, validate the actual two-device workflow:

1. Fresh launch reaches the login/sign-up UI promptly with push unavailable.
2. User A creates/signs into FreshFlag and creates a household.
3. User B signs into a separate FreshFlag account and joins using an invite.
4. Scan a recognized barcode and confirm product prefill.
5. Add an unknown barcode manually.
6. Confirm both devices see the same household inventory.
7. Set an expiry date and household reminder rule.
8. Configure each user's own Discord webhook and use FreshFlag's test action.
9. Confirm a due reminder reaches each configured personal Discord destination.
10. Mark the item consumed on one device and confirm the other device updates.
11. Relaunch both apps and confirm authentication, household selection, and persisted data still work.
12. Confirm FreshFlag refreshes successfully from SideStore before the 7-day signing period expires.
