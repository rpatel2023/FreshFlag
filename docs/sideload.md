# FreshFlag SideStore distribution runbook

FreshFlag's primary private iPhone distribution path is SideStore with a free Apple Account. TestFlight remains an optional paid path; it is not required for the two-user household deployment.

## What this path does

- Ubuntu remains the normal source/development machine.
- GitHub Actions provides a manually triggered macOS build for an **unsigned** FreshFlag IPA.
- SideStore signs that IPA on each iPhone with the Apple Account used for sideloading.
- Native APNs/FCM push delivery is not assumed to be available under free sideload signing; FreshFlag's personal Discord reminder integration remains the reliable parallel reminder channel.

The GitHub workflow is intentionally `workflow_dispatch` only so private-repository macOS runner minutes are consumed only when a new iOS artifact is actually needed.

## 1. Build the unsigned FreshFlag IPA

In GitHub:

1. Open the FreshFlag repository.
2. Open **Actions**.
3. Select **Build SideStore IPA**.
4. Choose **Run workflow** and run it from the intended branch/commit.
5. Wait for the job to finish successfully.
6. Download the `FreshFlag-SideStore-IPA` workflow artifact.
7. Extract it and keep `FreshFlag-unsigned.ipa` available on the computer or in Files/iCloud/another location accessible from the iPhone.

The workflow validates tests/analyzer, builds iOS release with `--no-codesign`, verifies the bundle ID `com.rpatel2023.freshflag`, places the production `GoogleService-Info.plist` into the app bundle, assembles the required `Payload/*.app` IPA structure, and retains the artifact for 7 days.

## 2. Install SideStore on an iPhone

Follow SideStore's current official install guide rather than relying on stale screenshots or copied third-party instructions.

Current official prerequisites include:

- iPhone/iPad/iPod touch on iOS/iPadOS 15 or newer with a passcode.
- A computer for the initial SideStore installation. Windows, macOS and supported Linux distributions are documented by SideStore.
- An Apple Account.
- Wi-Fi.
- LocalDevVPN on the iPhone; the VPN must be connected when installing, updating, or refreshing apps through SideStore.

For Windows, SideStore currently documents installing iTunes and `iloader`, connecting/trusting the iPhone, signing into `iloader`, selecting the device, and choosing **Install SideStore (Stable)**.

After SideStore is installed, trust the developer app in iOS Settings, enable Developer Mode when required by the iOS version, connect LocalDevVPN, sign into SideStore, and refresh SideStore once so its signing setup is known-good.

Official references:

- Prerequisites: https://docs.sidestore.io/docs/installation/prerequisites
- Installation: https://docs.sidestore.io/docs/installation/install
- FAQ/limits: https://docs.sidestore.io/docs/faq

## 3. Install FreshFlag

1. Make `FreshFlag-unsigned.ipa` accessible to the iPhone.
2. Connect LocalDevVPN.
3. Open SideStore.
4. Import/open the FreshFlag IPA in SideStore and install it.
5. When iOS prompts about the personal developer app, follow the same trust/Developer Mode flow used for SideStore.
6. Launch FreshFlag.
7. Create or sign into the FreshFlag Firebase account.
8. Complete the household join/create flow.
9. Configure that user's personal Discord reminder webhook in FreshFlag Settings.

Do the same on the second iPhone. FreshFlag authentication and household membership are independent of the Apple Account used by SideStore.

## Free Apple Account limits

SideStore currently documents that free Apple Accounts have a normal 7-day development signing period, a maximum of 3 simultaneously active apps including SideStore, and 10 App IDs per week. SideStore can refresh apps before expiry; the initial computer is not normally needed for routine refreshes.

Because these limits are Apple-account specific and can change, check SideStore's FAQ when troubleshooting signing/refresh behavior.

## Pairing-file recovery

If a SideStore pairing file expires (for example after an iOS update/reset, or occasionally otherwise), use SideStore's official pairing-file replacement procedure in `iloader`:

https://docs.sidestore.io/docs/advanced/pairing-file

## FreshFlag acceptance test on both phones

Before calling the private release complete, validate the actual two-device workflow:

1. User A creates/signs into FreshFlag and creates a household.
2. User B signs into a separate FreshFlag account and joins using an invite.
3. Scan a recognized barcode and confirm product prefill.
4. Add an unknown barcode manually.
5. Confirm both devices see the same household inventory.
6. Set an expiry date and household reminder rule.
7. Configure each user's own Discord webhook and use FreshFlag's test action.
8. Confirm a due reminder reaches each configured personal Discord destination.
9. Mark the item consumed on one device and confirm the other device updates.
10. Relaunch both apps and confirm authentication, household selection, and persisted data still work.

Native FCM/APNs notification behavior can be tested separately if free signing grants the needed entitlement, but it is not a release blocker for the SideStore-first deployment because Discord is the parallel reminder path.
