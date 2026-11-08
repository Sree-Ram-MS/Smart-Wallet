# Smart Wallet on the web (GitHub Pages)

The `web-version` branch builds the app for the browser and deploys it to
`https://sree-ram-ms.github.io/Smart-Wallet/` with GitHub Actions
(`.github/workflows/deploy-web.yml`). Login is Google Sign-In, and data syncs
through the same private Google Drive **appDataFolder** backup
(`smart_wallet_backup.smartwallet`) the Android app uses.

## 1. Create the Web OAuth client (same Google Cloud project!)

The Drive `appDataFolder` is private **per Google Cloud project**. The web
client must live in the **same project as the Android OAuth client** (the
Firebase / Cloud project you set up for Android), otherwise the web app sees
an empty Drive folder and the phone and browser never share data.

1. Open <https://console.cloud.google.com/apis/credentials> and select the
   project that holds the **Android** OAuth client
   (package `com.smartwallet.smart_wallet`).
2. **Create credentials → OAuth client ID → Application type: Web application.**
   Name it e.g. `Smart Wallet Web`.
3. **Authorized JavaScript origins:**
   - `https://sree-ram-ms.github.io`
   - for local testing: `http://localhost` and `http://localhost:7357`
   (Origins have no path, so no `/Smart-Wallet`.) Redirect URIs are not needed.
4. Copy the client ID and replace the placeholder in `web/index.html`:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```
5. Make sure the **Google Drive API** is enabled in that project, and the
   OAuth consent screen lists the scopes `drive.appdata` and `drive.file`.
   If the consent screen is in *Testing* mode, add your Google account as a
   test user.

Local test: `flutter run -d chrome --web-hostname localhost --web-port 7357`

## 2. Enable GitHub Pages

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Push to `web-version` (or run the workflow manually from the Actions tab).
   The site is published at `https://sree-ram-ms.github.io/Smart-Wallet/`.
3. If the `github-pages` environment has branch protection rules, allow the
   `web-version` branch (Settings → Environments → github-pages).

**Private repo note:** GitHub Pages for a *private* repository needs a paid
plan (GitHub Pro / Team / Enterprise). On the free plan, either make the repo
public or host `build/web` elsewhere (Firebase Hosting, Netlify, Cloudflare
Pages). If you host elsewhere, add that origin to the OAuth client and change
`--base-href` (use `/` at a domain root).

## 3. How web sign-in and sync behave

- Sign-in uses the official Google button (Google Identity Services). The
  browser keeps no Google session across reloads, so after a reload the app
  shows a **"Connect Drive"** prompt (or tap the cloud icon on the dashboard).
  Browser access tokens last 1 hour; when one expires the cloud icon turns
  to **Connect** and one tap renews it.
- After connecting, if the Drive backup is newer than this browser's data it is
  restored (you are asked for the password if the backup is encrypted).
- Every change is uploaded ~5 s later. The dashboard cloud icon shows
  Synced / Syncing / Pending / Offline and the last-synced time.
- If another device changed the Drive backup since the last sync and this
  device has unsynced changes too, nothing is overwritten: you choose
  **Pull from Drive** or **Keep this device**.
- Not on the web: biometric lock, home-screen widget, local notifications.
- Images picked on the web are stored inline (data URI) so they sync. Images
  picked on Android are stored as phone file paths, so they show as the emoji
  fallback in the browser.

The Android app does the same Drive sync automatically when signed in with
Google (no extra setup needed there).
