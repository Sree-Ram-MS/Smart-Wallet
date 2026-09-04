import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'backup_service.dart';
import 'auth_service.dart';
import 'hive_service.dart';

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
  static const String _backupFileName = 'smart_wallet_backup.smartwallet';

  /// Get authenticated Drive API client
  static Future<drive.DriveApi?> _getDriveApi({bool forceFresh = false}) async {
    try {
      GoogleSignInAccount? account = AuthService.googleSignIn.currentUser;
      if (account != null) {
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

      // Ensure Drive scopes are requested and granted
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
            debugPrint('[GoogleDrive] User denied Google Drive permission scope.');
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

  /// Check if a cloud backup exists in the user's private Google Drive AppData folder
  static Future<GoogleDriveBackupInfo?> getLatestBackupInfo({bool forceFresh = false}) async {
    try {
      final driveApi = await _getDriveApi(forceFresh: forceFresh);
      if (driveApi == null) return null;

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

  /// 1-Tap Upload database backup directly into Google Drive AppData folder
  static Future<bool> uploadBackupToGoogleDrive({String? password}) async {
    try {
      return await _performUpload(password: password);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403 || e.status == 401) {
        debugPrint('[GoogleDrive] 403/401 received. Disconnecting stale token cache...');
        try {
          final account = AuthService.googleSignIn.currentUser;
          await account?.clearAuthCache();
        } catch (_) {}
        return await _performUpload(password: password, forceFresh: true);
      }
      rethrow;
    }
  }

  static Future<bool> _performUpload({String? password, bool forceFresh = false}) async {
    final driveApi = await _getDriveApi(forceFresh: forceFresh);
    if (driveApi == null) {
      throw Exception('Could not authenticate with Google Drive. Please ensure permissions are granted.');
    }

    // 1. Generate backup payload file
    final localFile = await BackupService.createBackupFile(password: password);
    final fileLength = await localFile.length();
    final stream = localFile.openRead();
    final media = drive.Media(stream, fileLength);

    // 2. Check if a backup file already exists in AppData folder
    final existing = await getLatestBackupInfo(forceFresh: forceFresh);

    if (existing != null) {
      // Update existing backup file
      final updateMeta = drive.File()..modifiedTime = DateTime.now();
      await driveApi.files.update(
        updateMeta,
        existing.fileId,
        uploadMedia: media,
      );
    } else {
      // Create new backup file in AppData folder
      final newMeta = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..description = 'Smart Wallet Encrypted Database Cloud Backup';

      await driveApi.files.create(
        newMeta,
        uploadMedia: media,
      );
    }

    // Save last cloud sync time
    try {
      await HiveService.settingsBox.put('last_cloud_backup_time', DateTime.now().toIso8601String());
    } catch (_) {}

    // Clean up local temp file
    try {
      if (await localFile.exists()) await localFile.delete();
    } catch (_) {}

    return true;
  }

  /// Downloads and restores the latest backup from Google Drive AppData folder
  static Future<BackupPreviewInfo> downloadBackupFromGoogleDrive({String? password}) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Could not connect to Google Drive. Please ensure you are logged in.');
    }

    final backupInfo = await getLatestBackupInfo();
    if (backupInfo == null) {
      throw Exception('No cloud backup found on your Google Drive.');
    }

    // Download file content
    final drive.Media media = await driveApi.files.get(
      backupInfo.fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    // Save to temp file to inspect and parse preview
    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/drive_backup.smartwallet');
    await tempFile.writeAsBytes(bytes);

    try {
      final preview = await BackupService.loadBackupPreview(tempFile, password: password);
      return preview;
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
