# Smart Wallet Native — Phase 3 Report

Built 2026-11-04. **Not pushed to GitHub** (parent verifies and pushes).

Phase 3 makes Planned Payments, Split Bills, Debts & Credits and
Templates live, replaces the Phase 2 read-only split view with full
split editing, and adds local reminder notifications with the app's
first three permissions. A minimal Settings screen carries the
reminders section. Only Import/Export remains a placeholder (Phase 4).

## Deliverables

| APK | Package | Size | SHA-256 |
|---|---|---|---|
| `~/workspace/smart-wallet-native/SmartWallet-Native-v0.3.apk` | `com.smartwallet.smart_wallet` | 82,569 bytes | `4f8e132d7741172b268ea91fb4e7874c659d15ee3d410e3aec8941bff162ff48` |
| `~/workspace/smart-wallet-native-preview/SmartWallet-Preview.apk` | `com.smartwallet.preview` | 82,569 bytes | `aacfd05ac3714cb64f8c92c8fb194b9c6e0fac54ce2a100c5341b904a097d331` |

- Badging (both): versionCode **5**; real versionName **2.0.0-preview3**,
  preview versionName **2.0.0-preview3s**, label "Smart Wallet Preview".
- Signature verified with apksigner for both; signer SHA-1
  `29a0f8b118869f726da64b714cd415a3b9f2bbb8` — the same project debug
  keystore as Phases 1–2, so **the preview installs over the Phase 2
  preview** on the phone (same package `com.smartwallet.preview`,
  versionCode 5 > 4). The real-package APK still cannot install over
  the Flutter app (different signature) — that is the final
  switch-over build, as before.
- Permissions (aapt dump permissions, both APKs) — **exactly these
  three, all new in Phase 3**:
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.SCHEDULE_EXACT_ALARM`
  - `android.permission.RECEIVE_BOOT_COMPLETED`

## Tests

`./build-apk.sh test`: **203 checks, 0 failures** in the main project
(84 from Phases 1–2 + 119 new), and the same 203 pass in the preview
copy. New coverage:

- Planned advance: daily/weekly/monthly/yearly; Jan 31 → Feb 29 (leap
  2028) and → Feb 28 (2026); the Flutter drift Feb 28 → Mar 28; year
  rollover; Feb 29 yearly → Feb 28 clamp; occurrence counting and
  completion; until-date completion (due exactly on untilDate is NOT
  complete; advancing past it is); non-recurring completes on pay.
- Mark-paid: created transaction fields (expense, account, category,
  note "Planned Payment: {name}", today's date), balance effect,
  lastPaidDate, schedule advance; split planned payment → members
  copied with fresh ids, all unpaid, amounts preserved.
- Skip: advances/completes on the same state machine, creates no
  transaction, moves no money, leaves lastPaidDate untouched.
- Debts: full lent and borrowed lifecycles with affectsAccount —
  create (linked tx type/note/category rules), settle (mirror tx,
  category re-validated against settlement type), reopen (settlement
  removed, balances reversed), delete while active and while closed;
  affectsAccount=false never moves money; seed-style record with no
  transactionId deletes by reversing its direct balance effect;
  updateDebt rebuild (amount change, affects toggled off); active
  totals per direction.
- Splits: member mark-paid credits the chosen account (not a
  transaction), unmark debits the recorded account back, double-mark
  rejected; seed-data case — unmarking the 'Me' member (paid, no
  paidAccountId) moves nothing; deleting a split transaction reverses
  the expense AND a live recovery; sum validation (empty list, blank
  name, zero share, off-by-more-than-0.01 rejected; within 0.01
  accepted); equalSplit exactness (2400/3 = 800×3; 100/3 =
  33.33/33.33/33.34, summing to exactly 100).
- Templates: draftFromTemplate field mapping incl. transfer
  toAccountId and today's date.
- Reminders: plannedReminderTime (due − daysBefore at 09:00);
  nextDailyReminder (later today vs tomorrow roll-over).

## Flutter semantics — as read from the original sources

Read from `Sree-Ram-MS/Smart-Wallet` (branch `main`) before building:
`lib/services/notification_service.dart`,
`lib/widgets/add_transaction_sheet.dart`,
`lib/screens/splits/split_bills_screen.dart`,
`lib/screens/planned_payments/planned_payments_screen.dart`,
`lib/screens/debts/debts_screen.dart`, `lib/providers/providers.dart`,
`lib/services/hive_service.dart`.

- **Split member paid** (`hive_service.dart`): NOT a transaction. The
  member is flagged paid with a paidDate and a paidAccountId, and the
  member's share is credited directly to that account's balance.
  Unmarking debits it back. Whole-transaction apply/reverse also
  includes these recoveries for paid members that have a
  paidAccountId. Native mirrors all of it in `WalletLogic`
  (`markSplitMemberPaid` / `unmarkSplitMemberPaid` + recovery terms
  inside transaction apply/reverse). Split Bills totals in Flutter:
  Outflow / Recovered / Pending — recovered excludes your own share —
  mirrored.
- **Planned mark-paid** (`providers.dart`): stamps lastPaidDate=now and
  creates an **expense** transaction dated now with note
  `"Planned Payment: {name}"`; split members are copied with new ids
  and reset to unpaid. Recurring payments advance nextDueDate by the
  period with month-end clamping computed from the current due date
  (so Jan 31 → Feb 28 → Mar 28 — the drift is Flutter's own
  behaviour, preserved); completion when occurrences exceed the total
  or the advanced date passes untilDate; non-recurring completes
  immediately. Native mirrors this exactly (`markPlannedPaid`,
  `advancePlanned`, `advanceDueDate`).
- **Debts** (`hive_service.dart`): create with affectsAccount writes a
  linked transaction — lent → expense `"Lent to {person} ({notes})"`,
  borrowed → income `"Borrowed from {person}…"` (notes suffix only
  when notes are non-blank), dated at startDate; the category lands on
  the transaction only if its type matches, the record keeps it
  regardless. Settle writes the mirror transaction (`"Debt recovered
  from…"` / `"Debt repaid to…"`, dated now, category re-validated
  against the settlement type) and closes the record. Reopen deletes
  the settlement transaction (with a legacy fallback match). Delete
  removes linked + settlement transactions; a record with NO linked
  transaction (like the shipped seed debts) instead reverses a direct
  balance effect, only while active. Native mirrors all of it.
- **Notifications** (`notification_service.dart`): channel
  `smart_wallet_channel_v3` "Smart Wallet Reminders"; daily reminder
  id 100 at the profile's hour:minute, title "Update Your Daily
  Transactions 📝"; planned reminders ids 200–500 at (due date −
  daysBefore) **09:00**, future only, title "Upcoming Payment Due:
  {name} ⏰", body "Your payment of {amount} is due today|tomorrow|in
  N days ({date})." Native uses the same ids, channel, times and
  wording.
- **Planned editor** (Flutter sheet): non-recurring forces
  period=null/endType "never"; split members are saved **unpaid**
  always; blank member names become "Friend". Mirrored (native's
  editor rejects blank names via the shared split validation instead,
  which is stricter — see deviations).
- **Templates** (Flutter): list tap = use (opens the add sheet
  prefilled, date = today); long-press = edit. Mirrored (tap or the
  Use button prefills TxEditActivity; Edit button edits).

## Decisions & deviations (documented choices)

1. **Split members include an explicit "Me".** Flutter's *editor*
   treats "Me" as implicit (friends only, equal split divides by
   friends+1, and it never validates that shares sum to the total),
   but the shipped seed data has an explicit paid 'Me' member, and
   the phase brief requires sum validation. Native therefore keeps
   members explicit (a new split starts with Me + Friend 1), equal
   split = total ÷ member count with the last member taking the
   paisa remainder, and save validates: ≥1 member, non-blank names,
   shares > 0, |sum − total| ≤ ₹0.01. Coherent with the seed data
   and keeps balances exact.
2. **Unmark split member** debits only a recorded paidAccountId.
   Flutter falls back to debiting the transaction's account when
   paidAccountId is null — but such a member never credited anything,
   so that fallback would *invent* a loss. Native no-ops the money
   side in that case (flag still clears). Balances stay consistent.
3. **Skip occurrence added.** Flutter has no skip; added per the
   brief on the same advance state machine (no transaction, no
   lastPaidDate change).
4. **Debt edit rebuilds.** Flutter updates the linked transaction in
   place. Native `updateDebt` strips the old effects (linked tx /
   direct effect / settlement tx), swaps the record, and recreates
   the linked transaction (+ settlement if the record is closed,
   keeping the original settlement date). Net balances are identical
   for every field combination; JVM-tested.
5. **Planned reminders:** native cancels the whole 200–499 id window
   before rescheduling (Flutter doesn't when reminders are enabled,
   so edited/deleted payments can leave ghost alarms there); daily
   reminder is one-shot + receiver re-sync instead of Flutter's
   repeating matchDateTimeComponents alarm; the daily "next" rule is
   *not after now → tomorrow* (Flutter: strictly before → tomorrow),
   which differs only in the exact-minute edge and never schedules
   into the past. Notification sound is the system default; Flutter
   bundles a custom `wallet_tone` sound (a sound asset is not worth
   an external file in the no-libraries build).
6. **Split mark-paid dialog** keeps Flutter's account selector but
   uses today's date (Flutter also has a date picker). The paidDate
   is stored either way.
7. **Templates support to-account for transfers** (brief
   requirement). Flutter's template editor never sets the model's
   toAccountId field; native's does, so transfer templates are
   one-tap usable. Harmless superset.
8. **Debts & Credits are one screen** with Lent/Borrowed tabs
   (brief); Flutter ships two screens (Debts, Credits) over the same
   records. The Debt editor's category picker offers only the
   direction-matching type (+ none) instead of all categories —
   equivalent, since a mismatched category never reaches the linked
   transaction in Flutter either.
9. **Settings is reminders-only** (+ profile display), per the brief;
   the full Flutter Settings screen (profile editing, sign-in, drive
   backup, biometric, data management) lands with Phases 4–5.

## What Ram should test on the phone (preview APK)

Install `SmartWallet-Preview.apk` over the Phase 2 preview (same
signature, data preserved). Then:

1. **Notification permission:** first launch should show the Android
   13+ "Allow Smart Wallet Preview to send notifications?" prompt —
   allow it. (If denied, reminders silently won't post; re-allow in
   Settings → Apps → Smart Wallet Preview → Notifications.)
2. **Exact alarms:** Settings (in-app) shows a warning card if exact
   timing isn't granted. For exact reminder times, grant
   **"Alarms & reminders"**: Android Settings → Apps → Special app
   access → Alarms & reminders → Smart Wallet Preview → Allow.
   Without it, reminders still arrive, possibly a few minutes late
   (inexact fallback) — they must never crash the app.
3. **Daily reminder:** in-app Settings → Reminders: set the daily
   time ~2 minutes ahead, wait, and check the "Update Your Daily
   Transactions 📝" notification appears and opens the app.
4. **Planned reminder:** set "Remind me before" to 0 days, add a
   planned payment due today (due after 9 AM won't fire today — the
   rule is due-date 9:00 AM, so use a payment due tomorrow with
   days-before = 1 and check it fires at 9:00, or just confirm no
   crash and that toggling/editing planned payments keeps working).
5. **Planned Payments:** the seed data shows Netflix (₹649) and
   Airtel Fiber (₹999), both due Sep 2026 → highlighted **Overdue**.
   Mark Netflix paid → an expense "Planned Payment: Netflix" appears
   in Transactions, the HDFC Salary balance drops by ₹649, and the
   due date advances one month. Skip Airtel → due date advances, no
   transaction. Add a monthly payment with Occurrences = 2 and mark
   paid twice → it completes. Add a one-time payment → Mark Paid
   completes it immediately.
6. **Split Bills:** the seed Dinner Split (₹2,400) shows Rahul as
   paid-in-seed-data (with no recovery account — display only) and
   Karthik pending. Tap **Collect** on Karthik, pick an account →
   that account's balance rises by ₹800; **Undo** → it drops back.
   Totals (Outflow/Recovered/Pending) update.
7. **Split editing:** edit the Dinner Split (or + in Split Bills):
   change a share so the total doesn't match → Save is refused with
   the shortfall message; tap Split Equally → shares balance; save →
   balances stay consistent. Try switching it to income — the split
   section disappears and the split is dropped on save.
8. **Debts & Credits:** seed shows Alex ₹5,000 (Lent) and Uncle David
   ₹10,000 (Borrowed). Settle Alex → income "Debt recovered from
   Alex" appears and the balance rises ₹5,000; Reopen → it's
   reversed. Add a lent record with "Affects account balance" OFF →
   no transaction is created; add one ON → the "Lent to …" expense
   appears immediately. Note the seed debts have no linked
   transactions (they predate linking), so deleting one reverses its
   original balance effect instead — expected.
9. **Templates:** Templates shows Morning Coffee and Metro Card
   Recharge. Tap **Use** on Morning Coffee → the transaction form
   opens filled in (₹40, Cash); save → expense recorded. Add a
   transfer template with a to-account and use it.
10. **Reboot persistence (optional):** reboot the phone, wait a
    minute, and confirm the daily reminder still fires at its time
    (BootReceiver reschedules everything).

Data note: everything above works on the seeded starter data in the
preview build; no backup import yet (Phase 4), so balances start from
the seed (net ₹1,75,850) as in Phases 1–2.
