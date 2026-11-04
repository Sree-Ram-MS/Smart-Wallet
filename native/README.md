# Smart Wallet — Native (Android)

A from-scratch **native Java** rebuild of Ram's Flutter Smart Wallet
(repo `Sree-Ram-MS/Smart-Wallet`, v1.1.0+2, ~30 MB APK), built for one
reason: lightness. Pure Android framework APIs — **no external libraries,
no Gradle** — using the same aapt2 + javac + d8 + apksigner pipeline as
the Her Cycle app.

- Package: `com.smartwallet.smart_wallet` (same as the Flutter app)
- Phase 1 build: **SmartWallet-Native-v0.1.apk — 29,251 bytes** (≈ 0.1% of the Flutter APK)
- minSdk 26 · targetSdk 34 · **zero permissions**

## Phase 1 — what is in it

- **Data layer** (`app/src/main/java/com/smartwallet/smart_wallet/`):
  plain-Java models — `Account`, `Category`, `Transaction` (+`SplitMember`),
  `PlannedPayment`, `DebtCredit`, `Template`, `UserProfile`, held in a
  `WalletDb` container.
- **`WalletLogic`** — all money maths (net wallet, monthly income/expense,
  split paid/unpaid, recent transactions, INR formatting with Indian
  digit grouping). Pure Java, no Android imports, covered by JVM tests.
- **`Store`** — persists the whole DB as one JSON file in internal
  storage (`files/smartwallet_db.json`) using Android's built-in
  `org.json`. On first run it seeds from the bundled starter data
  (`res/raw/starter_wallet_data.json`, the same file shipped in the
  Flutter repo, also kept at `reference/starter_wallet_data.json`).
- **Dashboard** (single `MainActivity`, views built in code):
  dark theme matching the Flutter app exactly — bg `#0D0E1A`, card
  `#1E2138`, cardAlt `#252840`, primary `#6C63FF`, accent `#00D9A3`,
  income `#00C896`, expense `#FF5C7A`, text `#E8EAFF`, secondary `#8890B8`.
  Shows net wallet total (count-up animation), income/expense cards,
  account cards (emoji, name, balance, account colour) and the recent
  transactions list (category emoji, signed colour-coded amounts), with
  staggered fade/translate entrance animations. Because the seeded demo
  data is from September 2026, the income/expense cards show the current
  month when it has activity and otherwise fall back to — and label —
  the month of the most recent transaction.
- **Bottom nav** with all sections (Dashboard, Transactions, Planned,
  Split Bills, Debts, Templates, Import/Export, Settings); the others
  show a "Coming in a later phase" placeholder for now.

## Data-format compatibility

The on-disk format **is** the Flutter backup format, unchanged:

```json
{ "format": "smartwallet_backup", "version": 1, "createdAt": "<iso>",
  "data": { "user": {…}, "accounts": […], "categories": […],
            "transactions": […], "plannedPayments": […],
            "debtCredits": […], "templates": […],
            "analyticsCardOrder": […] } }
```

Field names, ISO-8601 date strings and ARGB `colorValue` all match the
Flutter app, so a `.smartwallet` file exported from the Flutter app can
be imported by this app in Phase 4 with no conversion — and vice versa.

## Build

```bash
./build-apk.sh        # -> SmartWallet-Native-v0.1.apk (debug-signed)
./build-apk.sh test   # JVM tests for WalletLogic (41 checks)
```

Toolchain: JDK 17 and Android SDK platform 34 + build-tools 34.0.0.
The script defaults to the copies at `~/workspace/period-tracker/tools/`
and honours `JAVA_HOME` / `ANDROID_SDK_ROOT` overrides. Signing uses a
project-local debug keystore at `build/debug.keystore` (generated on
first build, then **kept** between builds so later phases install over
earlier ones).

> **Install note:** the native APK has the same package name as the
> Flutter app but a *different* signature, so Android will not install
> it over the Flutter app. Export a `.smartwallet` backup from the
> Flutter app first (its data is deleted on uninstall), then uninstall
> the Flutter app, then install this one. Phase 1 only displays the
> seeded starter data — backup import arrives in Phase 4.

## Roadmap

- **Phase 1 (done):** foundation — models, store, WalletLogic + tests, dashboard.
- **Phase 2:** transactions CRUD; accounts & categories management.
- **Phase 3:** planned payments + notifications; debts, split bills, templates.
- **Phase 4:** backup import/export incl. password-encrypted `.smartwallet` files; CSV import/export.
- **Phase 5:** Google Sign-In + Drive AppData backup; biometric lock; home-screen Quick Add widget.
- **Phase 6:** polish, charts, extra features.
