import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/layout/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../providers/providers.dart';
import '../../core/router/app_router.dart';
import '../../services/auth_service.dart';
import 'user_avatar.dart';

/// One navigation destination, shared by the drawer and the wide sidebar.
class AppNavDestination {
  final IconData icon;
  final String label;
  final String route;
  const AppNavDestination(this.icon, this.label, this.route);
}

const appNavDestinations = <AppNavDestination>[
  AppNavDestination(Icons.dashboard_rounded, 'Dashboard', '/dashboard'),
  AppNavDestination(Icons.account_balance_wallet_rounded, 'Manage Accounts', '/manage-accounts'),
  AppNavDestination(Icons.receipt_long_rounded, 'Transaction History', '/transactions'),
  AppNavDestination(Icons.arrow_upward_rounded, 'Debts (I Lent)', '/debts'),
  AppNavDestination(Icons.arrow_downward_rounded, 'Credits (I Borrowed)', '/credits'),
  AppNavDestination(Icons.call_split_rounded, 'Split Bills / Expenses', '/split-bills'),
  AppNavDestination(Icons.calendar_month_rounded, 'Planned Payments', '/planned'),
  AppNavDestination(Icons.tune_rounded, 'Config / Categories', '/config'),
  AppNavDestination(Icons.bookmark_rounded, 'Templates', '/templates'),
  AppNavDestination(Icons.cloud_sync_rounded, 'Backup & Restore', '/import-export'),
  AppNavDestination(Icons.settings_rounded, 'Settings', '/settings'),
];

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
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
}

/// The phone navigation drawer.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      child: SafeArea(child: AppNavigationPanel()),
    );
  }
}

/// Drawer contents: profile header, destinations and sign out. Used inside the
/// phone drawer and, on wide screens, as the extended sidebar.
class AppNavigationPanel extends ConsumerWidget {
  /// Current route when used outside a drawer (sidebar). In the drawer the
  /// route is read from GoRouterState.
  final String? currentLocation;

  const AppNavigationPanel({super.key, this.currentLocation});

  bool get _inDrawer => currentLocation == null;

  void _closeDrawer(BuildContext context) {
    if (_inDrawer) Navigator.pop(context);
  }

  /// The sidebar sits above the app Navigator (MaterialApp.router builder),
  /// so dialogs and navigation from it go through the root navigator.
  BuildContext _navContext(BuildContext context) =>
      _inDrawer ? context : (rootNavigatorKey.currentContext ?? context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDark = user?.isDarkMode ?? true;
    final currency = user?.baseCurrency ?? 'INR';

    return Column(
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
                          _closeDrawer(context);
                          _navContext(context).go('/settings');
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
                        onTap: () => _showCurrencyPicker(_navContext(context), ref, currency),
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
                        _closeDrawer(context);
                        _navContext(context).go('/settings');
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
                  for (final d in appNavDestinations)
                    _NavItem(
                      icon: d.icon,
                      label: d.label,
                      route: d.route,
                      currentLocation: currentLocation,
                    ),

                  const Divider(height: 24),

                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.expense),
                    title: Text('Sign Out',
                        style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () => confirmAndSignOut(_navContext(context), ref),
                  ),
                ],
              ),
            ),
          ],
        );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, String current) {
    showAppSheet(
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
  final String? currentLocation;
  const _NavItem({required this.icon, required this.label, required this.route, this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final current = currentLocation ?? GoRouterState.of(context).uri.toString();
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
        if (currentLocation == null) {
          Navigator.pop(context);
          context.go(route);
        } else {
          (rootNavigatorKey.currentContext ?? context).go(route);
        }
      },
    );
  }
}
