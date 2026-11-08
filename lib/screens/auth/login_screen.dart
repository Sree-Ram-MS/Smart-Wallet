import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/layout/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/google_web_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  StreamSubscription? _webAuthSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web: the GIS button / One Tap report the user through this stream.
      _webAuthSub = AuthService.googleSignIn.onCurrentUserChanged.listen((account) async {
        if (account == null || !mounted) return;
        final user = await AuthService.saveWebAccount(account);
        if (!mounted) return;
        await ref.read(userProvider.notifier).setUser(user);
        if (mounted) context.go('/dashboard');
        unawaited(CloudSyncService.instance.start());
      });
    }
  }

  @override
  void dispose() {
    _webAuthSub?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null && mounted) {
        ref.read(userProvider.notifier).setUser(user);
        context.go('/dashboard');
        unawaited(CloudSyncService.instance.start());
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInAsGuest();
      ref.read(userProvider.notifier).setUser(user);
      if (mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Logo, name and tagline.
    final brand = <Widget>[
      // Logo
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
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.account_balance_wallet_rounded,
            size: 48, color: Colors.white),
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.7, 0.7)),

      const SizedBox(height: 28),

      Text(
        'Smart Wallet',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.darkText,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
      ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3),

      const SizedBox(height: 8),

      Text(
        'Your personal finance companion',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.darkTextSecondary,
            ),
        textAlign: TextAlign.center,
      ).animate().fadeIn(delay: 350.ms, duration: 600.ms),
    ];

    final features = <Widget>[
      // Feature highlights
      ...[
        ('💳', 'Multiple Accounts'),
        ('📊', 'Spending Charts'),
        kIsWeb ? ('☁️', 'Google Drive Sync') : ('🔒', 'Biometric Lock'),
      ].asMap().entries.map((e) {
        final delay = 400 + e.key * 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Center(
                  child: Text(e.value.$1, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                e.value.$2,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.darkText,
                    ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms)
            .slideX(begin: -0.2);
      }),
    ];

    // Sign-in buttons and footnote.
    final actions = <Widget>[
      // Google Sign In (web: official GIS button)
      if (kIsWeb)
        SizedBox(
          height: 56,
          child: Center(child: buildGoogleWebButton()),
        ).animate().fadeIn(delay: 700.ms, duration: 500.ms)
      else
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _loading ? null : _signInWithGoogle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.google.com/favicon.ico',
                      width: 22,
                      height: 22,
                      errorBuilder: (ctx, err, stack) =>
                          const Icon(Icons.g_mobiledata, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.3),

      const SizedBox(height: 16),

      // Guest button
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: _loading ? null : _signInAsGuest,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkTextSecondary,
            side: BorderSide(color: AppColors.darkBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Continue as Guest', style: TextStyle(fontSize: 15)),
        ),
      ).animate().fadeIn(delay: 800.ms, duration: 500.ms),

      const SizedBox(height: 12),
      Text(
        kIsWeb
            ? 'Sign in with Google to sync with your phone via Google Drive'
            : 'All data stored locally on your device',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.darkTextMuted),
      ).animate().fadeIn(delay: 900.ms),
    ];

    if (context.isWide) {
      return _WideLogin(brand: brand, features: features, actions: actions);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accent.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.1),

                  ...brand,

                  SizedBox(height: size.height * 0.08),

                  ...features,

                  const Spacer(),

                  ...actions,
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide-screen login: branding on the left, sign-in card on the right.
class _WideLogin extends StatelessWidget {
  final List<Widget> brand;
  final List<Widget> features;
  final List<Widget> actions;

  const _WideLogin({
    required this.brand,
    required this.features,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -160,
            left: -120,
            child: Container(
              width: 620,
              height: 620,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.30), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accent.withValues(alpha: 0.20), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...brand,
                            const SizedBox(height: 40),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Column(children: features),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 56),
                      Container(
                        width: 420,
                        padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.darkBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Welcome',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: AppColors.darkText,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to get started',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.darkTextSecondary,
                                  ),
                            ),
                            const SizedBox(height: 28),
                            ...actions,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
