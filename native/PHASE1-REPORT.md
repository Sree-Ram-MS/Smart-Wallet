# Smart Wallet Native — Phase 1 Report

Built 2026-11-04. Foundation + dashboard only, per the Phase 1 scope.

## APK

- **Path:** `~/workspace/smart-wallet-native/SmartWallet-Native-v0.1.apk`
  (sandbox: [SmartWallet-Native-v0.1.apk](sandbox://workspace/smart-wallet-native/SmartWallet-Native-v0.1.apk))
- **Exact size:** 29,251 bytes (Flutter original: 30 MB → ~99.9% smaller)
- **SHA-256:** `e37ead80e864735e1acef1f8f7351b7441eb1b0c90e338bdeeab940a2f94773b`
- Verified in a fresh foreground call after the build (file exists,
  `file` = Android package (APK) with APK Signing Block, sha256 re-computed).

## apksigner verify

```
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Number of signers: 1
Signer #1 certificate DN: CN=Android Debug, O=Android, C=US
Signer #1 certificate SHA-256 digest: 32691528a7ffc95635d9d55816dc584a41ba64385318bec10e405d7959e6318e
Signer #1 certificate SHA-1 digest: 29a0f8b118869f726da64b714cd415a3b9f2bbb8
```

Debug-signed with the project-local keystore `build/debug.keystore`
(generated on first build; the build script preserves it across builds
so later phases install over this one).

## aapt dump badging (summary)

- package: `com.smartwallet.smart_wallet`
- versionCode `3`, versionName `2.0.0-preview1`
- compileSdk 34, minSdk `26`, targetSdk `34`
- application-label: `Smart Wallet`
- launchable-activity: `com.smartwallet.smart_wallet.MainActivity`
- **Permissions: none** — `aapt dump permissions` lists only the package
  line. No INTERNET, no storage, nothing.

APK contents: AndroidManifest.xml, classes.dex (31,072 bytes),
resources.arsc, res/drawable/ic_launcher.xml,
res/raw/starter_wallet_data.json (7,878 bytes, the seed data), META-INF.

## Tests

`./build-apk.sh test` — **41 checks, 0 failures — ALL TESTS PASSED.**

Coverage: net wallet sums only `isEnabledForCalc` accounts (starter-data
total ₹1,75,850, plus disabled-account and empty/null cases); monthly
income/expense/net for Sep/Oct 2026 from the starter transactions;
**transfers excluded** from income, expense and net; recent-transactions
ordering + limit + no caller-list mutation; split paid/unpaid totals;
account/category lookups; ISO date parsing; INR formatting with Indian
grouping (₹4,850 · ₹1,75,850 · ₹1,00,00,000 · paise · negatives) and
signed income/expense/transfer formatting.

## What was built

- Models matching the Flutter backup JSON schema exactly: Account,
  Category, Transaction + SplitMember, PlannedPayment, DebtCredit,
  Template, UserProfile, WalletDb.
- `WalletLogic` — pure Java, no Android imports (runs in the JVM tests).
- `Store` — whole DB as one JSON file in internal storage via built-in
  `org.json`; first run seeds from the bundled starter data and persists it.
- Dashboard: net wallet with count-up animation, income/expense cards
  (current month, falling back to — and labelling — the most recent
  transaction's month, since the seed data is Sep 2026), account cards
  with emoji/colour/balance, recent transactions with category emoji and
  colour-coded signed amounts, staggered entrance animations, and a
  bottom nav whose other 7 sections show a "Coming in a later phase"
  placeholder.
- Colours match the Flutter theme exactly (bg #0D0E1A, card #1E2138,
  cardAlt #252840, primary #6C63FF, accent #00D9A3, income #00C896,
  expense #FF5C7A, text #E8EAFF, secondary #8890B8).
- Manifest declares **no permissions**.

## Source tree

```
SmartWallet-Native-v0.1.apk            (29,251 bytes, + .idsig)
PHASE1-REPORT.md
README.md
build-apk.sh                           (build | test modes, aapt2+javac+d8+apksigner)
reference/starter_wallet_data.json     (fetched from the Flutter repo)
tests/TestWalletLogic.java             (41 checks)
app/src/main/AndroidManifest.xml
app/src/main/java/com/smartwallet/smart_wallet/
    Account.java            Category.java         DebtCredit.java
    MainActivity.java       PlannedPayment.java   SplitMember.java
    Store.java              Template.java         Transaction.java
    UserProfile.java        WalletDb.java         WalletLogic.java
app/src/main/res/drawable/ic_launcher.xml
app/src/main/res/raw/starter_wallet_data.json   (seed data, = reference copy)
build/                                          (intermediates + debug.keystore)
```

## Notes for Ram

- **Uninstall first:** same package as the Flutter app, different
  signature → Android refuses install-over. Export a `.smartwallet`
  backup from the Flutter app **before** uninstalling it (uninstall
  deletes its data), then install the native APK. Phase 1 shows only
  the seeded starter data; importing that backup lands in Phase 4.
- The new debug key's SHA-1 is `29a0f8b118869f726da64b714cd415a3b9f2bbb8`
  — it differs from the SHA-1 registered in Firebase for the Flutter
  build, which matters only in Phase 5 (Google Sign-In): that SHA-1
  will need adding to the Firebase project then. Nothing to do now.
- Nothing was pushed to GitHub.
