import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../core/platform/platform_helpers.dart';
import 'backup_service.dart';
import 'google_drive_backup_service.dart';
import 'hive_service.dart';

/// What the small sync indicator shows.
enum CloudSyncStatus {
  /// Guest / not signed in with Google: sync is off.
  disabled,

  /// Signed in, but Drive access must be granted (always after a page load on
  /// the web, and when the 1-hour web token expires).
  needsAuth,

  /// Local changes waiting for the debounce timer.
  pending,
  syncing,
  synced,

  /// No network; will retry.
  offline,

  /// Drive has changes from another device and this device has changes too.
  conflict,

  /// The Drive backup is encrypted and we need the password to read it.
  needsPassword,
  error,
}

enum SyncConflictChoice { pullFromDrive, keepThisDevice }

/// UI hooks the app registers so the service can ask the user things.
abstract class CloudSyncPrompter {
  Future<String?> askBackupPassword();
  Future<SyncConflictChoice?> askConflict({required DateTime remoteModified, required bool firstSync});
  Future<void> askConnectDrive();
}

class CloudSyncState {
  final CloudSyncStatus status;
  final DateTime? lastSynced;
  final String? message;
  const CloudSyncState(this.status, {this.lastSynced, this.message});
}

/// Keeps Google Drive (appDataFolder backup) as the source of truth:
/// pulls a newer Drive backup after login / app start, and uploads a backup
/// ~5 s after any local data change. Never blindly overwrites a Drive file
/// that another device changed since our last sync.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const Duration debounce = Duration(seconds: 5);
  static const String _localModifiedKey = 'cloud_sync_local_modified';
  static const String _passwordKey = 'cloud_sync_password';
  static const String _autoSyncKey = 'cloud_auto_sync';

  /// Settings keys that are not user data (changing them must not trigger an upload).
  static const Set<String> _syncedSettingsKeys = {'analytics_card_order'};

  final ValueNotifier<CloudSyncState> state =
      ValueNotifier(const CloudSyncState(CloudSyncStatus.disabled));

  CloudSyncPrompter? prompter;

  /// Called after Drive data replaced the local database (refresh providers).
  VoidCallback? onDataReplaced;

  final List<StreamSubscription> _subs = [];
  Timer? _debounceTimer;
  Timer? _retryTimer;
  bool _applyingRemote = false;
  bool _busy = false;
  bool _started = false;
  bool _askedConnectThisSession = false;

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static bool get isGoogleUser {
    final user = HiveService.getUser();
    if (user == null) return false;
    if (user.id.startsWith('guest')) return false;
    return user.email.isNotEmpty && !user.email.endsWith('@smartwallet.app') && !user.email.endsWith('@smartwallet.local');
  }

  String? get syncPassword {
    final p = HiveService.settingsBox.get(_passwordKey);
    return (p is String && p.isNotEmpty) ? p : null;
  }

  /// Password used to encrypt auto-sync uploads (null = not encrypted).
  /// Stored locally only (the local Hive data itself is not encrypted).
  Future<void> setSyncPassword(String? password) async {
    if (password == null || password.trim().isEmpty) {
      await HiveService.settingsBox.delete(_passwordKey);
    } else {
      await HiveService.settingsBox.put(_passwordKey, password.trim());
    }
  }

  DateTime? get _localModified {
    final raw = HiveService.settingsBox.get(_localModifiedKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  bool get _hasUnsyncedLocalChanges {
    final local = _localModified;
    if (local == null) return false;
    final last = GoogleDriveBackupService.lastCloudSyncTime;
    return last == null || local.isAfter(last);
  }

  bool get _localHasUserData =>
      HiveService.transactionsBox.isNotEmpty ||
      HiveService.accountsBox.isNotEmpty ||
      HiveService.plannedBox.isNotEmpty ||
      HiveService.debtCreditBox.isNotEmpty ||
      HiveService.goalsBox.isNotEmpty;

  void _set(CloudSyncStatus status, {String? message}) {
    state.value = CloudSyncState(status,
        lastSynced: GoogleDriveBackupService.lastCloudSyncTime, message: message);
  }

  /// Auto sync (upload ~5 s after changes, pull on start). On by default.
  bool get autoSync {
    final v = HiveService.settingsBox.get(_autoSyncKey);
    return v is bool ? v : true;
  }

  Future<void> setAutoSync(bool value) async {
    await HiveService.settingsBox.put(_autoSyncKey, value);
    if (!value) {
      _debounceTimer?.cancel();
      _retryTimer?.cancel();
      _setIdle();
    } else {
      await syncNow(initial: true);
    }
  }

  /// Status to show while auto sync is off and nothing is running.
  void _setIdle() {
    if (!isGoogleUser) return _set(CloudSyncStatus.disabled);
    if (state.value.status == CloudSyncStatus.needsAuth) return;
    _set(_hasUnsyncedLocalChanges ? CloudSyncStatus.pending : CloudSyncStatus.synced,
        message: _hasUnsyncedLocalChanges ? 'Auto sync is off. Upload to Drive to save these changes.' : null);
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start watching local data and do the initial pull/push. Safe to call
  /// repeatedly (e.g. after login).
  Future<void> start() async {
    if (!isGoogleUser) {
      _set(CloudSyncStatus.disabled);
      return;
    }
    if (!_started) {
      _started = true;
      void onChange(_) => _onLocalChange();
      _subs.addAll([
        HiveService.userBox.watch().listen(onChange),
        HiveService.accountsBox.watch().listen(onChange),
        HiveService.categoriesBox.watch().listen(onChange),
        HiveService.transactionsBox.watch().listen(onChange),
        HiveService.plannedBox.watch().listen(onChange),
        HiveService.debtCreditBox.watch().listen(onChange),
        HiveService.templatesBox.watch().listen(onChange),
        HiveService.goalsBox.watch().listen(onChange),
        HiveService.settingsBox.watch().listen((e) {
          if (_syncedSettingsKeys.contains(e.key)) _onLocalChange();
        }),
      ]);
    }
    if (!autoSync) {
      _setIdle();
      return;
    }
    await syncNow(initial: true);
  }

  /// Stop syncing. With [clearMetadata] (sign-out) the record of what was
  /// last synced is forgotten, so another account starts fresh.
  Future<void> stop({bool clearMetadata = false}) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _started = false;
    _askedConnectThisSession = false;
    GoogleDriveBackupService.invalidateWebToken();
    if (clearMetadata) {
      for (final key in [
        _localModifiedKey,
        _passwordKey,
        GoogleDriveBackupService.lastRemoteModifiedKey,
        GoogleDriveBackupService.lastCloudBackupKey,
      ]) {
        await HiveService.settingsBox.delete(key);
      }
    }
    _set(CloudSyncStatus.disabled);
  }

  void _onLocalChange() {
    if (_applyingRemote || !isGoogleUser) return;
    HiveService.settingsBox.put(_localModifiedKey, DateTime.now().toIso8601String());
    final s = state.value.status;
    if (s != CloudSyncStatus.needsAuth &&
        s != CloudSyncStatus.conflict &&
        s != CloudSyncStatus.needsPassword &&
        s != CloudSyncStatus.offline) {
      _set(CloudSyncStatus.pending);
    }
    _debounceTimer?.cancel();
    if (!autoSync) {
      _setIdle();
      return;
    }
    _debounceTimer = Timer(debounce, () => syncNow());
  }

  // ─── Sync ──────────────────────────────────────────────────────────────────

  /// Web: called from a button tap (popup needs a user gesture).
  Future<void> connectDriveAndSync() async {
    if (kIsWeb) {
      final ok = await GoogleDriveBackupService.authorizeWeb();
      if (!ok) {
        _set(CloudSyncStatus.needsAuth, message: 'Google Drive permission was not granted.');
        return;
      }
    } else {
      // Native: interactive sign-in / scope grant if needed.
      await GoogleDriveBackupService.getLatestBackupInfo();
    }
    await syncNow(initial: true, userInitiated: true);
  }

  /// Reconcile with Drive. [initial] = after login/app start (may pull).
  Future<void> syncNow({bool initial = false, bool userInitiated = false}) async {
    if (!isGoogleUser) {
      _set(CloudSyncStatus.disabled);
      return;
    }
    if (_busy) {
      // Re-run after the current sync finishes.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () => syncNow(initial: initial));
      return;
    }
    _busy = true;
    _retryTimer?.cancel();
    _set(CloudSyncStatus.syncing);
    try {
      final remote = await GoogleDriveBackupService.getLatestBackupInfoForSync();
      final lastRemote = GoogleDriveBackupService.lastSyncedRemoteModified;
      final remoteChanged = remote != null &&
          (lastRemote == null || remote.modifiedTime.isAfter(lastRemote.add(const Duration(seconds: 1))));
      final localChanged = _hasUnsyncedLocalChanges;

      if (remote == null) {
        // Nothing on Drive yet: seed it with this device's data.
        if (_localHasUserData || localChanged) {
          await _upload();
        } else {
          _set(CloudSyncStatus.synced);
        }
        return;
      }

      if (remoteChanged) {
        // Drive was changed by another device (or never synced here).
        final firstSync = lastRemote == null;
        final mustAsk = localChanged || (firstSync && _localHasUserData);
        if (mustAsk) {
          final choice = await prompter?.askConflict(remoteModified: remote.modifiedTime, firstSync: firstSync);
          if (choice == SyncConflictChoice.pullFromDrive) {
            await _pull();
          } else if (choice == SyncConflictChoice.keepThisDevice) {
            await _upload();
          } else {
            _set(CloudSyncStatus.conflict,
                message: 'Drive has newer changes from another device. Pull them first.');
          }
        } else {
          await _pull();
        }
        return;
      }

      // Drive unchanged since our last sync.
      if (localChanged) {
        await _upload();
      } else {
        _set(CloudSyncStatus.synced);
      }
    } on DriveAuthRequiredException catch (e) {
      _set(CloudSyncStatus.needsAuth, message: e.message);
      if (kIsWeb && !_askedConnectThisSession && prompter != null) {
        _askedConnectThisSession = true;
        // The dialog's button calls connectDriveAndSync() (user gesture).
        unawaited(prompter!.askConnectDrive());
      }
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) {
        GoogleDriveBackupService.invalidateWebToken();
        _set(CloudSyncStatus.needsAuth, message: 'Google Drive session expired. Tap to reconnect.');
      } else {
        _set(CloudSyncStatus.error, message: 'Drive error ${e.status}: ${e.message}');
        _scheduleRetry();
      }
    } catch (e) {
      if (isNetworkError(e)) {
        _set(CloudSyncStatus.offline, message: 'Offline. Changes will sync when you are back online.');
      } else {
        _set(CloudSyncStatus.error, message: e.toString());
        debugPrint('[CloudSync] $e');
      }
      _scheduleRetry();
    } finally {
      _busy = false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (!autoSync) return;
    _retryTimer = Timer(const Duration(seconds: 60), () => syncNow());
  }

  Future<void> _upload() async {
    await GoogleDriveBackupService.uploadBackupToGoogleDrive(password: syncPassword, interactive: false);
    _set(CloudSyncStatus.synced);
  }

  /// Download the Drive backup and replace local data with it.
  Future<void> _pull() async {
    final result = await GoogleDriveBackupService.downloadBackupBytes(interactive: false);
    if (result == null) {
      _set(CloudSyncStatus.synced);
      return;
    }
    final inspection = BackupService.inspectBytes(result.bytes);
    String? password;
    if (inspection.isEncrypted) {
      password = syncPassword;
      BackupPreviewInfo? preview;
      for (var attempt = 0; attempt < 3 && preview == null; attempt++) {
        if (password == null || attempt > 0) {
          password = await prompter?.askBackupPassword();
          if (password == null || password.isEmpty) {
            _set(CloudSyncStatus.needsPassword, message: 'Drive backup is encrypted. Enter its password to sync.');
            return;
          }
        }
        try {
          preview = await BackupService.loadBackupPreview(result.bytes, password: password);
        } on FormatException {
          preview = null;
        }
      }
      if (preview == null) {
        _set(CloudSyncStatus.needsPassword, message: 'Incorrect backup password.');
        return;
      }
      await _apply(preview, result.info.modifiedTime);
      await setSyncPassword(password);
    } else {
      final preview = await BackupService.loadBackupPreview(result.bytes);
      await _apply(preview, result.info.modifiedTime);
    }
  }

  Future<void> _apply(BackupPreviewInfo preview, DateTime remoteModified) async {
    _applyingRemote = true;
    try {
      await BackupService.restoreDatabase(preview.rawData, replaceAll: true);
    } finally {
      // Let Hive's watch events for the restore fire before re-enabling.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _applyingRemote = false;
    }
    await GoogleDriveBackupService.markSynced(remoteModified: remoteModified);
    await HiveService.settingsBox.delete(_localModifiedKey);
    onDataReplaced?.call();
    _set(CloudSyncStatus.synced);
  }

  // ─── Manual actions (dashboard sync card) ───────────────────────────────────

  /// Web: make sure we hold a Drive token. Must start inside a tap handler
  /// (the token request may open a short Google popup). Returns false if the
  /// user did not grant access.
  Future<bool> _ensureDriveAccess() async {
    if (!kIsWeb || GoogleDriveBackupService.hasWebDriveToken) return true;
    final ok = await GoogleDriveBackupService.authorizeWeb();
    if (!ok) _set(CloudSyncStatus.needsAuth, message: 'Google Drive permission was not granted.');
    return ok;
  }

  /// "Sync latest": pull the newest Drive backup and restore it with the
  /// normal restore logic. When this device has changes that were never
  /// uploaded, [confirmOverwrite] is asked first (false = keep local data).
  /// Returns a short message for a snackbar.
  Future<String> syncLatest({required Future<bool> Function(DateTime remoteModified) confirmOverwrite}) async {
    if (!isGoogleUser) return 'Sign in with Google to sync.';
    if (_busy) return 'A sync is already running.';
    if (!await _ensureDriveAccess()) return 'Google Drive permission was not granted.';
    _busy = true;
    _set(CloudSyncStatus.syncing);
    try {
      final remote = await GoogleDriveBackupService.getLatestBackupInfoForSync();
      if (remote == null) {
        _setIdle();
        return 'No backup on Google Drive yet. Use Upload to Drive first.';
      }
      final lastRemote = GoogleDriveBackupService.lastSyncedRemoteModified;
      final remoteChanged =
          lastRemote == null || remote.modifiedTime.isAfter(lastRemote.add(const Duration(seconds: 1)));
      final localChanged = _hasUnsyncedLocalChanges || (lastRemote == null && _localHasUserData);
      if (!remoteChanged && !localChanged) {
        _set(CloudSyncStatus.synced);
        return 'Already up to date with Google Drive.';
      }
      if (localChanged) {
        final ok = await confirmOverwrite(remote.modifiedTime);
        if (!ok) {
          _setIdle();
          return 'Kept this device\'s data.';
        }
      }
      await _pull();
      final s = state.value.status;
      return s == CloudSyncStatus.synced ? 'Restored the latest Google Drive backup.' : (state.value.message ?? 'Sync stopped.');
    } on DriveAuthRequiredException catch (e) {
      _set(CloudSyncStatus.needsAuth, message: e.message);
      return e.message;
    } catch (e) {
      _set(isNetworkError(e) ? CloudSyncStatus.offline : CloudSyncStatus.error, message: e.toString());
      return isNetworkError(e) ? 'You are offline.' : 'Sync failed: $e';
    } finally {
      _busy = false;
    }
  }

  /// "Upload to Drive": upload now. When Drive was changed by another device
  /// since this device last synced, [confirmOverwrite] is asked first.
  Future<String> uploadNow({required Future<bool> Function(DateTime remoteModified) confirmOverwrite}) async {
    if (!isGoogleUser) return 'Sign in with Google to sync.';
    if (_busy) return 'A sync is already running.';
    if (!await _ensureDriveAccess()) return 'Google Drive permission was not granted.';
    _busy = true;
    _debounceTimer?.cancel();
    _set(CloudSyncStatus.syncing);
    try {
      final remote = await GoogleDriveBackupService.getLatestBackupInfoForSync();
      final lastRemote = GoogleDriveBackupService.lastSyncedRemoteModified;
      if (remote != null &&
          (lastRemote == null || remote.modifiedTime.isAfter(lastRemote.add(const Duration(seconds: 1))))) {
        final ok = await confirmOverwrite(remote.modifiedTime);
        if (!ok) {
          _setIdle();
          return 'Upload cancelled.';
        }
      }
      await _upload();
      return 'Uploaded to Google Drive.';
    } on DriveAuthRequiredException catch (e) {
      _set(CloudSyncStatus.needsAuth, message: e.message);
      return e.message;
    } catch (e) {
      _set(isNetworkError(e) ? CloudSyncStatus.offline : CloudSyncStatus.error, message: e.toString());
      return isNetworkError(e) ? 'You are offline.' : 'Upload failed: $e';
    } finally {
      _busy = false;
    }
  }

  /// User chose "Pull from Drive" in the sync sheet.
  Future<void> pullNow() async {
    if (_busy) return;
    _busy = true;
    _set(CloudSyncStatus.syncing);
    try {
      await _pull();
    } on DriveAuthRequiredException catch (e) {
      _set(CloudSyncStatus.needsAuth, message: e.message);
    } catch (e) {
      _set(isNetworkError(e) ? CloudSyncStatus.offline : CloudSyncStatus.error, message: e.toString());
    } finally {
      _busy = false;
    }
  }

  /// User chose "Keep this device" (overwrite Drive with local data).
  Future<void> pushNow() async {
    if (_busy) return;
    _busy = true;
    _set(CloudSyncStatus.syncing);
    try {
      await _upload();
    } on DriveAuthRequiredException catch (e) {
      _set(CloudSyncStatus.needsAuth, message: e.message);
    } catch (e) {
      _set(isNetworkError(e) ? CloudSyncStatus.offline : CloudSyncStatus.error, message: e.toString());
    } finally {
      _busy = false;
    }
  }
}
