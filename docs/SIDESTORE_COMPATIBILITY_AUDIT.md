# SideStore / Personal Team compatibility audit

Date: 2026-08-14

This audit reviews FreshFlag specifically for the zero-fee iPhone distribution path: an unsigned GitHub-built IPA re-signed by SideStore with an Apple Personal Team. The goal is to prevent behavior that is harmless under a paid Apple Developer/TestFlight build from blocking or misleading the SideStore build.

## Release decision

The SideStore build is a distinct compile-time distribution profile:

```text
--dart-define=FRESHFLAG_SIDESTORE=true
```

For this profile, native APNs/FCM remote push is **unsupported by product policy**. Discord is the supported expiry-reminder delivery channel. A future paid/TestFlight build omits the define and may enable the existing FCM path after Apple push capability/APNs configuration is completed.

## Blockers found and remediated

### 1. FCM blocked the first Flutter frame

Previous startup awaited `FCMService.initialize()` before `runApp()`. That initialization could await Apple/FCM token work, leaving a Personal-Team device on the native white launch screen indefinitely.

Remediation:

- render FreshFlag before optional messaging initialization;
- do not register the FCM background handler in SideStore builds;
- do not initialize FCM at all in SideStore builds;
- standard builds initialize FCM only after the first Flutter frame.

### 2. FCM could block household loading after authentication

`AuthWrapper` previously awaited device registration before `HouseholdViewModel.initializeForUser()`. `syncRegistrationForCurrentUser()` can require an FCM token, so a successful login could hang before household state loaded.

Remediation:

- household loading is now completed before optional device registration;
- FCM registration is best-effort/unawaited in standard builds;
- SideStore builds never attempt the registration.

### 3. Firebase Messaging auto-init was enabled implicitly

Firebase Messaging enables token auto-generation by default on Apple platforms. Avoiding explicit `getToken()` calls alone is therefore insufficient.

Remediation:

- `ios/Runner/Info.plist` sets `FirebaseMessagingAutoInitEnabled` to `false`;
- standard builds explicitly re-enable FCM auto-init inside `FCMService.initialize()`;
- SideStore builds leave it disabled.

### 4. Push Settings UI implied a capability the SideStore build does not provide

The prior push toggle was enabled by default and could initiate permission/token work.

Remediation:

- push is now opt-in by default;
- the SideStore build disables the push switch and directs users to Discord reminders;
- the FCM service itself also rejects/ignores SideStore token/permission paths as defense-in-depth.

### 5. Apple token ordering was unsafe even for a paid build

Firebase documents that on Apple platforms the APNs token must be available before FCM token API calls. The previous code called `getToken()` directly.

Remediation:

- Apple token acquisition now checks `getAPNSToken()` first;
- no FCM token request is attempted while the APNs token is absent;
- token requests have a finite timeout;
- startup does not implicitly request notification permission.

## iOS capability / entitlement inventory

Current FreshFlag iOS Runner has:

- no Runner `.entitlements` file;
- no `CODE_SIGN_ENTITLEMENTS` build setting;
- no Xcode `SystemCapabilities` section;
- no app extensions (`.appex`);
- no app groups;
- no iCloud/CloudKit capability;
- no Sign in with Apple;
- no Apple Pay/Wallet;
- no HealthKit;
- no NFC;
- no associated domains/universal-link capability;
- no network extension or Personal VPN capability;
- no background remote-notification mode.

This is the desired SideStore profile. The manual IPA workflow now fails if a Runner entitlement/capability or app extension is introduced, forcing a new compatibility review rather than silently consuming Personal-Team capability/App-ID budget.

## Dependency audit

### Safe for the SideStore profile

- **Firebase Auth (email/password):** network-backed authentication; FreshFlag does not use Sign in with Apple or an OAuth callback scheme.
- **Cloud Firestore:** ordinary TLS network access; no Apple entitlement.
- **Callable Cloud Functions:** ordinary TLS network access; no Apple entitlement.
- **Discord reminders:** sent server-side by deployed Cloud Functions; no iOS capability is required.
- **mobile_scanner:** camera access only. `NSCameraUsageDescription` is present.
- **Open Food Facts:** uses HTTPS with an 8-second timeout and falls back to manual entry.
- **SharedPreferences:** normal app-container preferences; no app group is used.
- **Provider/UI/theme:** no Apple capability dependency.

### Intentionally unavailable in SideStore

- **FCM/APNs remote push and notification deep links from push taps.** The code remains for the future standard/paid distribution profile but is disabled in the SideStore profile.

## Signing / refresh considerations

- FreshFlag contains only the main app, so it should use one FreshFlag App ID rather than consuming additional IDs for extensions.
- SideStore/free Apple Account provisioning expires on the Personal-Team cadence and must be refreshed before expiry.
- Once a FreshFlag build is installed, updated builds should be sideloaded through SideStore without deleting the existing app. SideStore documents that this adopts the app into its list while preserving app data.
- Authentication/session persistence across an actual SideStore refresh/update remains a physical-device acceptance item even though app data is expected to be preserved.

## Network/VPN considerations

LocalDevVPN is required for SideStore install/update/refresh operations, not for FreshFlag's normal Firebase/Open Food Facts use. Other VPN/DNS profiles can interfere with SideStore refresh itself; that is a SideStore operational issue rather than a FreshFlag app dependency.

FreshFlag's own external client traffic uses HTTPS. No App Transport Security exception is required.

## Non-blocking observations

- The Xcode project still declares an iOS deployment target below SideStore's supported iOS baseline. This does not prevent installation on the target modern iPhones and is not a Personal-Team capability issue. It can be normalized separately when the iOS dependency chain is modernized.
- `GoogleService-Info.plist` is not a native Xcode Runner resource in the legacy project; the SideStore workflow intentionally injects it into the generated `.app` and verifies its bundle ID. A future normal Xcode archive should add the plist to Runner resources instead of relying on workflow injection.

## Workflow guards before any next device build

The SideStore workflow must verify all of the following before uploading an IPA:

1. build uses `FRESHFLAG_SIDESTORE=true`;
2. `FirebaseMessagingAutoInitEnabled` is false;
3. Xcode Runner has no entitlement/capability declaration;
4. generated app contains no `.appex` extension;
5. app bundle ID is `com.rpatel2023.freshflag`;
6. Firebase plist bundle ID matches the app bundle ID;
7. Flutter tests and analyzer pass;
8. unsigned iOS release build succeeds.

Only after these checks pass should another physical-device IPA be installed.
