# Smart Wallet — Native (Android)

A from-scratch **native Java** rebuild of Ram's Flutter Smart Wallet
(repo `Sree-Ram-MS/Smart-Wallet`, v1.1.0+2, ~30 MB APK), built for one
reason: lightness. Pure Android framework APIs — **no external libraries,
no Gradle** — using the same aapt2 + javac + d8 + apksigner pipeline as
the Her Cycle app.

- Package: `com.smartwallet.smart_wallet` (same as the Flutter app)
- Phase 1 build: SmartWallet-Native-v0.1.apk — 29,251 bytes (≈ 0.1% of the Flutter APK)
- Phase 2 build: **SmartWallet-Native-v0.2.apk — 49,731 bytes**, versionCode 4 / `2.0.0-preview2`
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

## Phase 2 — what is in it

The wallet data is now fully editable, matching the Flutter app's behaviour:

- **Transactions** (`HistoryActivity` + `TxEditActivity`): full history,
  newest first, with text search (note / category / account) and
  All / Income / Expense / Transfer filter chips. Add / edit / delete with
  type, amount, account (plus to-account for transfers), a category picker
  that lists sub-categories under their parents and only offers categories
  of the matching type (transfers have no category), a date picker and a
  note. Dashboard and history both have a **+** to add a transaction.
- **Balance effects live in `WalletLogic` only** (pure Java, JVM-tested):
  income adds, expense subtracts, transfer moves between accounts;
  deleting a transaction reverses it; editing = reverse old + apply new.
  `Account.balance` remains the stored field, exactly as in Flutter.
- **Accounts** (`AccountsActivity` + `AccountEditActivity`): net-wallet
  header, account cards, add/edit with name, balance, currency, emoji
  presets + free text, the Flutter account-colour palette, card type
  (Mastercard / Visa / Rupay / American Express / Cash / Bank / UPI /
  Other), notes and the count-in-net-wallet switch. **Delete is blocked**
  with an explanation while any transaction, planned payment, debt/credit
  or template references the account.
- **Categories** (`CategoriesActivity` + `CategoryEditActivity`, under
  Config in the bottom nav): grouped by Income / Expense with
  sub-categories indented under parents. Add/edit with name, type, emoji,
  the Flutter chart-colour palette and an optional same-type top-level
  parent. **Delete is blocked** while the category is used anywhere or
  has sub-categories; a parent category's type can't be changed.
- **Split transactions are read-only in Phase 2** (decision): opening one
  shows its split breakdown with a clear message and no Save button, so an
  edit can never silently destroy splits. It can still be deleted — an
  explicit, confirmed action that reverses the full amount. Split
  *editing* arrives in Phase 3.
- Every change saves through `Store` immediately, and the dashboard
  reloads in `onResume`, so balances and totals are always current.
- Bottom nav is now 10 entries: Dashboard, Transactions, Accounts and
  Config are live; Planned, Split Bills, Debts, Templates, Import/Export
  and Settings remain placeholders for their phases.

## Phase 3 — what is in it

Planned payments, reminders, debts & credits, split bills and templates
are live, mirroring the Flutter app's behaviour (checked against the
Flutter sources; see `PHASE3-REPORT.md` for the semantics decisions):

- **Planned Payments** (`PlannedActivity` + `PlannedEditActivity`):
  sorted by next due date, overdue highlighted, occurrence progress and
  end conditions (never / until date / N occurrences). Add/edit/delete
  with name, amount, account, expense category, due date, recurring
  period (daily/weekly/monthly/yearly), note, and **split members**
  edited like transaction splits. **Mark Paid** records the real expense
  transaction (note "Planned Payment: {name}", split members copied
  fresh and unpaid), stamps lastPaidDate and advances the schedule —
  month-end clamped (Jan 31 → Feb 28/29) — completing when the end
  condition is met or immediately for one-time payments. **Skip** (a
  small native extra; Flutter has no skip) advances without paying.
  Date/advance math is pure Java in `WalletLogic` and JVM-tested.
- **Notifications** (`NotifService` + receivers): the app's first
  permissions — exactly `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`,
  `RECEIVE_BOOT_COMPLETED`. Channel and wording mirror Flutter's
  NotificationService: a daily reminder (id 100) at the profile's time,
  and one reminder per planned payment (ids 200–499) at 09:00,
  `plannedReminderDaysBefore` days before its due date. Exact alarms
  when the OS allows them, inexact fallback otherwise; rescheduled on
  app start, on any planned-payment change, on settings change, and
  after reboot/app update via `BootReceiver`. Android 13+ asks for the
  notification permission on first launch.
- **Debts & Credits** (`DebtsActivity` + `DebtEditActivity`): one screen
  with Lent / Borrowed tabs (Flutter ships two screens over the same
  data), active totals per direction, Active and Recovered/Repaid
  sections. Add/edit/delete with direction, person, amount, account,
  optional category, start/due dates, notes and the affects-account
  switch. When a record affects an account, create/settle/reopen/delete
  keep a linked transaction in step (lent = expense "Lent to {person}",
  borrowed = income "Borrowed from {person}", settle the mirror image),
  exactly as Flutter's HiveService does; seed-style records without a
  linked transaction reverse their direct balance effect on delete.
- **Split Bills** (`SplitsActivity`): every split transaction with
  Total Outflow / Recovered / Pending totals and per-member rows.
  **Collect** marks a member paid and credits their share into the
  chosen account (default: the expense's account) as a direct balance
  adjustment — Flutter records no transaction for a repayment, and
  neither does native; **Undo** debits it back. "Me" is my own share
  and never collectible.
- **Split editing** (`TxEditActivity` + shared `SplitEditor`): the
  Phase 2 read-only block is gone. Expenses get a split switch and a
  members editor — add/remove people, Split Equally (paid members keep
  their share; the rest is split evenly, last person takes the paisa
  remainder so shares always sum exactly) and save-time validation
  that shares sum to the amount within ₹0.01. Existing members' paid
  state survives edits, so collected money stays consistent.
- **Templates** (`TemplatesActivity` + `TemplateEditActivity`):
  list/add/edit/delete; **Use** (or tapping the card) opens the
  transaction form prefilled via `WalletLogic.draftFromTemplate` and
  saves through the normal path. Transfer templates carry a
  to-account (Flutter's editor never sets one; native supports it).
- **Settings** (`SettingsActivity`): minimal for now — profile display
  plus the **Reminders** section (daily toggle + time picker, planned
  toggle + days-before stepper) writing the `UserProfile` fields the
  scheduler reads, with an in-app note when exact alarms aren't
  granted. Full settings arrive in a later phase.
- Bottom nav: only **Import/Export** remains a placeholder (Phase 4).
- Tests: **203 JVM checks** (84 from Phases 1–2 + 119 new) covering
  planned advance/completion, mark-paid effects, debt lifecycle with
  affectsAccount on and off, split validation/equal-split/paid
  toggling/recovery reversal, template drafts and reminder maths.

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
./build-apk.sh        # -> SmartWallet-Native-v0.3.apk (debug-signed)
./build-apk.sh test   # JVM tests for WalletLogic (203 checks)
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
- **Phase 2 (done):** transactions CRUD; accounts & categories management; split transactions read-only (see above).
- **Phase 3 (done):** planned payments + notifications; debts & credits, split bills + split editing, templates; minimal reminders Settings.
- **Phase 4:** backup import/export incl. password-encrypted `.smartwallet` files; CSV import/export.
- **Phase 5:** Google Sign-In + Drive AppData backup; biometric lock; home-screen Quick Add widget.
- **Phase 6:** polish, charts, extra features.
