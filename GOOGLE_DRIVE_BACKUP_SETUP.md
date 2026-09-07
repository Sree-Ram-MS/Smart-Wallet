# Google Drive Cloud Backup (AppData) Complete Setup Guide for Flutter

This comprehensive guide explains step-by-step how to configure and implement **Google Drive AppData Backup** in any Flutter application. 

This implementation uses the **Google Drive AppData Folder (`drive.appdata`)**, which is a special, hidden folder in the user's Google Drive. 
- Files stored here do not clutter the user's personal Google Drive file list.
- Users cannot accidentally edit, rename, or delete the backup file in Google Drive UI.
- The app only gains permission to access its own private data, maximizing user privacy and security.

---

## Table of Contents
1. [Overview & Prerequisites](#1-overview--prerequisites)
2. [Firebase Project Setup & SHA-1](#2-firebase-project-setup--sha-1)
3. [Enable Google Drive API in Google Cloud Console](#3-enable-google-drive-api-in-google-cloud-console)
4. [Configure OAuth 2.0 Consent Screen & Scopes](#4-configure-oauth-20-consent-screen--scopes)
5. [Flutter Dependencies (`pubspec.yaml`)](#5-flutter-dependencies-pubspecyaml)
6. [Android Platform Configuration](#6-android-platform-configuration)
7. [iOS Platform Configuration (Optional)](#7-ios-platform-configuration-optional)
8. [Production-Ready Dart Implementation](#8-production-ready-dart-implementation)
9. [Troubleshooting & Common Errors](#9-troubleshooting--common-errors)

---

## 1. Overview & Prerequisites

### Architecture Flow
```
[Flutter App]
      │
      ▼
[GoogleSignIn] ──(Request Drive AppData Scope)──► [Google Account Auth]
      │                                                     │
      ▼                                                     ▼
[_GoogleHttpClient] ◄──(Inject Bearer Token Headers)─────────┘
      │
      ▼
[googleapis (DriveApi v3)] ──► [Google Drive Private AppData Folder]
                                      (smart_wallet_backup.smartwallet)
```

---

## 2. Firebase Project Setup & SHA-1

Google Sign-In on Android requires an active OAuth 2.0 Client ID tied to your app's **Package Name (Application ID)** and **SHA-1 Fingerprint**. The simplest way to create and manage this is through Firebase.

### Step 2.1: Create Firebase Project
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (or select an existing one).
3. Name your project and click **Continue**.

### Step 2.2: Add Android Application
1. Click the **Android** icon to register your app.
2. Enter your **Android package name** (must match `applicationId` in `android/app/build.gradle` or `android/app/build.gradle.kts`):
   ```
   com.yourcompany.yourapp
   ```
3. Enter an **App nickname** (optional).

### Step 2.3: Generate and Add SHA-1 Fingerprint
Google Sign-In will fail with `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10, ...)` if your SHA-1 fingerprint is missing or incorrect.

Open a terminal inside your Flutter project directory and run:

**On Windows (PowerShell):**
```powershell
cd android
./gradlew signingReport
```

**On macOS / Linux:**
```bash
cd android
./gradlew signingReport
```

Look for the `Variant: debugUnitTest` or `Variant: debug` section:
```
Variant: debug
Config: debug
Store: C:\Users\Username\.android\debug.keystore
Alias: AndroidDebugKey
SHA1: 45:2A:9C:... (40 characters hex)
```

1. Copy the **SHA1** string.
2. In Firebase Console, paste it under **Debug signing certificate SHA-1**.
3. *(When preparing for release, generate a keystore for release and add the release SHA-1 here as well).*

### Step 2.4: Download `google-services.json`
1. Click **Register app**.
2. Download `google-services.json`.
3. Place this file into your Flutter project at:
   ```
   android/app/google-services.json
   ```

---

## 3. Enable Google Drive API in Google Cloud Console

When you create a project in Firebase, a Google Cloud project with the exact same ID is automatically created. You must enable the **Google Drive API** in that Cloud project.

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. In the top project selector dropdown, select the project that matches your Firebase project.
3. In the search bar at the top, type **Google Drive API** and select it from Marketplace / APIs.
4. Click the blue **ENABLE** button.
5. Wait a few seconds until the API status displays as **API Enabled**.

---

## 4. Configure OAuth 2.0 Consent Screen & Scopes

### Step 4.1: Configure Consent Screen
1. In [Google Cloud Console](https://console.cloud.google.com/), go to **APIs & Services > OAuth consent screen**.
2. Under **User Type**, choose **External** and click **Create**.
3. Fill in the required fields:
   - **App name**: (Your App Name)
   - **User support email**: (Select your email from the dropdown)
   - **Developer contact information**: (Your email)
4. Click **Save and Continue**.

### Step 4.2: Add Scopes
1. On the **Scopes** page, click **Add or Remove Scopes**.
2. In the filter box, type `drive.appdata`.
3. Check the box for:
   - `https://www.googleapis.com/auth/drive.appdata` *(See, create, and delete its own configuration data in your Google Drive)*.
4. Optionally, you can also select:
   - `https://www.googleapis.com/auth/drive.file`
   - `email`
   - `profile`
5. Click **Update** and then **Save and Continue**.

### Step 4.3: Add Test Users (CRITICAL)
While your app is in "Testing" publishing status, **only registered test users can authenticate**. If an unlisted Google account tries to log in, Google will block it with:
`Access blocked: App has not completed the Google verification process`.

1. On the **Test users** page, click **+ ADD USERS**.
2. Enter your Gmail address (and any other test accounts).
3. Click **Save and Continue**.

> **Note for Production**: Once you are ready to publish your app to Google Play Store, you can go back to OAuth consent screen and click **Publish App** to move it to Production status.

---

## 5. Flutter Dependencies (`pubspec.yaml`)

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Authentication
  google_sign_in: ^6.2.2

  # Google APIs & Drive Client
  googleapis: ^13.2.0
  http: ^1.2.2

  # Path provider for creating local temp backup files
  path_provider: ^2.1.4
```

Run:
```bash
flutter pub get
```

---

## 6. Android Platform Configuration

### If using Kotlin DSL (`android/settings.gradle.kts` and `android/app/build.gradle.kts`):

#### 1. `android/settings.gradle.kts`
Ensure the `com.google.gms.google-services` plugin is listed:
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

#### 2. `android/app/build.gradle.kts`
Apply the plugin at the top:
```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.yourcompany.yourapp"
    compileSdk = flutter.compileSdkVersion
    
    defaultConfig {
        applicationId = "com.yourcompany.yourapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
}
```

### If using Groovy DSL (`android/build.gradle` and `android/app/build.gradle`):

#### 1. `android/build.gradle`
```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

#### 2. `android/app/build.gradle`
```groovy
apply plugin: 'com.android.application'
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        applicationId "com.yourcompany.yourapp"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        multiDexEnabled true
    }
}
```

---

## 7. iOS Platform Configuration (Optional)

If targeting iOS:
1. In Firebase Console, add an **iOS App** with your iOS Bundle Identifier.
2. Download `GoogleService-Info.plist` and place it inside `ios/Runner/` using Xcode.
3. Open `ios/Runner/Info.plist` and add the `CFBundleURLTypes` scheme with your `REVERSED_CLIENT_ID` found in `GoogleService-Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.1234567890-abcdefg</string>
        </array>
    </dict>
</array>
```

---

## 8. Production-Ready Dart Implementation

Here is the complete, drop-in architecture to integrate into your new application.

### File 1: `lib/services/auth_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Define scopes including Drive AppData
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Sign in with Google
  static Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final account = await googleSignIn.signIn();
      return account;
    } catch (e, st) {
      debugPrint('[GoogleSignIn Error] $e\n$st');
      return null;
    }
  }

  /// Sign out and disconnect
  static Future<void> signOut() async {
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await googleSignIn.signOut();
    } catch (_) {}
  }
}
```

---

### File 2: `lib/services/google_drive_backup_service.dart`

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Authenticated HTTP Client adapter that attaches Bearer tokens from GoogleSignIn
class _GoogleHttpClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _client = http.Client();

  _GoogleHttpClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _account.authHeaders;
    request.headers.addAll(headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Metadata model for cloud backup
class GoogleDriveBackupInfo {
  final String fileId;
  final String name;
  final DateTime modifiedTime;
  final int sizeBytes;

  const GoogleDriveBackupInfo({
    required this.fileId,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
  });
}

class GoogleDriveBackupService {
  // Change filename according to your app
  static const String _backupFileName = 'my_app_backup.json';

  /// Authenticate and retrieve DriveApi client
  static Future<drive.DriveApi?> _getDriveApi({bool forceFresh = false}) async {
    try {
      GoogleSignInAccount? account = AuthService.googleSignIn.currentUser;
      if (account != null && forceFresh) {
        try {
          await account.clearAuthCache();
        } catch (_) {}
      }
      account ??= await AuthService.googleSignIn.signInSilently();
      account ??= await AuthService.googleSignIn.signIn();

      if (account == null) {
        debugPrint('[GoogleDrive] User not signed in.');
        return null;
      }

      // Check / request Drive scopes
      try {
        final hasScope = await AuthService.googleSignIn.canAccessScopes([
          drive.DriveApi.driveAppdataScope,
        ]);
        if (!hasScope) {
          final granted = await AuthService.googleSignIn.requestScopes([
            drive.DriveApi.driveAppdataScope,
            drive.DriveApi.driveFileScope,
          ]);
          if (!granted) {
            debugPrint('[GoogleDrive] User denied Drive permission scope.');
            return null;
          }
        }
      } catch (scopeErr) {
        debugPrint('[GoogleDrive Scope Check Warning] $scopeErr');
      }

      final httpClient = _GoogleHttpClient(account);
      return drive.DriveApi(httpClient);
    } catch (e, st) {
      debugPrint('[GoogleDrive Error] $e\n$st');
      return null;
    }
  }

  /// Inspect if a backup file exists in user's private Google Drive AppData folder
  static Future<GoogleDriveBackupInfo?> getLatestBackupInfo({bool forceFresh = false}) async {
    try {
      final driveApi = await _getDriveApi(forceFresh: forceFresh);
      if (driveApi == null) return null;

      // Query only the 'appDataFolder' space
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        return null;
      }

      final file = files.first;
      return GoogleDriveBackupInfo(
        fileId: file.id ?? '',
        name: file.name ?? _backupFileName,
        modifiedTime: file.modifiedTime ?? DateTime.now(),
        sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
      );
    } catch (e, st) {
      debugPrint('[GoogleDrive] getLatestBackupInfo error: $e\n$st');
      return null;
    }
  }

  /// Upload a local backup file to Google Drive AppData folder
  static Future<bool> uploadBackupFile(File localFile) async {
    try {
      return await _performUpload(localFile);
    } on drive.DetailedApiRequestError catch (e) {
      // If token expired (401 or 403), clear cache and retry once
      if (e.status == 403 || e.status == 401) {
        debugPrint('[GoogleDrive] Stale token detected. Clearing cache and retrying...');
        try {
          final account = AuthService.googleSignIn.currentUser;
          await account?.clearAuthCache();
        } catch (_) {}
        return await _performUpload(localFile, forceFresh: true);
      }
      rethrow;
    }
  }

  static Future<bool> _performUpload(File localFile, {bool forceFresh = false}) async {
    final driveApi = await _getDriveApi(forceFresh: forceFresh);
    if (driveApi == null) {
      throw Exception('Could not authenticate with Google Drive. Please ensure permissions are granted.');
    }

    final fileLength = await localFile.length();
    final stream = localFile.openRead();
    final media = drive.Media(stream, fileLength);

    // Check if backup already exists
    final existing = await getLatestBackupInfo(forceFresh: forceFresh);

    if (existing != null) {
      // Update existing file
      final updateMeta = drive.File()..modifiedTime = DateTime.now();
      await driveApi.files.update(
        updateMeta,
        existing.fileId,
        uploadMedia: media,
      );
      debugPrint('[GoogleDrive] Existing backup file updated: ${existing.fileId}');
    } else {
      // Create new file inside 'appDataFolder'
      final newMeta = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..description = 'Application Database Cloud Backup';

      final created = await driveApi.files.create(
        newMeta,
        uploadMedia: media,
      );
      debugPrint('[GoogleDrive] New backup created: ${created.id}');
    }

    return true;
  }

  /// Download backup bytes from Google Drive AppData folder
  static Future<List<int>> downloadBackupBytes() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Could not connect to Google Drive. Please ensure you are logged in.');
    }

    final backupInfo = await getLatestBackupInfo();
    if (backupInfo == null) {
      throw Exception('No cloud backup found on your Google Drive.');
    }

    // Download content stream
    final drive.Media media = await driveApi.files.get(
      backupInfo.fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    return bytes;
  }
}
```

---

## 9. Troubleshooting & Common Errors

| Error Code / Message | Root Cause | Solution |
| :--- | :--- | :--- |
| **`ApiException: 10`** | SHA-1 mismatch or wrong package name | Run `cd android; ./gradlew signingReport`, copy the debug SHA-1, and add it to Firebase Console Android App settings. Re-download `google-services.json`. |
| **`ApiException: 12500`** | Support email missing in Firebase/GCP | Open Firebase Console > Project Settings > General. Ensure **Support email** is selected. |
| **`403 Access Blocked: App has not completed verification`** | OAuth Consent screen is in "Testing" mode and current email is not a Test User | Open Google Cloud Console > **APIs & Services > OAuth consent screen > Test users**, and add your Gmail address. |
| **`403 Forbidden: Google Drive API has not been used...`** | Drive API is disabled in Cloud Console | In Google Cloud Console, search for **Google Drive API** and click **ENABLE**. |
| **User cannot find the file in Google Drive website** | Expected behavior for `appDataFolder` | The `appDataFolder` is hidden from the Drive UI. To confirm it exists: Open Google Drive on web > Settings (gear icon) > **Settings > Manage Apps**. You will see your application listed with "Hidden app data". |
| **Token expired / 401 Unauthorized** | Google auth cache has stale token | Call `account.clearAuthCache()` and re-authenticate as shown in the provided `_performUpload` error handler. |
