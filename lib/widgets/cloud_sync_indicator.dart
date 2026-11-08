import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../services/cloud_sync_service.dart';
import '../core/layout/responsive.dart';

String _ago(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

({IconData icon, Color color, String label}) _visual(CloudSyncStatus s) {
  switch (s) {
    case CloudSyncStatus.synced:
      return (icon: Icons.cloud_done_rounded, color: AppColors.income, label: 'Synced');
    case CloudSyncStatus.syncing:
      return (icon: Icons.cloud_sync_rounded, color: AppColors.primary, label: 'Syncing');
    case CloudSyncStatus.pending:
      return (icon: Icons.cloud_upload_rounded, color: AppColors.primary, label: 'Pending');
    case CloudSyncStatus.offline:
      return (icon: Icons.cloud_off_rounded, color: Colors.grey, label: 'Offline');
    case CloudSyncStatus.needsAuth:
      return (icon: Icons.cloud_outlined, color: Colors.orange, label: 'Connect');
    case CloudSyncStatus.conflict:
      return (icon: Icons.sync_problem_rounded, color: Colors.orange, label: 'Conflict');
    case CloudSyncStatus.needsPassword:
      return (icon: Icons.lock_outline_rounded, color: Colors.orange, label: 'Locked');
    case CloudSyncStatus.error:
      return (icon: Icons.error_outline_rounded, color: AppColors.expense, label: 'Error');
    case CloudSyncStatus.disabled:
      return (icon: Icons.cloud_off_rounded, color: Colors.grey, label: 'Local');
  }
}

/// Small "Synced / Syncing / Offline" chip with the last-synced time.
/// Hidden when sync is disabled (guest user).
class CloudSyncIndicator extends StatelessWidget {
  const CloudSyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CloudSyncState>(
      valueListenable: CloudSyncService.instance.state,
      builder: (context, st, _) {
        if (st.status == CloudSyncStatus.disabled) return const SizedBox.shrink();
        final v = _visual(st.status);
        return Tooltip(
          message: st.message ?? 'Google Drive: ${v.label} · last synced ${_ago(st.lastSynced)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showCloudSyncSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  st.status == CloudSyncStatus.syncing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: v.color),
                        )
                      : Icon(v.icon, size: 20, color: v.color),
                  const SizedBox(height: 2),
                  Text(
                    st.status == CloudSyncStatus.synced ? _ago(st.lastSynced) : v.label,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: v.color),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showCloudSyncSheet(BuildContext context) {
  final service = CloudSyncService.instance;
  return showAppSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => ValueListenableBuilder<CloudSyncState>(
      valueListenable: service.state,
      builder: (ctx, st, _) {
        final v = _visual(st.status);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(v.icon, color: v.color),
                    const SizedBox(width: 10),
                    Text('Google Drive sync: ${v.label}', style: Theme.of(ctx).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Last synced: ${_ago(st.lastSynced)}'),
                if (st.message != null) ...[
                  const SizedBox(height: 6),
                  Text(st.message!, style: Theme.of(ctx).textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                if (st.status == CloudSyncStatus.needsAuth)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_to_drive_rounded),
                      label: const Text('Connect Google Drive'),
                      // Called straight from the tap so the browser allows the popup.
                      onPressed: () => service.connectDriveAndSync(),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sync now'),
                      onPressed: st.status == CloudSyncStatus.syncing
                          ? null
                          : () => service.syncNow(initial: true, userInitiated: true),
                    ),
                  ),
                  if (st.status == CloudSyncStatus.conflict || st.status == CloudSyncStatus.needsPassword) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download_rounded),
                        label: const Text('Pull from Drive (replace this device\'s data)'),
                        onPressed: () => service.pullNow(),
                      ),
                    ),
                  ],
                  if (st.status == CloudSyncStatus.conflict) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('Keep this device (overwrite Drive)'),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: const Text('Overwrite Drive?'),
                              content: const Text(
                                  'Changes made on your other devices since the last sync will be lost.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Overwrite')),
                              ],
                            ),
                          );
                          if (ok == true) await service.pushNow();
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Dialogs the sync service shows (password, conflict, connect Drive).
class AppCloudSyncPrompter implements CloudSyncPrompter {
  BuildContext? get _ctx => rootNavigatorKey.currentContext;

  @override
  Future<String?> askBackupPassword() async {
    final ctx = _ctx;
    if (ctx == null) return null;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Encrypted Drive backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your Google Drive backup is password protected. Enter the password to sync it.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.key_rounded)),
              onSubmitted: (_) => Navigator.pop(d, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Unlock')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    return ok == true && text.isNotEmpty ? text : null;
  }

  @override
  Future<SyncConflictChoice?> askConflict({required DateTime remoteModified, required bool firstSync}) async {
    final ctx = _ctx;
    if (ctx == null) return null;
    final when = remoteModified.toLocal().toString().split('.').first;
    return showDialog<SyncConflictChoice>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Google Drive has newer data'),
        content: Text(firstSync
            ? 'A Smart Wallet backup (saved $when) already exists in your Google Drive, and this device also has data.\n\n'
                'Pull the Drive data (replaces this device\'s data), or keep this device\'s data (replaces the Drive backup)?'
            : 'Your Drive backup was changed on another device ($when), and this device has unsynced changes.\n\n'
                'Pull the Drive data first (this device\'s unsynced changes are discarded), or keep this device\'s data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Decide later')),
          TextButton(
            onPressed: () => Navigator.pop(d, SyncConflictChoice.keepThisDevice),
            child: const Text('Keep this device'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, SyncConflictChoice.pullFromDrive),
            child: const Text('Pull from Drive'),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> askConnectDrive() async {
    final ctx = _ctx;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Sync with Google Drive'),
        content: Text(kIsWeb
            ? 'Allow Smart Wallet to access its private Google Drive backup so this browser shows the same data as your phone.'
            : 'Allow Smart Wallet to access its private Google Drive backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Not now')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_to_drive_rounded),
            label: const Text('Connect Drive'),
            onPressed: () {
              // Start the authorization popup inside the tap handler.
              CloudSyncService.instance.connectDriveAndSync();
              Navigator.pop(d);
            },
          ),
        ],
      ),
    );
  }
}
