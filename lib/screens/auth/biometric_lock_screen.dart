import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/biometric_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/auth_service.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});
  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _authenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() { _authenticating = true; _failed = false; });
    final ok = await BiometricService.authenticate();
    if (mounted) {
      if (ok) {
        context.go('/dashboard');
        CloudSyncService.instance.start();
      } else {
        setState(() { _authenticating = false; _failed = true; });
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    ref.read(userProvider.notifier).clearUser();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24),
                  ],
                ),
                child: const Icon(Icons.lock_rounded, size: 44, color: Colors.white),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 32),
              Text(
                'App Locked',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.darkText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use biometrics or PIN to continue',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              if (_authenticating)
                const CircularProgressIndicator(color: AppColors.primary)
              else ...[
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Authentication failed. Try again.',
                      style: TextStyle(color: AppColors.expense),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Authenticate'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _signOut,
                  child: Text('Sign Out', style: TextStyle(color: AppColors.darkTextSecondary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
