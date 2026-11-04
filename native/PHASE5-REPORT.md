# Smart Wallet Native — Phase 5 Report (Sign-In, Drive, Biometric, Widget, Login)

**Status: DONE — all five sub-parts built.** Google Sign-In compiled,
dexed and linked against the real vendored SDK (no fallback needed);
it activates on-device once Ram registers the signing SHA-1 in
Firebase (steps below — until then the sign-in button returns error
code 10, which the Login screen explains in plain words).

## Builds (re-verified in a fresh foreground pass after building)

| APK | Package | Version | Size | SHA-256 |
|---|---|---|---|---|
| `SmartWallet-Native-v0.5.apk` | com.smartwallet.smart_wallet | 7 / 2.0.0-preview5 | 2,487,469 bytes | `797884a979d67c4e695f79542229c46061f8f3752b9011146ded814bdba89b37` |
| `SmartWallet-Preview.apk` (in `~/workspace/smart-wallet-native-preview/`) | com.smartwallet.preview | 7 / 2.0.0-preview5s | 2,487,469 bytes | `751161433f199135940e03e65a88327de0c338a247091717fe87177badb8d6fa` |

Both signed with the project debug keystore, signer SHA-1
`29a0f8b118869f726da64b714cd415a3b9f2bbb8` (unchanged since Phase 1).
Verified with apksigner + aapt badging in a separate foreground pass.

**Size honesty:** 103,049 → 2,487,469 bytes. The entire growth is
the Play Services + AndroidX + Kotlin runtime dex (single
classes.dex, 6,331,356 bytes uncompressed). That is the real cost
of Google Sign-In without a native rewrite of the OAuth flow —
still ~8% of the 30 MB Flutter APK.

## Permissions — exactly five

POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED
(Phase 3 trio) + **INTERNET** (Sign-In/Drive) + **USE_BIOMETRIC**
(framework BiometricPrompt). Confirmed from both APKs' badging.

## Tests — 351 JVM checks, 0 failures

203 (WalletLogic) + 107 (Phase 4) + **41 new (TestPhase5)**:
session-gate routes (8), Drive URL construction incl. query
encoding (11), Drive JSON parsing — list/create/error bodies,
size as string and number, pretty size/time (15), widget balance
formatting incl. negatives, rounding, no-grouping Flutter parity (7).
The Google SDK classes themselves can't run on a JVM; they're
covered by compile+dex+link and the phone test below.

## Auth vendoring outcome — the hard part worked

- Flutter's `pubspec.lock`: google_sign_in 6.3.0 →
  google_sign_in_android 6.2.1 → **play-services-auth 21.2.0**.
- `./fetch-libs.sh` downloads the full POM-resolved tree from
  Google Maven (dl.google.com) — reachable from this VM by plain
  curl, HTTP 200 — with Gradle-style newest-version conflict
  resolution (base/basement 18.3.0, tasks 18.1.0). Kotlin/Guava
  artifacts, which Google Maven doesn't host, come from Maven
  Central. 34 artifacts, ~7 MB of downloads:
  play-services-auth 21.2.0, auth-base 18.0.10, auth-api-phone
  18.0.2, base 18.3.0, basement 18.3.0, tasks 18.1.0, fido 20.0.1,
  androidx fragment 1.5.7 / activity 1.5.1 / loader 1.1.0 /
  core 1.8.0 / core-ktx 1.2.0, lifecycle 2.5.1 set, arch.core 2.1.0,
  savedstate 1.2.0, viewpager/customview/tracing/versionedparcelable,
  annotation + collection, Guava listenablefuture 1.0, Kotlin stdlib
  1.6.21 (+jdk7/jdk8), kotlinx-coroutines 1.6.1.
- Deliberately excluded: `androidx.concurrent:concurrent-futures` —
  its only class is a stub ListenableFuture that duplicates Guava's
  real one (d8 rejects duplicate classes). The three Kotlin stdlib
  jars' duplicate `module-info.class` entries are stripped in the
  prepared copies (downloads stay pristine).
- Pipeline integration: each AAR extracted to `libs/x/` (res
  compiled by aapt2, linked with `--extra-packages` for all 23
  library packages so their R classes exist, `--auto-add-overlay`),
  classes.jar flattened to `libs/jars/` for javac + d8. Library
  manifest entries merged BY HAND into our manifest:
  SignInHubActivity, RevocationBoundService, GoogleApiActivity,
  `com.google.android.gms.version` meta-data (=
  @integer/google_play_services_version, 12451000, from basement
  resources — verified present in the final binary manifest), and
  `android:appComponentFactory` from androidx.core. SignInHubActivity
  extends FragmentActivity, which is why the fragment/activity
  chain is in the tree.
- `default_web_client_id` is set from the web (type 3) client
  `720304451502-ih61sa67e59lt1040t1c3pl125lj3nj0.apps.googleusercontent.com`
  in `res/values/strings.xml`, and the same id is passed to
  `requestServerAuthCode(...)`.
- **libs/ is NOT for GitHub**: when pushing, ship `fetch-libs.sh`
  (+ this report + README) and leave `libs/` out; the build
  recreates it on any machine with curl + unzip.

## Sign-in / session behaviour (Flutter parity)

- Scopes: email, profile, `drive.appdata`, `drive.file`.
- Fresh Google sign-in replaces the profile exactly like Flutter's
  saveUser (name → email prefix fallback, photo → '', INR, dark,
  biometric off); wallet data untouched.
- Guest = `guest_001` / "Guest User" / `guest@smartwallet.app`.
- Link (Settings or Drive card): only id/name/email/photo change —
  data, currency, biometric, theme kept (photo falls back to the
  current one when Google returns none).
- Sign out: `revokeAccess()` (Flutter's disconnect) + `signOut()`,
  then clear ONLY the stored user + session flag — data remains
  (Flutter `clearUser()` parity).
- **Session model deviation (documented, deliberate):** Flutter
  keys "logged in" off a stored user's presence; the native seed
  data ships a demo profile (`user_001`), so presence can't
  distinguish first run. Native keeps an explicit `signed_in` flag
  in app preferences (outside the backup file, like Flutter's
  settings box). Consequence: on the first Phase 5 launch, existing
  testers see the Login screen ONCE and tap "Continue as Guest"
  (or Google) — one tap, nothing is lost.
- Gate (pure `SessionGate`, unit-tested): no session → Login
  (LAUNCHER `LoginActivity`, forwards when a session exists);
  session + biometricEnabled + API 28+ + hardware enrolled →
  `LockActivity`; LockActivity sets a process-lifetime unlocked
  flag so in-session navigation doesn't re-prompt.

## Drive backup notes

- REST via HttpURLConnection, token from `GoogleAuthUtil.getToken`
  with `oauth2:…drive.appdata …drive.file` on a background thread —
  the same mechanism Flutter's plugin uses for its auth headers.
  Behind a `TokenProvider` interface (AuthService in the app).
- File: `smart_wallet_backup.smartwallet` in appDataFolder; list
  query/fields exactly as Flutter's. Upload: if a file exists,
  PATCH `upload/drive/v3/files/{id}?uploadType=media`; else
  two-step — POST metadata create (name + parents appDataFolder +
  Flutter's description "Smart Wallet Encrypted Database Cloud
  Backup"), then PATCH the media. Download: GET `files/{id}?alt=media`.
- Backup bytes come from BackupCodec, with the SAME optional
  password dialog as local export (Flutter's upload path takes an
  optional password the same way).
- Restore reuses the Phase 4 flow unchanged: download → temp
  content → inspect → password if encrypted → preview → confirm →
  safety snapshot → replace → notifications resync (undo works).
- 401/403 → token invalidated, one retry with a fresh token
  (Flutter's authenticated-client behaviour). After a successful
  upload, `last_cloud_backup_time` is persisted (app preferences —
  Flutter keeps it in its settings box, also outside the backup).
- Errors surface as toasts/status text; a recoverable-auth error
  offers a "Grant Drive Access" button that launches Google's
  consent intent.
- Drive card states: guest → explanation + Link button; Google
  user → account, last-backup stamp, live cloud info probe
  (modified time + size), Backup / Restore buttons, busy states.

## Biometric notes

- Framework only: `android.hardware.biometrics.BiometricPrompt` +
  `BiometricManager` (API 29+ probe; API 28 uses the deprecated
  FingerprintManager probe; API 26–27 → UNSUPPORTED). No
  androidx.biometric anywhere.
- API 30+: `setAllowedAuthenticators(BIOMETRIC_WEAK |
  DEVICE_CREDENTIAL)` — PIN/password inside the system prompt
  (Flutter's biometricOnly:false). API 28–29: negative-button
  prompt + a separate "Use PIN / Password" keyguard button on the
  lock screen.
- Never locks out: gate routes to the lock only when a probe says
  AVAILABLE; the lock re-checks and lets the user in with a notice
  if biometrics vanished, and NO_BIOMETRICS / HW_NOT_PRESENT /
  NO_DEVICE_CREDENTIAL prompt errors also fall through to the
  dashboard with a notice. Lockout errors show a wait message;
  plain failures show Flutter's "Authentication failed. Try again."
- Settings → Security toggle: enabling runs a real prompt first
  and only saves `biometricEnabled = true` on success; the reason
  string is Flutter's "Authenticate to access Smart Wallet".
- Error constants are the framework's `BIOMETRIC_ERROR_*` (the
  androidx `ERROR_*` names don't exist in the framework API).

## Widget notes

- Layout/drawables ported from the Flutter widget XML: #1A1C36
  panel, purple stroke, "SMART WALLET" + "Net Balance" chip,
  18sp balance, divider, three tinted buttons (↓ Expense / ↑ Income
  / 🍽️ Split). Info: 180×70dp min, targetCell 4×2,
  updatePeriodMillis 1800000, resizeMode horizontal|vertical,
  home_screen category, Flutter's description text.
- Balance read straight from `smartwallet_db.json` in filesDir
  (Store.parse + WalletLogic.netWallet) so a cold widget process
  never triggers Store seeding; formatting = Flutter's WidgetService
  exactly (symbol + 2dp, no grouping).
- Buttons are PendingIntents to MainActivity with
  smartwallet://quick-add?type=income|expense|split; MainActivity
  (singleTop, VIEW intent-filter on the smartwallet scheme) opens
  TxEditActivity prefilled — expense/income via the existing
  preset_type extra, split via EXTRA_START_SPLIT. Body tap →
  smartwallet://open-dashboard.
- Refresh: `Store.save()` calls `QuickAddWidgetProvider.refreshAll`
  (guarded, no-op with no widgets placed) + the system period.
- **Preview-build fix worth knowing:** the preview package differs
  from the source package, so its manifest now writes all 21 app
  component names fully-qualified (`com.smartwallet.smart_wallet.*`)
  and the three R-referencing files (Store, NotifReceiver,
  QuickAddWidgetProvider) get an `import com.smartwallet.preview.R;`
  in the preview copy. The launcher activity in the preview APK
  verifiably resolves to the real class.

## Deviations summary

1. Session flag instead of user-presence (explained above; one-tap
   Guest on first Phase 5 launch).
2. Drive upload uses the two-step metadata+media simple upload
   instead of multipart (functionally identical result).
3. Widget balance format keeps Flutter's *ungrouped* numbers
   (₹1500.00, not ₹1,500.00) — that's what Flutter's WidgetService
   printed; the in-app dashboard keeps its Indian grouping.
4. Coroutines jars are dexed although only SavedStateHandle
   references them — kept deliberately so the FragmentActivity
   sign-in hub can never hit a missing class at runtime.

## Ram's required Firebase steps (before Google Sign-In can work)

In Firebase console → project **smart-wallet-by-ram**:

1. Project settings → the existing Android app
   `com.smartwallet.smart_wallet` → **Add fingerprint** → SHA-1
   `29a0f8b118869f726da64b714cd415a3b9f2bbb8` (the native build's
   signing key — same key as every phase so far).
2. **Add a second Android app** with package `com.smartwallet.preview`
   and the same SHA-1 `29a0f8b118869f726da64b714cd415a3b9f2bbb8`
   (so the side-by-side preview build can sign in too).
3. Google Cloud console (same project): make sure the **Google
   Drive API** is enabled.
4. If the OAuth consent screen is still in **Testing** mode, add
   your Gmail address as a **test user** (Google Auth Platform →
   Audience) — otherwise sign-in fails with an access-blocked error.
5. Nothing to download or replace in the app: the web client id is
   already baked in; google-services.json is not read by the native
   build.

Until step 1 is done, "Continue with Google" fails with code 10 —
the Login screen says so in plain words. Guest mode, biometric and
the widget work regardless.

## Phone-test checklist

1. Install the preview APK over the Phase 4 preview (same key).
   First launch shows the **Login screen** — tap **Continue as
   Guest**; your existing data should be intact.
2. Add the **Smart Wallet Quick Add** widget to the home screen:
   balance matches the dashboard net; tap **Expense / Income /
   Split** — the editor opens prefilled (Split opens the split
   editor); tap the widget body → dashboard.
3. Settings → Security: turn **Biometric lock** on (it should
   prompt first). Kill and relaunch the app → lock screen →
   fingerprint unlocks; Cancel keeps you on the lock; Sign Out
   returns to Login with data intact. (Nothing Phone 2a: also
   confirm the prompt looks right.)
4. After the Firebase steps: Login → **Continue with Google** →
   account picker → lands on the dashboard with your name/photo in
   Settings. Settings shows "✓ Signed in with Google".
5. Import/Export → **☁️ Backup to Drive** (try once with a
   password, once without): Drive card then shows the cloud
   modified time + size and the last-backup stamp. Change a
   transaction, then **Restore from Drive** → same preview dialog
   as local restore → confirm → data rolls back; **Undo Last
   Restore** still works.
6. As a guest: Settings → **Link Google Account** → after linking,
   the Drive card becomes active and all pre-link data is still
   there.
7. Phase 3 leftovers if not yet done: notification permission
   prompt on first dashboard entry, and a planned-payment reminder
   firing at the right time (exact alarms on the 2a).
