import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'backup_service.dart';
import 'auth_service.dart';
import 'hive_service.dart';

/// Thrown when Google Drive needs the user to (re)authorize access.
/// On the web this happens on every page load and when the 1-hour GIS token
/// expires, because tokens can only be obtained interactively (popup).
class DriveAuthRequiredException implements Exception {
  final String message;
  const DriveAuthRequiredException([this.message = 'Google Drive access needs to be granted.']);
  @override
  String toString() => message;
}

class _GoogleHttpClient extends http.BaseClient {
  final Future<Map<String, String>> Function() _headers;
  final http.Client _client = http.Client();

  _GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headers());
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

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

/// Result of downloading the Drive backup (preview + the remote file's
/// modifiedTime, so callers can record what they synced against).
class DriveDownloadResult {
  final BackupPreviewInfo preview;
  final DateTime remoteModifiedTime;
  const DriveDownloadResult(this.preview, this.remoteModifiedTime);
}

class GoogleDriveBackupService {
  static const String _backupFileName = 'smart_wallet_backup.smartwallet';

  static const List<String> driveScopes = [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ];

  /// Settings key: Drive `modifiedTime` of the backup we last uploaded or
  /// restored. Used to detect changes made by another device.
  static const String lastRemoteModifiedKey = 'cloud_sync_remote_modified';

  /// Settings key: when this device last finished a sync with Drive.
  static const String lastCloudBackupKey = 'last_cloud_backup_time';

  /// Drive modifiedTime of the last file downloaded by
  /// [downloadBackupFromGoogleDrive]; record it with [markSynced] once the
  /// user actually restores it.
  static DateTime? lastDownloadedRemoteModified;

  // ─── Web token handling ─────────────────────────────────────────────────────
  // GIS access tokens live for 1 hour and cannot be refreshed silently, so we
  // remember when we got one and ask again (interactively) after it expires.
  static DateTime? _webTokenExpiry;

  static bool get hasWebDriveToken =>
      _webTokenExpiry != null && DateTime.now().isBefore(_webTokenExpiry!);

  static void invalidateWebToken() => _webTokenExpiry = null;

  /// Web only: shows the Google authorization popup for the Drive scopes.
  /// MUST be called directly from a user gesture (button tap), otherwise the
  /// browser blocks the popup.
  static Future<bool> authorizeWeb() async {
    try {
      final granted = await AuthService.googleSignIn.requestScopes(driveScopes);
      if (granted) {
        _webTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
      }
      return granted;
    } catch (e) {
      debugPrint('[GoogleDrive] Web authorization failed: $e');
      return false;
    }
  }

  static Future<Map<String, String>> _webAuthHeaders() async {
    final tokens = await GoogleSignInPlatform.instance.getTokens(
      email: AuthService.googleSignIn.currentUser?.email ?? HiveService.getUser()?.email ?? '',
      shouldRecoverAuth: false,
    );
    final token = tokens.accessToken;
    if (token == null || token.isEmpty) {
      invalidateWebToken();
      throw const DriveAuthRequiredException();
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Get authenticated Drive API client.
  ///
  /// [interactive] = false never shows any UI (used by background auto-sync):
  /// it returns null / throws [DriveAuthRequiredException] instead.
  static Future<drive.DriveApi?> _getDriveApi({bool forceFresh = false, bool interactive = true}) async {
    if (kIsWeb) {
      if (!hasWebDriveToken) {
        if (!interactive) throw const DriveAuthRequiredException();
        final ok = await authorizeWeb();
        if (!ok) throw const DriveAuthRequiredException('Google Drive permission was not granted.');
      }
      return drive.DriveApi(_GoogleHttpClient(_webAuthHeaders));
    }

    try {
      GoogleSignInAccount? account = AuthService.googleSignIn.currentUser;
      if (account != null) {
        try {
          await account.clearAuthCache();
        } catch (_) {}
      }
      account ??= await AuthService.googleSignIn.signInSilently();
      if (interactive) {
        account ??= await AuthService.googleSignIn.signIn();
      }

      if (account == null) {
        debugPrint('[GoogleDrive] User not signed in.');
        return null;
      }

      // Ensure Drive scopes are requested and granted
      try {
        final hasScope = await AuthService.googleSignIn.canAccessScopes([
          drive.DriveApi.driveAppdataScope,
        ]);
        if (!hasScope) {
          if (!interactive) throw const DriveAuthRequiredException();
          final granted = await AuthService.googleSignIn.requestScopes(driveScopes);
          if (!granted) {
            debugPrint('[GoogleDrive] User denied Google Drive permission scope.');
            return null;
          }
        }
      } on DriveAuthRequiredException {
        rethrow;
      } catch (scopeErr) {
        debugPrint('[GoogleDrive Scope Check Warning] $scopeErr');
      }

      final signedIn = account;
      return drive.DriveApi(_GoogleHttpClient(() => signedIn.authHeaders));
    } on DriveAuthRequiredException {
      rethrow;
    } catch (e, st) {
      debugPrint('[GoogleDrive Error] $e\n$st');
      return null;
    }
  }

  static Future<GoogleDriveBackupInfo?> _findBackup(drive.DriveApi driveApi) async {
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id, name, modifiedTime, size)',
    );

    final files = fileList.files;
    if (files == null || files.isEmpty) return null;

    final file = files.first;
    return GoogleDriveBackupInfo(
      fileId: file.id ?? '',
      name: file.name ?? _backupFileName,
      modifiedTime: file.modifiedTime ?? DateTime.now(),
      sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
    );
  }

  /// Check if a cloud backup exists in the user's private Google Drive AppData folder
  static Future<GoogleDriveBackupInfo?> getLatestBackupInfo({bool forceFresh = false}) async {
    try {
      final driveApi = await _getDriveApi(forceFresh: forceFresh);
      if (driveApi == null) return null;
      return await _findBackup(driveApi);
    } on DriveAuthRequiredException {
      rethrow;
    } catch (e, st) {
      debugPrint('[GoogleDrive] getLatestBackupInfo error: $e\n$st');
      return null;
    }
  }

  /// Same as [getLatestBackupInfo] but never shows UI and lets errors
  /// (offline, auth required) propagate so auto-sync can report them.
  static Future<GoogleDriveBackupInfo?> getLatestBackupInfoForSync() async {
    final driveApi = await _getDriveApi(interactive: false);
    if (driveApi == null) throw const DriveAuthRequiredException();
    return _findBackup(driveApi);
  }

  /// 1-Tap Upload database backup directly into Google Drive AppData folder
  static Future<bool> uploadBackupToGoogleDrive({String? password, bool interactive = true}) async {
    try {
      return await _performUpload(password: password, interactive: interactive);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403 || e.status == 401) {
        if (kIsWeb) {
          invalidateWebToken();
          throw const DriveAuthRequiredException('Google Drive session expired. Please reconnect.');
        }
        debugPrint('[GoogleDrive] 403/401 received. Disconnecting stale token cache...');
        try {
          final account = AuthService.googleSignIn.currentUser;
          await account?.clearAuthCache();
        } catch (_) {}
        return await _performUpload(password: password, forceFresh: true, interactive: interactive);
      }
      rethrow;
    }
  }

  static Future<bool> _performUpload({String? password, bool forceFresh = false, bool interactive = true}) async {
    final driveApi = await _getDriveApi(forceFresh: forceFresh, interactive: interactive);
    if (driveApi == null) {
      if (!interactive) throw const DriveAuthRequiredException();
      throw Exception('Could not authenticate with Google Drive. Please ensure permissions are granted.');
    }

    // 1. Generate backup payload in memory (works on web and native)
    final snapshotTime = DateTime.now();
    final bytes = BackupService.createBackupBytes(password: password);
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);

    // 2. Check if a backup file already exists in AppData folder
    final existing = await _findBackup(driveApi);

    drive.File result;
    if (existing != null) {
      // Update existing backup file
      final updateMeta = drive.File()..modifiedTime = DateTime.now().toUtc();
      result = await driveApi.files.update(
        updateMeta,
        existing.fileId,
        uploadMedia: media,
        $fields: 'id, modifiedTime',
      );
    } else {
      // Create new backup file in AppData folder
      final newMeta = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..description = 'Smart Wallet Encrypted Database Cloud Backup';

      result = await driveApi.files.create(
        newMeta,
        uploadMedia: media,
        $fields: 'id, modifiedTime',
      );
    }

    final now = DateTime.now().toIso8601String();
    try {
      await HiveService.settingsBox.put('last_backup_time', now);
    } catch (_) {}
    await markSynced(remoteModified: result.modifiedTime ?? DateTime.now(), syncedAt: snapshotTime);

    return true;
  }

  /// Records that local data now matches the Drive file with [remoteModified].
  /// [syncedAt] is when the uploaded snapshot was taken (changes after it
  /// still count as unsynced).
  static Future<void> markSynced({required DateTime remoteModified, DateTime? syncedAt}) async {
    try {
      await HiveService.settingsBox.put(lastRemoteModifiedKey, remoteModified.toUtc().toIso8601String());
      await HiveService.settingsBox.put(lastCloudBackupKey, (syncedAt ?? DateTime.now()).toIso8601String());
    } catch (_) {}
  }

  static DateTime? get lastSyncedRemoteModified {
    final raw = HiveService.settingsBox.get(lastRemoteModifiedKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  static DateTime? get lastCloudSyncTime {
    final raw = HiveService.settingsBox.get(lastCloudBackupKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// Downloads raw bytes of the Drive backup.
  static Future<({List<int> bytes, GoogleDriveBackupInfo info})?> downloadBackupBytes({bool interactive = true}) async {
    final driveApi = await _getDriveApi(interactive: interactive);
    if (driveApi == null) {
      if (!interactive) throw const DriveAuthRequiredException();
      throw Exception('Could not connect to Google Drive. Please ensure you are logged in.');
    }

    final backupInfo = await _findBackup(driveApi);
    if (backupInfo == null) return null;

    final drive.Media media = await driveApi.files.get(
      backupInfo.fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return (bytes: bytes, info: backupInfo);
  }

  /// Downloads and previews the latest backup from Google Drive AppData folder
  static Future<BackupPreviewInfo> downloadBackupFromGoogleDrive({String? password}) async {
    final result = await downloadBackupBytes();
    if (result == null) {
      throw Exception('No cloud backup found on your Google Drive.');
    }
    final preview = await BackupService.loadBackupPreview(result.bytes, password: password);
    lastDownloadedRemoteModified = result.info.modifiedTime;
    return preview;
  }
}
