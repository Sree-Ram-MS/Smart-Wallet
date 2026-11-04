# Smart Wallet Native — Phase 4 Report (Import/Export)

Date: 2026-11-04. Phase 4 makes the **Import/Export** nav item a real
screen: Flutter-compatible backup export/import (plain and
password-encrypted), a restore preview with a safety snapshot and
undo, and CSV export/import in Flutter's exact format. All format
logic is pure Java (`BackupCodec`, `CsvCodec`, `MiniJson` — no
Android imports, JVM-tested); `ImportExportActivity` only does
Storage Access Framework I/O. **No new permissions** — the manifest
still carries exactly POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM and
RECEIVE_BOOT_COMPLETED.

## Builds (re-verified in a fresh foreground pass after building)

| APK | Package | Version | Size | SHA-256 |
|---|---|---|---|---|
| `SmartWallet-Native-v0.4.apk` | `com.smartwallet.smart_wallet` | 2.0.0-preview4 (code 6) | 103,049 bytes | `8f5265c8a0995bb5e250e399fb49c0b3d2b2fcb81b99c303b34fe1f10d6e072d` |
| `SmartWallet-Preview.apk` | `com.smartwallet.preview` ("Smart Wallet Preview") | 2.0.0-preview4s (code 6) | 103,049 bytes | `1d56df2618bd27a066d11e076365a348942912225e75302cc5c1738b4bb05ec0` |

Both pass `apksigner verify`, signer SHA-1
`29a0f8b118869f726da64b714cd415a3b9f2bbb8` — the same project
keystore as Phases 1–3, so the preview installs over the Phase 3
preview.

## Tests — 310 JVM checks, 0 failures

203 pre-existing (Phases 1–3) + **107 new** in `tests/TestPhase4.java`:

- **Plain round-trip (a):** representative DB (splits with paid
  members incl. a null `paidAccountId`, recurring planned payment
  with occurrences, a split planned payment, linked + settled debts,
  a transfer template, sub-category, comma in a note) → export →
  file-shape checks (magic, snapshot also spread at top level,
  checksum = SHA-256 of the snapshot JSON) → preview counts
  (2/3/4/2/2/2) → field-level equality incl. net wallet ₹1,200.50
  and September income/expense totals.
- **Encryption (b):** an **independent reference implementation**
  of the Dart algorithm written inside the test (below). With a
  fixed salt/IV the codec's ciphertext and MAC match the reference
  **byte-for-byte**; the derived keys match; the codec decrypts a
  reference-produced payload; a reference-encrypted full backup
  ("Flutter-produced file") restores through the production parser;
  encrypted file field order/layout asserted
  (`format,version,createdAt,checksum,salt,iv,ciphertext,mac`,
  16-byte salt and IV); wrong password → `WrongPasswordException`
  with Flutter's exact message; missing password → Flutter's exact
  "Password is required…" message; random-salt round-trip.
- **Real fixture (c):** `reference/starter_wallet_data.json` (the
  actual Flutter-format starter backup) imported through the
  production parser: counts 4/10/5/2/2/2 and **net wallet ₹1,75,850**
  — the Phase 1 numbers.
- **CSV (d):** export asserted line-by-line (header, Dart double
  formatting, quoted date and comma-note fields, transfer accounts);
  export→import round-trip (dates survive via the display format —
  see deviations); a hand-written Flutter-style CSV (CRLF, quoted
  fields, ISO + display dates, zero/bad amounts, unknown type, bad
  date) → imported 4 / skipped 2 with reasons, all rows in the
  first account, balances moved exactly; LF-only file with reordered
  mixed-case headers; no-accounts file skips everything cleanly.
- **Malformed files (e):** garbage, empty, `{}`, unknown format,
  missing `data`, wrong-typed section, wrong-typed row, truncated
  JSON, broken base64, tampered ciphertext (MAC failure) — all
  rejected with clean errors, and the live DB is asserted untouched
  afterwards. Parsing always completes **before** any mutation.
  Legacy raw snapshots (no wrapper — Flutter's fallback) still load.

## The Flutter encryption algorithm (as read from backup_service.dart)

The Flutter app has no crypto package beyond hashing (`crypto` in
pubspec); the cipher is hand-rolled in Dart and is replicated
exactly:

- **Snapshot:** the data map (`version, createdAt, appName, user,
  accounts, categories, transactions, plannedPayments, debtCredits,
  templates, analyticsCardOrder`). `checksum` = lowercase hex
  SHA-256 of the snapshot's JSON encoding. (Flutter computes it but
  never verifies it on import; native doesn't either.)
- **Plain file:** `{format:"smartwallet_backup", version:1,
  createdAt, checksum, data:{snapshot}}` with the snapshot *also*
  spread across the top level of the file object.
- **Encrypted file:** `{format:"smartwallet_encrypted", version:1,
  createdAt, checksum, salt, iv, ciphertext, mac}` — no `data` key.
- **Key derivation:** PBKDF2-HMAC-SHA256, 10,000 iterations, 32-byte
  key. The HMAC key is the password's UTF-8 bytes; U₁ =
  HMAC(password, salt ‖ 0x00000001); each further Uᵢ =
  HMAC(password, Uᵢ₋₁), XOR-accumulated.
- **Cipher:** plaintext = **gzip**(UTF-8 snapshot JSON). Keystream
  block *j* (0-based) = HMAC-SHA256(key, iv ‖ BE32(*j*)); ciphertext
  = plaintext XOR keystream. (Dart computes one extra initial block
  HMAC(key, iv ‖ "enc") that is overwritten at byte 0 and never
  used — a quirk with no observable effect; noted for completeness.)
- **Salt / IV:** 16 random bytes each, standard base64 in the file.
- **Integrity / wrong-password detection:** `mac` =
  base64(HMAC-SHA256(key, salt ‖ iv ‖ ciphertext)), compared as a
  base64 *string* before decrypting. Mismatch →
  `FormatException("Incorrect password or corrupted backup file.")`.
  This MAC check is exactly what native relies on — a wrong
  password can never produce a garbage restore.
- Empty/blank password = no encryption (plain file). Flutter's
  suggested file name: `smart_wallet_backup_<epochMillis>.smartwallet`;
  native uses the same.

Field-level mapping notes: Dart writes doubles as e.g. `54200.0`
(minijson writer reproduces Dart's `double.toString()` for the
ranges this app uses) and **omits null fields** in model JSON except
where `toJson` includes them explicitly (mirrored per model).
Restore defaults also mirror Flutter (e.g. a missing `cardType`
restores as `"Mastercard"`, missing `affectsAccount` as `true`).

## CSV format (as read from import_export_screen.dart + utils.dart)

- **Export:** header exactly
  `ID,Type,Amount,Account,To Account,Category,Date,Note`. One row
  per transaction: id, type, amount as a Dart double string,
  account / to-account / category **names** (blank when the id
  doesn't resolve), Date = `d MMM yyyy, h:mm a`
  (e.g. `2 Sep 2026, 2:15 PM`), note. Encoding matches
  `package:csv` defaults: comma delimiter, fields containing
  comma/quote/CR/LF are double-quoted with `"` doubled, CRLF row
  endings. File name `smart_wallet_export_<epochMillis>.csv`.
- **Import (Flutter's behaviour, mirrored):** rows are matched to
  columns **by header name** (case-insensitive) and only **Type,
  Amount, Date, Note** are read — the ID, Account, To Account and
  Category columns are ignored. **Every imported transaction is
  placed in the first account**, with no category and no
  to-account. A type outside `income|expense|transfer`
  (case-sensitive comparison) becomes `expense`. Amounts that don't
  parse become 0 and the row is skipped (amount ≤ 0); per-row
  errors are silently skipped; **no duplicate detection**. Dates
  use Dart `DateTime.tryParse` (ISO 8601 subset) and fall back to
  "now" when unparseable. Fewer than 2 rows →
  "CSV is empty or invalid." Native additionally reports *why*
  rows were skipped (Flutter stays silent) and shows a preview
  count before importing, like Flutter's own confirm dialog.

## Deviations and decisions

1. **Undo snapshot (extra, as specified):** before a restore
   replaces the DB, the current DB is written to a single internal
   file (`smartwallet_safety.json`). **Undo last restore** swaps
   live ↔ snapshot, so undo is itself undoable. If the snapshot
   can't be written, the restore is aborted rather than proceeding
   unprotected. Flutter has no equivalent.
2. **CSV date improvement:** Flutter **cannot re-import its own
   CSV export's dates** — it writes `d MMM yyyy, h:mm a` but only
   parses ISO on import, so every date becomes "now" there. Native
   tries ISO first (with Flutter-compatible leniency), then the
   display format, then "now" — so a Flutter export keeps its real
   dates in native. Files native exports still import into Flutter
   exactly as Flutter's own do.
3. **Template `toAccountId`:** native's snapshot writer includes it
   when set (Flutter's `TemplateModel.toJson` omits the field).
   Flutter ignores unknown keys on restore, so interchange is
   unaffected; native→native restores keep transfer templates'
   to-accounts (consistent with the Phase 3 decision).
4. **Preview source:** counts/user/currency come from parsing the
   file (decrypting first when needed) — the same fields Flutter's
   `BackupPreview` shows (createdAt, isEncrypted, counts, userName,
   currency). Google Drive listing/restore stays Phase 5.
5. Structural strictness: a backup whose sections have the wrong
   JSON *shape* (e.g. `transactions` not a list) is rejected as
   invalid instead of being half-restored; missing/null sections
   restore as empty, as in Flutter.

## Ram's migration steps (Flutter → native)

1. In the **Flutter app**: Import/Export → Export Backup (set a
   password if you want the file encrypted — native reads both) and
   save/share the `.smartwallet` file somewhere reachable (Drive,
   USB, WhatsApp to yourself…).
2. Install/open the **native preview** build (side-by-side, no
   uninstall needed).
3. Bottom nav → **Import/Export** → **Import / Restore Backup** →
   pick the `.smartwallet` file.
4. Enter the password if the file is encrypted; check the preview
   (date, counts, user, currency) and confirm the replace-all
   prompt. Done — dashboard shows your real data, reminders are
   rescheduled. Picked the wrong file? **Undo last restore** on the
   same screen brings the starter data back.

**Reverse check (while Flutter is still installed):** in the native
app, Import/Export → **Export Backup** (try it with a password),
then in the Flutter app import that file — it should restore
identically, including decrypting the password-protected file.
Same check works for CSV both ways via Export/Import Transactions
CSV (dates exported from native will show as "now" inside Flutter
— that's Flutter's own import limitation, item 2 above).

## Still open after Phase 4

- Phase 3's phone checks remain worthwhile (notification
  permission prompt, exact-alarm grant, planned/debt/split flows)
  — and now the full migration rehearsal above on the preview
  build, before the real-package switch-over.
- Phase 5 needs the native keystore SHA-1
  `29a0f8b118869f726da64b714cd415a3b9f2bbb8` added to the Firebase
  project `smart-wallet-by-ram` for Google Sign-In.
