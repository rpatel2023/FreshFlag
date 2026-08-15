# Fresh Flag Changelog

This file is the current project handoff and progress log. The detailed historical log remains permanently available in Git history; the pre-handoff version is the `CHANGELOG.md` blob present at merge commit `705d498977fef87c2e38d7fe8a6085ba1edce5f3`.

## Current state — 2026-08-15

Fresh Flag is in physical two-iPhone acceptance testing using the SideStore/private-distribution path. Production Firebase Auth, Firestore, scheduled reminder Functions, and per-user Discord delivery are already deployed from the earlier production checkpoint. Source changes after that checkpoint still require a production Firebase redeploy and/or a new SideStore IPA before they can be physically validated.

### Physical validation already passed

- SideStore iOS build #4 launches successfully on a physical iPhone.
- Firebase email/password sign-in works after the Firebase Auth Pigeon alignment fix.
- Camera barcode scanning works on-device.
- Open Food Facts recognized barcode `061120102241` as Pizza Mozzarella and carried it into Add Item.
- Add Item persisted category, quantity, optional storage location, date-only expiry, and barcode to production Firestore.
- Inventory survived a full app process restart and reloaded with the expected persisted fields.
- Marking an inventory item consumed successfully wrote to Firestore and immediately exposed the existing Restore action on the detail screen.
- The installed build then made the consumed item unreachable after backing out because the dashboard hid consumed items. PR #15 fixed this source-side by adding explicit Active / Consumed views and separate counts.
- PR #15 merged to `main` as `55672e641a1365a4e4604c11b66512b5da053107`. The currently installed physical build predates this fix.
- The Reminders screen correctly surfaced a due Heinz Baked Beans item while excluding a later-expiring item.
- The owner's personal Discord integration connected successfully and its manual test action delivered a message.
- A real scheduled expiry reminder for Heinz Baked Beans was delivered by the production backend to Discord, validating the SideStore reminder path without APNs/FCM.
- That real reminder exposed wording `expires in 1 days`; the backend and client template renderers now normalize this to `1 day` in PR #16.
- Household invite creation passed on the owner account.
- A second iPhone using a separate Fresh Flag/Firebase account accepted the invite and joined the same household.
- The second iPhone sees the same shared household inventory, validating initial two-account household loading in production.
- **Cross-device realtime create passed:** the second iPhone added a manual item and it appeared automatically on the first iPhone's already-open Inventory screen with no refresh, navigation, or app restart.
- **Cross-device realtime consume/restore passed:** consuming the shared test item on the second iPhone removed it automatically from the first iPhone's active inventory, and restoring it on the second iPhone made it reappear automatically on the first iPhone without refresh/navigation.
- **Second-user personal Discord integration passed:** the second Fresh Flag user configured their own Discord webhook and the manual test message arrived successfully, proving Discord configuration is independent per Firebase user and does not require household-owner permission.
- **Two-recipient scheduled Discord fanout passed:** one real scheduled household reminder was independently delivered to both configured users' Discord destinations, validating production scheduler fanout and per-recipient delivery across the two-user household.

## 2026-08-15 — Household roles and member management — SOURCE VALIDATED / MERGED

Physical testing exposed that the original `owner` / `member` model was too coarse: a spouse could not co-manage reminder rules, while the existing Member role was too powerful to serve as a future read-only guest.

PR #16 replaces that model with:

- **Owner** — full household control; only role allowed to assign Admin. Ownership transfer is not implemented yet, so an Owner cannot leave the household.
- **Admin** — full inventory access; may manage reminder rules and invites; may change Member ↔ Guest and remove Members/Guests; cannot alter Owner/Admin roles or promote another Admin.
- **Member** — may add/edit/consume/delete inventory; may view reminder rules; cannot manage household access or reminder rules.
- **Guest** — read-only household/inventory access and read-only reminder rules.

Implemented in PR #16:

- Added `Owner / Admin / Member / Guest` role model and capability helpers.
- Added backend-managed callable Functions to list household members, change roles, remove members, and let non-owners leave a household.
- Added a `Members & access` Settings screen with role display and permitted management actions.
- Member listing exposes safe display names only; household members are not given each other's email addresses.
- Membership role changes are observed live so a promoted/demoted user's running app can update without a restart.
- Owners and Admins can create/revoke household invites and create/edit/delete/toggle household reminder rules.
- Guest inventory writes are blocked in both the Flutter UI and Firestore security rules.
- Direct client edits/deletes of membership documents are denied; role changes/removals go through the validated backend operations so `memberUids` and membership documents cannot drift apart.
- Admins cannot alter the Owner or another Admin; only the Owner can assign Admin.
- Admin/Member/Guest accounts can leave the household; Owner leave is blocked until ownership transfer exists.
- Fixed the observed `1 days` reminder grammar in both backend delivery rendering and client rendering.
- Added Flutter tests for role capabilities and reminder grammar.
- Added backend tests for role transitions/removal/leave policy.
- Expanded Firestore Emulator tests to prove Admin invite/reminder permissions, Guest read-only inventory, and denial of direct membership-role mutation.

Validation on final PR #16 head `085dc03bd62fbec2a76ff098b8f206f4ac83d0c5`:

- Backend CI run `31895438318`: **success** — Functions build/tests and Firestore Emulator authorization tests passed.
- Flutter CI run `31895438384`: **success** — dependency resolution, lockfile reproducibility, Flutter tests, analyzer, and Linux release build passed.
- PR #16 merged to `main` as `705d498977fef87c2e38d7fe8a6085ba1edce5f3`.
- No macOS SideStore IPA build was triggered for PR #16.

## 2026-08-15 — Fresh Flag branding/text normalization — SOURCE VALIDATED / MERGED

Physical testing also exposed inconsistent presentation of the product name as `FreshFlag` and mixed action capitalization.

PR #17 establishes the presentation convention:

- **User-facing product name:** `Fresh Flag`.
- iOS and Android display labels use `Fresh Flag`.
- Login, account creation, household setup, Settings/About, camera permission, Discord settings, Discord sender name, and Discord test-message branding use `Fresh Flag`.
- Ordinary action labels use sentence case, including `Sign in`, `Create account`, `Create invite code`, `Join household`, and `Create household`.
- Client and backend display-name constants prevent future drift.
- `docs/branding.md` records the convention.
- Regression tests lock the platform display labels and Discord sender name.

Technical identifiers intentionally remain unchanged to preserve Firebase, signing, SideStore updates, imports, and CI:

- Dart package `freshflag`;
- Flutter class names such as `FreshFlagApp`;
- bundle/application ID `com.rpatel2023.freshflag`;
- Firebase project ID `freshflag`;
- GitHub repository `FreshFlag`;
- internal build/artifact names such as `FreshFlag.app` and `FreshFlag-unsigned.ipa`.

Validation on PR #17 head `8b123d8ea97f5bd62316e566854a16b4efac4c99`:

- Backend CI run `31896789088`: **success** — Functions build/tests and Firestore Emulator authorization tests passed.
- Flutter CI run `31896789118`: **success** — dependency resolution, lockfile reproducibility, Flutter tests, analyzer, and Linux release build passed.
- PR #17 merged to `main` as `68974ae5f58368bce5941a55aa332b59544c2a44`.
- No macOS SideStore IPA build was triggered for PR #17.

## Production/runtime work still pending

The source merges do **not** by themselves update the two installed iPhones or the production Firebase backend.

All high-value acceptance tests available on the currently installed build are now complete. The next gate is production deployment of current-main Firestore rules and Cloud Functions, followed by one batched SideStore IPA containing PR #15, PR #16, and PR #17.

The current installed build therefore still has the old owner/member UI, pre-PR15 consumed-item navigation, and the old `FreshFlag` display branding.

## Next physical acceptance sequence

1. **Realtime inventory create — PASSED.**
2. **Realtime inventory consume/restore — PASSED.**
3. **Second-user Discord integration — PASSED.**
4. **Two-recipient scheduled Discord fanout — PASSED.**
5. Delete the temporary `Two user reminder test` household rule so it cannot affect future expiry events, if it has not already been deleted.
6. **NEXT:** deploy the updated Firestore rules and Cloud Functions from current `main` to Firebase project `freshflag`.
7. Run the manual **Build SideStore IPA** workflow from current `main` and update both iPhones without deleting the existing app.
8. Confirm the iPhone home-screen/display branding now says **Fresh Flag**.
9. Open **Settings → Members & access** on the Owner phone and promote the spouse from Member to Admin.
10. Confirm the spouse's already-open app changes to Admin without a restart and can manage reminder rules and invites.
11. Temporarily set a test account to Guest and confirm inventory is genuinely read-only, then restore the intended role.
12. Re-test Active / Consumed navigation and Restore using the PR #15 UI.
13. Relaunch both apps and verify auth, household selection, persisted inventory, Discord configuration, and SideStore refresh remain healthy.

Do not expand into unrelated features until this two-device acceptance sequence is stable.
