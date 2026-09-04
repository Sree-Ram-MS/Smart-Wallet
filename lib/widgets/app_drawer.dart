import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import 'user_avatar.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDark = user?.isDarkMode ?? true;
    final currency = user?.baseCurrency ?? 'INR';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar on left, Theme toggle on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/settings');
                        },
                        child: UserAvatar(user: user, radius: 28),
                      ),
                      // Dark/Light toggle
                      GestureDetector(
                        onTap: () => ref.read(userProvider.notifier).toggleDarkMode(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 58,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isDark
                                ? const Color(0xFF26283D)
                                : AppColors.lightBorder,
                            border: Border.all(
                              color: isDark ? const Color(0xFF383C5A) : AppColors.lightBorder,
                            ),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            alignment: isDark
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.primary : AppColors.lightTextSecondary,
                              ),
                              child: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Bottom Row: Name & Email on left, Currency Pill on right (parallel)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Guest User',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.email ?? 'guest@smartwallet.app',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Currency Badge aligned with Name & Email
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showCurrencyPicker(context, ref, currency),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF26283D) : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF383C5A) : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$currency ${CurrencyUtil.symbol(currency)}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFB0B8E8) : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: isDark ? const Color(0xFFB0B8E8) : AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user?.isGuest == true) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/settings');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_sync_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Guest Mode • Tap to Connect Account',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
                  _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Manage Accounts', route: '/manage-accounts'),
                  _NavItem(icon: Icons.receipt_long_rounded, label: 'Transaction History', route: '/transactions'),
                  _NavItem(icon: Icons.arrow_upward_rounded, label: 'Debts (I Lent)', route: '/debts'),
                  _NavItem(icon: Icons.arrow_downward_rounded, label: 'Credits (I Borrowed)', route: '/credits'),
                  _NavItem(icon: Icons.call_split_rounded, label: 'Split Bills / Expenses', route: '/split-bills'),
                  _NavItem(icon: Icons.calendar_month_rounded, label: 'Planned Payments', route: '/planned'),
                  _NavItem(icon: Icons.tune_rounded, label: 'Config / Categories', route: '/config'),
                  _NavItem(icon: Icons.bookmark_rounded, label: 'Templates', route: '/templates'),
                  _NavItem(icon: Icons.cloud_sync_rounded, label: 'Backup & Restore', route: '/import-export'),
                  _NavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),

                  const Divider(height: 24),

                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.expense),
                    title: Text('Sign Out',
                        style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Sign Out',
                                    style: TextStyle(color: AppColors.expense))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await AuthService.signOut();
                        ref.read(userProvider.notifier).clearUser();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select Base Currency',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: CurrencyUtil.supportedCurrencies.map((c) {
                  final isSelected = c == current;
                  return ListTile(
                    leading: Text(
                      CurrencyUtil.symbol(c),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    title: Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(userProvider.notifier).setBaseCurrency(c);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.toString();
    final selected = current == route;
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppColors.primary : null, size: 22),
      title: Text(label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : null,
          )),
      selected: selected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
