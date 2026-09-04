import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_backup_service.dart';
import '../../services/hive_service.dart';
import '../../widgets/app_drawer.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});
  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _driveBackupLoading = false;
  bool _driveRestoreLoading = false;
  bool _localBackupLoading = false;
  bool _localRestoreLoading = false;
  bool _csvExportLoading = false;
  bool _csvImportLoading = false;
  String? _statusMsg;
  bool _isError = false;

  String? get _lastCloudBackupTime {
    try {
      final raw = HiveService.settingsBox.get('last_cloud_backup_time');
      if (raw != null) {
        final dt = DateTime.tryParse(raw.toString());
        if (dt != null) return DateUtil.formatDateTime(dt);
      }
    } catch (_) {}
    return null;
  }

  String? get _lastLocalBackupTime {
    try {
      final raw = HiveService.settingsBox.get('last_backup_time');
      if (raw != null) {
        final dt = DateTime.tryParse(raw.toString());
        if (dt != null) return DateUtil.formatDateTime(dt);
      }
    } catch (_) {}
    return null;
  }

  // ─── Direct Google Drive AppData Sync ───────────────────────────────────────

  Future<void> _handleGoogleDriveBackup() async {
    final passwordCtrl = TextEditingController();
    bool usePassword = false;

    final shouldBackup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.add_to_drive_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Backup to Google Drive',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Uploads your complete encrypted database directly into your personal Google Drive (AppData folder). Zero server needed, completely private and accessible on any device with your Google account.',
                style: TextStyle(fontSize: 12.5, color: AppColors.darkTextSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),

              // Password Protection Toggle
              Material(
                color: AppColors.darkCardAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: SwitchListTile(
                  title: const Text('Password Protect / Encrypt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Encrypts data with AES & PBKDF2 key derivation', style: TextStyle(fontSize: 11)),
                  secondary: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                  value: usePassword,
                  onChanged: (v) => setSheetState(() => usePassword = v),
                ),
              ),

              if (usePassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Enter Backup Password',
                    prefixIcon: Icon(Icons.password_rounded),
                    hintText: 'Keep this password safe to restore later',
                  ),
                ),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload to Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (usePassword && passwordCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a password or turn off password protection.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldBackup == true) {
      setState(() {
        _driveBackupLoading = true;
        _statusMsg = null;
      });

      try {
        final password = usePassword ? passwordCtrl.text.trim() : null;
        await GoogleDriveBackupService.uploadBackupToGoogleDrive(password: password);
        if (mounted) {
          setState(() {
            _statusMsg = 'Database successfully backed up to your Google Drive!';
            _isError = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMsg = e.toString();
            _isError = true;
          });
        }
      } finally {
        if (mounted) setState(() => _driveBackupLoading = false);
      }
    }
  }

  Future<void> _handleGoogleDriveRestore() async {
    setState(() {
      _driveRestoreLoading = true;
      _statusMsg = null;
    });

    try {
      final info = await GoogleDriveBackupService.getLatestBackupInfo();
      if (info == null) {
        throw Exception('No cloud backup found on your Google Drive account.');
      }

      String? password;
      BackupPreviewInfo? preview;

      // Try downloading without password first or check if encrypted
      try {
        preview = await GoogleDriveBackupService.downloadBackupFromGoogleDrive();
      } catch (e) {
        // Prompt for password if encrypted
        if (!mounted) return;
        final passCtrl = TextEditingController();
        final passEntered = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_rounded, color: AppColors.accent),
                SizedBox(width: 8),
                Text('Encrypted Cloud Backup'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This cloud backup is password protected. Enter the password:'),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Unlock')),
            ],
          ),
        );

        if (passEntered == true && passCtrl.text.trim().isNotEmpty) {
          password = passCtrl.text.trim();
          preview = await GoogleDriveBackupService.downloadBackupFromGoogleDrive(password: password);
        } else {
          setState(() => _driveRestoreLoading = false);
          return;
        }
      }

      if (!mounted) return;

      // Show preview & confirmation
      final proceed = await _showRestoreConfirmation(preview);
      if (proceed != null) {
        await BackupService.restoreDatabase(preview.rawData, replaceAll: proceed);
        refreshAllData(ref);

        if (mounted) {
          setState(() {
            _statusMsg =
                'Restored from Google Drive! (${preview?.transactionsCount} transactions, ${preview?.accountsCount} accounts)';
            _isError = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = e.toString();
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _driveRestoreLoading = false);
    }
  }

  // ─── Local / Share Backup & Restore ────────────────────────────────────────

  Future<void> _handleLocalBackup() async {
    final passwordCtrl = TextEditingController();
    bool usePassword = false;

    final shouldBackup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.file_download_rounded, color: AppColors.income, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Export .smartwallet File',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Creates a portable .smartwallet file to share via email, save to files, or transfer via USB.',
                style: TextStyle(fontSize: 12.5, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.darkCardAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: SwitchListTile(
                  title: const Text('Password Protect / Encrypt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Encrypts data with AES & PBKDF2', style: TextStyle(fontSize: 11)),
                  secondary: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                  value: usePassword,
                  onChanged: (v) => setSheetState(() => usePassword = v),
                ),
              ),
              if (usePassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Enter Password', prefixIcon: Icon(Icons.password_rounded)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Export & Share File', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldBackup == true) {
      setState(() {
        _localBackupLoading = true;
        _statusMsg = null;
      });
      try {
        final password = usePassword ? passwordCtrl.text.trim() : null;
        await BackupService.shareBackup(password: password);
        if (mounted) setState(() => _statusMsg = 'Backup file exported successfully!');
      } catch (e) {
        if (mounted) setState(() => _statusMsg = 'Export failed: $e');
      } finally {
        if (mounted) setState(() => _localBackupLoading = false);
      }
    }
  }

  Future<void> _handleLocalRestore() async {
    setState(() {
      _localRestoreLoading = true;
      _statusMsg = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        setState(() => _localRestoreLoading = false);
        return;
      }

      final file = File(result.files.first.path!);
      final inspection = await BackupService.inspectFile(file);

      String? password;
      if (inspection.isEncrypted) {
        final passCtrl = TextEditingController();
        if (!mounted) return;
        final passEntered = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Password Protected Backup'),
            content: TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.key_rounded)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Unlock')),
            ],
          ),
        );
        if (passEntered != true) {
          setState(() => _localRestoreLoading = false);
          return;
        }
        password = passCtrl.text.trim();
      }

      final preview = await BackupService.loadBackupPreview(file, password: password);
      if (!mounted) return;

      final proceed = await _showRestoreConfirmation(preview);
      if (proceed != null) {
        await BackupService.restoreDatabase(preview.rawData, replaceAll: proceed);
        refreshAllData(ref);

        if (mounted) {
          setState(() {
            _statusMsg =
                'Restored successfully! (${preview.transactionsCount} transactions, ${preview.accountsCount} accounts)';
            _isError = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = 'Restore failed: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _localRestoreLoading = false);
    }
  }

  Future<bool?> _showRestoreConfirmation(BackupPreviewInfo preview) async {
    bool replaceAll = true;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.restore_page_rounded, color: AppColors.income, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Restore Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Created on ${DateUtil.formatDateTime(preview.createdAt)} (${preview.userName} • Base: ${preview.currency})',
                style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCardAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _PreviewMetric(label: 'Accounts', value: '${preview.accountsCount}', icon: '💳'),
                        _PreviewMetric(label: 'Categories', value: '${preview.categoriesCount}', icon: '🏷️'),
                        _PreviewMetric(label: 'Transactions', value: '${preview.transactionsCount}', icon: '📜'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _PreviewMetric(label: 'Planned', value: '${preview.plannedCount}', icon: '📅'),
                        _PreviewMetric(label: 'Debts/Credits', value: '${preview.debtsCount}', icon: '🤝'),
                        _PreviewMetric(label: 'Templates', value: '${preview.templatesCount}', icon: '⚡'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text('Restore Option', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setModalState(() => replaceAll = true),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: replaceAll ? AppColors.primary.withValues(alpha: 0.15) : AppColors.darkCardAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: replaceAll ? AppColors.primary : Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        replaceAll ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: replaceAll ? AppColors.primary : Colors.white54,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Replace Everything (Recommended)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Replaces current local data with the backup snapshot. Ideal for switching phones.',
                                style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setModalState(() => replaceAll = false),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !replaceAll ? AppColors.primary.withValues(alpha: 0.15) : AppColors.darkCardAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: !replaceAll ? AppColors.primary : Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !replaceAll ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: !replaceAll ? AppColors.primary : Colors.white54,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Merge into Existing Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Appends items from the backup without deleting existing accounts or transactions.',
                                style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(bCtx, replaceAll),
                  child: const Text('Restore Database Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CSV Export & Import ───────────────────────────────────────────────────

  Future<void> _exportCSV() async {
    setState(() {
      _csvExportLoading = true;
      _statusMsg = null;
    });
    try {
      final transactions = ref.read(transactionsProvider);
      final accounts = ref.read(accountsProvider);
      final categories = ref.read(categoriesProvider);

      final rows = <List<dynamic>>[
        ['ID', 'Type', 'Amount', 'Account', 'To Account', 'Category', 'Date', 'Note'],
      ];

      for (final t in transactions) {
        final acc = accounts.firstWhereOrNull((a) => a.id == t.accountId);
        final toAcc = t.toAccountId != null ? accounts.firstWhereOrNull((a) => a.id == t.toAccountId) : null;
        final cat = categories.firstWhereOrNull((c) => c.id == t.categoryId);
        rows.add([
          t.id,
          t.type,
          t.amount.toString(),
          acc?.name ?? '',
          toAcc?.name ?? '',
          cat?.name ?? '',
          DateUtil.formatDateTime(t.date),
          t.note,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/smart_wallet_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Smart Wallet CSV Export',
          text: 'Smart Wallet CSV Export',
        ),
      );
      if (mounted) setState(() => _statusMsg = 'Exported ${transactions.length} transactions to CSV!');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _csvExportLoading = false);
    }
  }

  Future<void> _importCSV() async {
    setState(() {
      _csvImportLoading = true;
      _statusMsg = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        setState(() => _csvImportLoading = false);
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content, eol: '\n');

      if (rows.isEmpty || rows.length < 2) {
        setState(() => _statusMsg = 'CSV is empty or invalid.');
        return;
      }

      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import Preview'),
          content: Text('Found ${dataRows.length} transactions. Import will add them to your first account.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _csvImportLoading = false);
        return;
      }

      final typeIdx = headers.indexWhere((h) => h.toLowerCase() == 'type');
      final amtIdx = headers.indexWhere((h) => h.toLowerCase() == 'amount');
      final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
      final noteIdx = headers.indexWhere((h) => h.toLowerCase() == 'note');

      final accounts = ref.read(accountsProvider);
      int imported = 0;

      for (final row in dataRows) {
        try {
          final type = typeIdx >= 0 ? row[typeIdx].toString() : 'expense';
          final amount = amtIdx >= 0 ? (double.tryParse(row[amtIdx].toString()) ?? 0.0) : 0.0;
          final date = dateIdx >= 0 ? DateTime.tryParse(row[dateIdx].toString()) ?? DateTime.now() : DateTime.now();
          final note = noteIdx >= 0 ? row[noteIdx].toString() : '';

          if (amount <= 0 || accounts.isEmpty) continue;

          final txn = Transaction(
            id: '',
            type: ['income', 'expense', 'transfer'].contains(type) ? type : 'expense',
            amount: amount,
            accountId: accounts.first.id,
            date: date,
            note: note,
          );
          await ref.read(transactionsProvider.notifier).add(txn);
          imported++;
        } catch (_) {}
      }

      if (mounted) setState(() => _statusMsg = 'Imported $imported transactions from CSV!');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'CSV Import failed: $e');
    } finally {
      if (mounted) setState(() => _csvImportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudTime = _lastCloudBackupTime;
    final localTime = _lastLocalBackupTime;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Backup & Cloud Sync'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cloud Status Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    const Color(0xFF1E1E28),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Google Drive Serverless Sync',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cloudTime != null
                              ? 'Google Drive synced: $cloudTime'
                              : (localTime != null ? 'Local backup: $localTime' : 'No cloud backup yet'),
                          style: TextStyle(
                            fontSize: 12,
                            color: cloudTime != null ? AppColors.income : AppColors.darkTextSecondary,
                            fontWeight: cloudTime != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // SECTION 1: Google Drive Sync
            const _SectionHeader(
              title: 'Google Drive Sync (Serverless & Private)',
              icon: Icons.add_to_drive_rounded,
            ),
            const SizedBox(height: 10),

            _ActionCard(
              icon: Icons.cloud_upload_rounded,
              iconColor: AppColors.primary,
              title: '1-Tap Backup to Google Drive',
              description:
                  'Silently uploads an encrypted snapshot into your hidden Google Drive AppData folder. No server needed.',
              buttonLabel: 'Backup to Google Drive',
              loading: _driveBackupLoading,
              onTap: _handleGoogleDriveBackup,
            ),
            const SizedBox(height: 14),

            _ActionCard(
              icon: Icons.cloud_download_rounded,
              iconColor: AppColors.income,
              title: 'Restore from Google Drive',
              description:
                  'Downloads and restores your cloud backup on any new phone or after reinstalling.',
              buttonLabel: 'Restore from Google Drive',
              loading: _driveRestoreLoading,
              onTap: _handleGoogleDriveRestore,
            ),
            const SizedBox(height: 28),

            // SECTION 2: Local File Backup
            const _SectionHeader(
              title: 'Local / Offline File Backup (.smartwallet)',
              icon: Icons.folder_zip_rounded,
            ),
            const SizedBox(height: 10),

            _ActionCard(
              icon: Icons.share_rounded,
              iconColor: AppColors.accent,
              title: 'Export .smartwallet File',
              description: 'Save encrypted backup file to device files or share via email / messaging apps.',
              buttonLabel: 'Export File',
              loading: _localBackupLoading,
              onTap: _handleLocalBackup,
            ),
            const SizedBox(height: 14),

            _ActionCard(
              icon: Icons.restore_page_rounded,
              iconColor: AppColors.transfer,
              title: 'Restore from Local File',
              description: 'Select a previously exported .smartwallet file to restore database.',
              buttonLabel: 'Pick & Restore File',
              loading: _localRestoreLoading,
              onTap: _handleLocalRestore,
            ),
            const SizedBox(height: 28),

            // SECTION 3: CSV Tools
            const _SectionHeader(
              title: 'Spreadsheet Export & Import (CSV)',
              icon: Icons.table_chart_outlined,
            ),
            const SizedBox(height: 10),

            _ActionCard(
              icon: Icons.upload_file_rounded,
              iconColor: AppColors.accent,
              title: 'Export Transactions to CSV',
              description: 'Export all records into CSV format for Excel or Google Sheets.',
              buttonLabel: 'Export CSV',
              loading: _csvExportLoading,
              onTap: _exportCSV,
            ),
            const SizedBox(height: 14),

            _ActionCard(
              icon: Icons.download_rounded,
              iconColor: AppColors.transfer,
              title: 'Import Transactions from CSV',
              description: 'Import transaction records from a CSV file.',
              buttonLabel: 'Import CSV',
              loading: _csvImportLoading,
              onTap: _importCSV,
            ),

            if (_statusMsg != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_isError ? AppColors.expense : AppColors.income).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (_isError ? AppColors.expense : AppColors.income).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      color: _isError ? AppColors.expense : AppColors.income,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMsg!,
                        style: TextStyle(
                          color: _isError ? AppColors.expense : AppColors.income,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  const _PreviewMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.darkTextSecondary)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final bool loading;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: loading ? null : onTap,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
