# Fresh Flag Changelog

This file is the current project handoff and progress log. The detailed historical log remains permanently available in Git history; the pre-handoff version is the `CHANGELOG.md` blob present at merge commit `705d498977fef87c2e38d7fe8a6085ba1edce5f3`.

## Current state — 2026-08-15

Fresh Flag is in physical two-iPhone acceptance testing using the SideStore/private-distribution path. Production Firebase Auth, Firestore, scheduled reminder Functions, and per-user Discord delivery are already deployed from the earlier production checkpoint. Source changes after that checkpoint still require a production Firebase redeploy and/or a new SideStore IPA before they can be physically validated.

### Physical validation already passed on the currently installed build

- SideStore iOS build #4 launches successfully on a physical iPhone.
- Firebase email/password sign-in works after the Firebase Auth Pigeon alignment fix.
- Camera barcode scanning works on-device.
- Open Food Facts recognized barcode `061120102241` as Pizza Mozzarella and carried it into Add Item.
- Add Item persisted category, quantity, optional storage location, date-only expiry, and barcode to production Firestore.
- Inventory survived a full app process restart and reloaded with the expected persisted fields.
- Marking an inventory item consumed successfully wrote to Firestore and immediately exposed the existing Restore action on the detail screen.
- The installed build then made the consumed item unreachable after backing out because the dashboard hid consumed items. PR #15 fixed this source-side by adding explicit Active / Consumed views and separate counts.
- The Reminders screen correctly surfaced a due Heinz Baked Beans item while excluding a later-expiring item.
- The owner's personal Discord integration connected successfully and its manual test action delivered a message.
- A real scheduled expiry reminder for Heinz Baked Beans was delivered by the production backend to Discord, validating the SideStore reminder path without APNs/FCM.
- Household invite creation passed on the owner account.
- A second iPhone using a separate Fresh Flag/Firebase account accepted the invite and joined the same household.
- The second iPhone sees the same shared household inventory.
- **Cross-device realtime create passed:** the second iPhone added a manual item and it appeared automatically on the first iPhone's already-open Inventory screen with no refresh, navigation, or app restart.
- **Cross-device realtime consume/restore passed:** consuming the shared test item on the second iPhone removed it automatically from the first iPhone's active inventory, and restoring it on the second iPhone made it reappear automatically on the first iPhone without refresh/navigation.
- **Second-user personal Discord integration passed:** the second Fresh Flag user configured their own Discord webhook and its manual test message arrived successfully.
- **Two-recipient scheduled Discord fanout passed:** one real scheduled household reminder was independently delivered to both configured users' Discord destinations.

## PR #15 — Consumed inventory recovery — MERGED

PR #15 fixed the physical-test defect where consumed items became unreachable after leaving Item details.

- Adds explicit **Active / Consumed** inventory views.
- Shows separate Active, Expiring, Expired, and Consumed counts.
- Keeps consumed items reopenable so **Restore to inventory** remains reachable.
- Merged to `main` as `55672e641a1365a4e4604c11b66512b5da053107`.
- The currently installed physical build predates this fix.

## PR #16 — Household roles and member management — MERGED

Physical testing exposed that the original `owner` / `member` model was too coarse. PR #16 adds:

- **Owner** — full control; only Owner may assign Admin; ownership transfer is not implemented yet.
- **Admin** — full inventory access; manages reminder rules, invites, Members, and Guests within the intended boundary.
- **Member** — inventory write access; reminder-rule read access; no household access management.
- **Guest** — read-only household/inventory/reminder-rule access.
- **Members & access** screen.
- Backend-managed member listing, role changes, removals, and non-owner leave flow.
- Live membership/role updates on the affected device.
- Firestore enforcement of Guest read-only inventory.
- Owner/Admin reminder-rule and invite management.
- Fix for the observed `1 days` reminder wording in both backend and client rendering.

Validation on final PR #16 head `085dc03bd62fbec2a76ff098b8f206f4ac83d0c5`:

- Backend CI run `31895438318`: **success**.
- Flutter CI run `31895438384`: **success**.
- Merged to `main` as `705d498977fef87c2e38d7fe8a6085ba1edce5f3`.
- No macOS SideStore IPA build was triggered.

## PR #17 — Fresh Flag branding/text normalization — MERGED

PR #17 establishes the product presentation convention:

- **User-facing product name:** `Fresh Flag`.
- iOS and Android display labels use `Fresh Flag`.
- Login, account creation, household setup, Settings/About, camera permission, Discord settings, Discord sender name, and Discord test-message branding use `Fresh Flag`.
- Ordinary actions use sentence case.
- Client/backend display-name constants and `docs/branding.md` prevent future drift.
- Technical identifiers remain unchanged: Dart package `freshflag`, `FreshFlagApp`, bundle ID `com.rpatel2023.freshflag`, Firebase project `freshflag`, GitHub repo `FreshFlag`, and internal IPA/app artifact names.

Validation on PR #17 head `8b123d8ea97f5bd62316e566854a16b4efac4c99`:

- Backend CI run `31896789088`: **success**.
- Flutter CI run `31896789118`: **success**.
- Merged to `main` as `68974ae5f58368bce5941a55aa332b59544c2a44`.
- No macOS SideStore IPA build was triggered.

## PR #18 — Favourites and final pre-IPA inventory polish — MERGED

PR #18 is the final low-risk convenience/polish batch before the next SideStore IPA.

### Personal Favourites

- Adds a **Favourites** bottom-navigation tab using Canadian spelling in the UI.
- A signed-in user can star/unstar an inventory product from Item details.
- Favourites are **personal to the Firebase user**, not household-owned, so each user has their own reusable product list.
- Favourites are stored under `users/{uid}/favorites` and protected by self-only Firestore rules.
- The Firestore Emulator proves another signed-in user cannot read or write someone else's favourites.
- A favourite stores reusable product fields only: name, barcode, category, usual quantity, and usual storage location.
- Purchase-specific expiry and notes are deliberately not copied into the favourite template.
- **Add again** opens the standard Add item form prefilled from the favourite and still requires a fresh expiry date.
- Barcode favourites deduplicate by barcode.
- Manual favourites deduplicate by normalized product name + category rather than inventory record ID, avoiding duplicate templates across purchases.
- Favourite matching also tolerates item edits/source identity so star/unstar remains predictable.
- Consuming or deleting the live inventory record does not delete the personal favourite.
- Guest users may curate personal favourites, but **Add again** is disabled while their current household access is read-only.
- Re-adding a barcode-backed favourite is labelled **Favourite product**, rather than incorrectly looking like a fresh barcode scan.

### Inventory / reminder polish

- Existing inventory items can now be edited from **Item details**.
- The same form is reused for manual add, barcode add, favourite re-add, and edit.
- Edit supports name, quantity, category, expiry, storage location, and notes while preserving the inventory record identity/barcode/audit context.
- Quick expiry shortcuts: **Today, +3 days, +7 days, +14 days, +30 days**, with the regular date picker still available.
- Inventory search by item name.
- Inventory sort options: **Expiry soonest**, **Name A–Z**, **Recently added**.
- Inventory cards now prioritize category, quantity, storage location, and expiry status; raw barcode remains available in Item details instead of cluttering the list.
- One-day status reads **Expires tomorrow**.
- Reminder rows are tappable and open the corresponding Item details screen.
- **Mark consumed** now offers an **Undo** SnackBar action.
- Remaining user-facing copy normalization was completed, including the missed Inventory `Fresh Flag` title and `Scan barcode` sentence case.

PR #18 intentionally adds **no new package dependency and no new Cloud Function**. Its only backend/runtime addition is the personal-Favourites Firestore security rule.

Validation on final PR #18 head `96c3ca8a5f132f0a92ae1951a6eff9c2bba074d2`:

- Backend CI run `31897972971`: **success** — Functions build/tests and Firestore Emulator authorization tests passed.
- Flutter CI run `31897972983`: **success** — dependency resolution, lockfile reproducibility, Flutter tests, analyzer, and Linux release build passed.
- PR #18 merged to `main` as `79a2dc00f793ee448615e3cd2bdc9284491a6c89`.
- No macOS SideStore IPA build was triggered.

## Production/runtime work still pending

The source merges do **not** by themselves update the two installed iPhones or the production Firebase backend.

All worthwhile tests on the currently installed pre-PR15/16/17/18 build are complete. The next gate is now:

1. Deploy **current-main Firestore rules + Cloud Functions** to Firebase project `freshflag`.
   - This deploy activates PR #16 role enforcement/callables.
   - It activates the reminder grammar and Discord display-brand updates.
   - It activates PR #18 personal-Favourites Firestore access.
2. Run one manual **Build SideStore IPA** workflow from current `main`.
3. Update both iPhones without deleting the existing app.

The next IPA must therefore contain **PR #15 + PR #16 + PR #17 + PR #18** in one batched build.

## Next physical acceptance sequence after deployment/build

1. Delete the temporary `Two user reminder test` rule first if it still exists.
2. Confirm the iPhone home-screen/display branding says **Fresh Flag**.
3. Confirm Active / Consumed navigation and Restore work using the PR #15 UI.
4. Open **Settings → Members & access** on the Owner phone and promote the spouse from Member to Admin.
5. Confirm the spouse's already-open app changes to Admin without restart and can manage reminder rules and invites.
6. Validate **Edit item** and confirm the change propagates to the other iPhone in real time.
7. Validate expiry shortcuts, inventory search, each sort option, cleaner card metadata, and tappable reminder → Item details.
8. Mark an item consumed and validate **Undo**.
9. Star an item, open **Favourites**, use **Add again**, confirm product fields are prefilled but expiry is blank/freshly selected, and save it without rescanning.
10. Confirm Favourites are personal: the wife's account does not automatically inherit the owner's favourites; each account can create its own.
11. Temporarily set a test account to Guest and confirm inventory remains genuinely read-only while personal Favourites can still be viewed/managed and **Add again** is disabled.
12. Relaunch both apps and verify auth, household selection, persisted inventory, Favourites, Discord configuration, and SideStore refresh remain healthy.

Do not expand into unrelated features until this acceptance sequence is stable.
