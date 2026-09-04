import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../providers/providers.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/user_avatar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${appDir.path}/profile_photos');
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      final ext = picked.path.split('.').last;
      final targetPath = '${photoDir.path}/profile_${const Uuid().v4()}.$ext';
      await File(picked.path).copy(targetPath);

      final user = ref.read(userProvider);
      if (user != null) {
        final updated = user.copyWith(photoUrl: targetPath);
        await ref.read(userProvider.notifier).updateUser(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: AppColors.darkCard,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile photo: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final user = ref.read(userProvider);
    if (user != null) {
      final updated = user.copyWith(photoUrl: '');
      await ref.read(userProvider.notifier).updateUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed.'),
            backgroundColor: AppColors.darkCard,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    final user = ref.read(userProvider);
    final hasPhoto = user?.photoUrl.isNotEmpty == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile Photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfilePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfilePhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.expense)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox();

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
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Guest Account Connection Banner
            if (user.isGuest) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      const Color(0xFF1E1E28),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_sync_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connect Google Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Logged in as Guest User',
                                style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Link your Google account to keep your identity and profile updated. All your existing accounts, categories, and transactions will remain completely safe and untouched.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Connect with Google', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await ref.read(userProvider.notifier).connectGoogleAccount();
                          if (success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Google account connected successfully!'),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to connect Google account. Please try again.'),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Profile section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Profile', style: Theme.of(context).textTheme.titleMedium),
                        TextButton.icon(
                          onPressed: _showPhotoOptions,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: Text(
                            user.photoUrl.isNotEmpty ? 'Change Photo' : 'Upload Photo',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: UserAvatar(
                        user: user,
                        radius: 46,
                        showEditBadge: true,
                        onEdit: _showPhotoOptions,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_rounded, color: AppColors.primary),
                          onPressed: () async {
                            final updated = user.copyWith(name: _nameCtrl.text.trim());
                            await ref.read(userProvider.notifier).updateUser(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Display name saved!')),
                              );
                            }
                          },
                        ),
                      ),
                      onSubmitted: (v) async {
                        final updated = user.copyWith(name: v.trim());
                        await ref.read(userProvider.notifier).updateUser(updated);
                      },
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Email'),
                      child: Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Preferences
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),

                    // Base currency
                    DropdownButtonFormField<String>(
                      initialValue: user.baseCurrency,
                      items: CurrencyUtil.supportedCurrencies
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('$c  ${CurrencyUtil.symbol(c)}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) ref.read(userProvider.notifier).setBaseCurrency(v);
                      },
                      decoration: const InputDecoration(labelText: 'Base Currency'),
                      dropdownColor: AppColors.darkCard,
                    ),
                    const SizedBox(height: 16),

                    // Dark mode
                    SwitchListTile(
                      value: user.isDarkMode,
                      onChanged: (_) async {
                        await ref.read(userProvider.notifier).toggleDarkMode();
                      },
                      title: const Text('Dark Mode'),
                      secondary: const Icon(Icons.dark_mode_rounded),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: AppColors.darkCardAlt,
                    ),
                    const SizedBox(height: 8),

                    // Biometric
                    SwitchListTile(
                      value: user.biometricEnabled,
                      onChanged: (v) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref.read(userProvider.notifier).toggleBiometric();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(v
                                ? 'Biometric App Lock enabled! You will be asked on next launch.'
                                : 'Biometric App Lock disabled.'),
                          ),
                        );
                      },
                      title: const Text('Biometric App Lock'),
                      subtitle: const Text('Face ID / Touch ID / Fingerprint / PIN'),
                      secondary: const Icon(Icons.fingerprint_rounded),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: AppColors.darkCardAlt,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Notifications & Reminders
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Notifications & Reminders', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Daily Update Transaction Reminder Switch
                    SwitchListTile(
                      value: user.dailyReminderEnabled,
                      onChanged: (v) async {
                        await ref.read(userProvider.notifier).setDailyReminder(enabled: v);
                      },
                      title: const Text('Daily Transaction Reminder'),
                      subtitle: const Text('Reminds you to log daily income & expenses'),
                      secondary: const Icon(Icons.alarm_rounded),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: AppColors.darkCardAlt,
                    ),
                    if (user.dailyReminderEnabled) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: AppColors.darkCardAlt.withValues(alpha: 0.6),
                        leading: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                        title: const Text('Reminder Time', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          TimeOfDay(hour: user.dailyReminderHour, minute: user.dailyReminderMinute)
                              .format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        trailing: const Text('Tap to change', style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: user.dailyReminderHour,
                              minute: user.dailyReminderMinute,
                            ),
                          );
                          if (picked != null) {
                            await ref.read(userProvider.notifier).setDailyReminder(
                                  enabled: true,
                                  hour: picked.hour,
                                  minute: picked.minute,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Daily reminder set to ${picked.format(context)}',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Upcoming Planned Payment Alert Switch
                    SwitchListTile(
                      value: user.plannedReminderEnabled,
                      onChanged: (v) async {
                        await ref.read(userProvider.notifier).setPlannedReminder(enabled: v);
                      },
                      title: const Text('Upcoming Payment Alerts'),
                      subtitle: const Text('Reminds you before bills & EMIs are due'),
                      secondary: const Icon(Icons.event_note_rounded),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: AppColors.darkCardAlt,
                    ),
                    if (user.plannedReminderEnabled) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DropdownButtonFormField<int>(
                          initialValue: user.plannedReminderDaysBefore,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('On Due Date (Same day)')),
                            DropdownMenuItem(value: 1, child: Text('1 Day Before')),
                            DropdownMenuItem(value: 2, child: Text('2 Days Before (Recommended)')),
                            DropdownMenuItem(value: 3, child: Text('3 Days Before')),
                            DropdownMenuItem(value: 5, child: Text('5 Days Before')),
                            DropdownMenuItem(value: 7, child: Text('1 Week Before')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(userProvider.notifier).setPlannedReminder(
                                    enabled: true,
                                    daysBefore: v,
                                  );
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Remind in Advance',
                            prefixIcon: Icon(Icons.timelapse_rounded),
                          ),
                          dropdownColor: AppColors.darkCard,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Send Test Notification button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Send Test Notification'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await NotificationService.showInstantNotification(
                            title: 'Smart Wallet Reminder 🔔',
                            body: 'This is a test notification. Your daily reminders & payment alerts are working!',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test notification sent! Check your notification tray.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Data & Backup Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Data & Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1-Tap Backup to Google Drive, export encrypted .smartwallet files, or import/export CSV transactions.',
                      style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.backup_rounded),
                        label: const Text('Manage Backup & Restore'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => context.go('/import-export'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final updated = user;
                  updated.name = _nameCtrl.text;
                  await ref.read(userProvider.notifier).updateUser(updated);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Settings saved!')),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
