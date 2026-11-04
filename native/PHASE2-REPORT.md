# Smart Wallet Native — Phase 2 Report

Built 2026-11-04. Phase 2 scope: transactions / accounts / categories
become fully editable, matching the Flutter app's behaviour. Verified in
a fresh foreground call after building (both APKs).

## APKs

### Real package (for the eventual switch-over / release)
- **Path:** `~/workspace/smart-wallet-native/SmartWallet-Native-v0.2.apk`
  (sandbox: [SmartWallet-Native-v0.2.apk](sandbox://workspace/smart-wallet-native/SmartWallet-Native-v0.2.apk))
- **Exact size:** 49,731 bytes
- **SHA-256:** `ab498eeb07c498cd6c6adafeb9f27ef2cad3d0248b58164d5dba444983aa43c3`
- package `com.smartwallet.smart_wallet`, versionCode `4`,
  versionName `2.0.0-preview2`, minSdk 26, targetSdk 34, label "Smart Wallet"

### Side-by-side preview (the one Ram installs)
- **Path:** `~/workspace/smart-wallet-native-preview/SmartWallet-Preview.apk`
  (sandbox: [SmartWallet-Preview.apk](sandbox://workspace/smart-wallet-native-preview/SmartWallet-Preview.apk))
- **Exact size:** 49,731 bytes
- **SHA-256:** `9484be02e83e4b32a221481b5e7218fc2f849803e3788242d9e255e8846e6348`
- package `com.smartwallet.preview`, versionCode `4`,
  versionName `2.0.0-preview2s`, label "Smart Wallet Preview"
- Built exactly like Phase 1's preview: project copied to
  `~/workspace/smart-wallet-native-preview/`, package sed-renamed
  `com.smartwallet.smart_wallet` → `com.smartwallet.preview`, and the
  SAME `build/debug.keystore` copied in before building.
  Signer SHA-1 for BOTH APKs: `29a0f8b118869f726da64b714cd415a3b9f2bbb8`
  — identical to Phase 1, so **the preview installs over Phase 1's
  preview** (and the real build over Phase 1's real build) with data kept.

### Verification (fresh foreground call, after the builds)
- `file`: Android package (APK), with APK Signing Block — both.
- `apksigner verify`: **Verifies**, v2 + v3 true, 1 signer — both.
- `zipalign -c`: OK — both.
- `aapt dump badging`: as above — both.
- **Permissions: none** — `aapt dump permissions` lists only the package
  line for both APKs. Still no INTERNET, no storage, nothing.
- Contents: classes.dex (75,636 B real / 75,352 B preview),
  AndroidManifest.xml, res/raw/starter_wallet_data.json (7,878 B).

## Tests

`./build-apk.sh test` — **84 checks, 0 failures — ALL TESTS PASSED**,
in BOTH the main project and the preview copy.

- The original 41 Phase 1 checks unchanged (net wallet, monthly sums,
  splits totals, lookups, INR formatting…).
- 43 new Phase 2 checks: apply/reverse for income, expense and transfer
  (both sides); add → balance applied; edit amount nets correctly
  (reverse old + apply new); edit changing type expense→income and
  income→transfer; delete reverses both sides of a transfer and removes
  the row; unknown-id update/delete return false; account delete guards
  (blocked by transaction, by transfer to-side, by planned payment, by
  debt — allowed when unreferenced); category delete guards (blocked by
  use in a transaction, by use in a planned payment, by having
  sub-categories — allowed when unused); history filter + search (by
  note, by category name, by account, type+search combined, newest-first
  order); category picker ordering (parent, then its subs, then next parent).

## What was built

- **`WalletLogic` (extended, still pure Java):** `applyTransaction` /
  `reverseTransaction` (the ONLY place transaction balance effects
  happen), `addTransaction`, `deleteTransaction`, `updateTransaction`
  (= reverse old + apply new), `filterTransactions` (type + text search),
  `accountDeleteBlockReason`, `categoryDeleteBlockReason`,
  `categoriesForPicker` (parents followed by their subs).
- **`Ui.java` (new):** shared theme constants (same Flutter colours),
  page scaffold with back/+ header, dark inputs, spinners, chips, colour
  swatches (Flutter `accountColors` / `chartColors` palettes), buttons.
- **Transactions:** `HistoryActivity` — newest-first list, search box,
  All/Income/Expense/Transfer chips, account names, transfer shown as
  From → To. `TxEditActivity` — type chips, amount, account / to-account
  spinners, category spinner (matching type only, sub-categories
  indented; hidden for transfers), date picker, note, save, and delete
  behind a confirm dialog that says the amount will be reversed.
  Dashboard gets a floating **+** and its recent rows/accounts are
  tappable straight into the editors.
- **Accounts:** `AccountsActivity` (net-wallet header + cards) and
  `AccountEditActivity` (name, balance, currency, emoji presets + free
  text, colour palette, card type — Mastercard/Visa/Rupay/American
  Express/Cash/Bank/UPI/Other plus any existing value, notes,
  count-in-net-wallet switch). Delete confirm, or a "can't delete"
  dialog naming the blocker.
- **Categories:** `CategoriesActivity` (Income group, then Expense,
  subs indented with parent name) and `CategoryEditActivity` (name,
  type chips, emoji, 10-colour palette, optional same-type top-level
  parent). Nav: dashboard bottom nav grew to 10 items — **Accounts**
  and **Config** now open these screens; dashboard "Accounts ›" title
  also opens Manage Accounts.
- **Persistence:** every mutation calls `Store.save()` immediately;
  the dashboard and list screens reload in `onResume`.
- Planned, Split Bills, Debts, Templates, Import/Export and Settings
  remain placeholders, as scoped.

## Split-transaction decision

**Split transactions are read-only in Phase 2.** Opening one in the
editor shows its member-by-member paid/unpaid breakdown and a clear
"can't be edited in Phase 2 — split editing arrives in Phase 3"
message, with no Save button — so an edit can never silently destroy
splits. (Preserving splits while changing the amount would leave the
split shares summing to a different total than the transaction, which
is worse.) Deleting a split transaction is allowed: it is explicit,
the confirm dialog names the split and its member count, and
`WalletLogic.deleteTransaction` reverses the full amount.

## Notes / deviations for Ram

- **Install the preview** (`SmartWallet-Preview.apk`): it installs over
  the Phase 1 preview — same package, same signature, higher
  versionCode — so the data it seeded/carried is kept. The real-package
  v0.2 APK is for later, as before.
- Editing a transaction's date keeps its original time-of-day; new
  transactions use the current time. Dates display as "d MMM yyyy"
  everywhere, same as Phase 1.
- Account balance is edited directly in Manage Accounts (that field IS
  the stored balance, as in Flutter); transaction add/edit/delete move
  it from there. No double counting: Phase 1's stored balances already
  include the starter transactions, and Phase 2 only applies effects
  for changes made from now on.
- The account card-type presets are a sensible list (the Flutter sheet's
  exact list wasn't re-fetched for this phase); any card type already
  in the data is preserved and shown in the picker.
- Dialogs (date picker, confirms) use the stock Android Material look,
  same as Phase 1's theme baseline; visual polish is Phase 6.
- Nothing was pushed to GitHub.
