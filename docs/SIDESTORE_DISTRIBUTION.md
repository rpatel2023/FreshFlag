# Fresh Flag SideStore distribution

Fresh Flag uses SideStore as the zero-fee private distribution path for friends and family.

## Publisher workflow

Fresh Flag has two iOS workflows:

- `.github/workflows/ios-sidestore-build.yml` — ad-hoc unsigned IPA build for development/testing. The artifact expires after GitHub's configured retention period.
- `.github/workflows/ios-sidestore-release.yml` — permanent SideStore release publishing. This creates a GitHub Release containing `FreshFlag.ipa` and `source.json`.

The release workflow does not require an Apple Developer Program membership. It builds with `--no-codesign`; SideStore signs the IPA on each user's device with that user's Apple Account.

## Permanent source URL

SideStore source URL:

```text
https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

One-tap SideStore source link:

```text
sidestore://source?url=https://github.com/rpatel2023/FreshFlag/releases/latest/download/source.json
```

The source URL is stable. GitHub's `/releases/latest/` redirect resolves to the newest SideStore release.

## Publishing a release

In GitHub:

1. Open **Actions**.
2. Select **Publish SideStore Release**.
3. Choose **Run workflow** from `main`.
4. Enter:
   - `version`, for example `0.1.0`;
   - `build_number`, which must increase for every release;
   - short user-facing `release_notes`.
5. Run the workflow.

The workflow:

1. resolves dependencies;
2. runs the SideStore Flutter tests;
3. runs the Dart analyzer;
4. verifies that no paid Apple entitlement/capability has been introduced;
5. builds an unsigned release app with the requested version/build number;
6. packages `FreshFlag.ipa`;
7. generates an AltStore/SideStore-compatible `source.json`;
8. creates a permanent GitHub Release;
9. verifies the public source and IPA URLs.

Release tags use:

```text
sidestore-v<version>-b<build_number>
```

Example:

```text
sidestore-v0.1.0-b2
```

## Tester setup

Each tester completes SideStore's normal one-time installation and pairing process on their own iPhone and computer.

After SideStore is installed, give them the one-tap source link above. They add the Fresh Flag source and install Fresh Flag from SideStore.

For later Fresh Flag releases, the same source automatically describes the newest release so SideStore can surface the update.

## Release rules

- Never reuse a build number.
- Keep the bundle identifier `com.rpatel2023.freshflag` unchanged.
- Do not add paid Apple entitlements/capabilities to the SideStore build without an explicit distribution decision.
- Do not enable Firebase Messaging auto-init in the SideStore build; SideStore uses Fresh Flag's local expiry reminder path instead of APNs/FCM.
- Keep `FreshFlag.ipa` and `source.json` as the exact GitHub Release asset names because the stable source URLs depend on them.
- Keep the GitHub repository public while using GitHub Releases as the download host. A private repository would require authentication that ordinary SideStore clients do not have.

## Friend-facing setup summary

```text
Install SideStore once
→ add Fresh Flag source once
→ install Fresh Flag
→ sign into Fresh Flag
→ join household
→ later Fresh Flag releases appear as updates in SideStore
```
