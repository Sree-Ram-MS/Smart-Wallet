import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/biometric_lock_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/account/manage_accounts_screen.dart';
import '../../screens/transactions/transaction_history_screen.dart';
import '../../screens/planned_payments/planned_payments_screen.dart';
import '../../screens/debts/debts_screen.dart';
import '../../screens/config/config_screen.dart';
import '../../screens/templates/templates_screen.dart';
import '../../screens/import_export/import_export_screen.dart';
import '../../screens/splits/split_bills_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../services/auth_service.dart';
import '../../services/hive_service.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// URLs: Flutter web uses hash URLs (/#/dashboard) by default, which is what we
// want on GitHub Pages: a page refresh always loads index.html. Don't call
// usePathUrlStrategy() unless the host rewrites unknown paths to index.html.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: _getInitialRoute(),
  routes: [
    GoRoute(path: '/login', builder: (ctx, s) => const LoginScreen()),
    GoRoute(path: '/biometric', builder: (ctx, s) => const BiometricLockScreen()),
    GoRoute(path: '/dashboard', builder: (ctx, s) => const DashboardScreen()),
    GoRoute(path: '/manage-accounts', builder: (ctx, s) => const ManageAccountsScreen()),
    GoRoute(path: '/transactions', builder: (ctx, s) => const TransactionHistoryScreen()),
    GoRoute(path: '/planned', builder: (ctx, s) => const PlannedPaymentsScreen()),
    GoRoute(path: '/split-bills', builder: (ctx, s) => const SplitBillsScreen()),
    GoRoute(path: '/debts', builder: (ctx, s) => const DebtsScreen()),
    GoRoute(path: '/credits', builder: (ctx, s) => const CreditsScreen()),
    GoRoute(path: '/config', builder: (ctx, s) => const ConfigScreen()),
    GoRoute(path: '/templates', builder: (ctx, s) => const TemplatesScreen()),
    GoRoute(path: '/import-export', builder: (ctx, s) => const ImportExportScreen()),
    GoRoute(path: '/settings', builder: (ctx, s) => const SettingsScreen()),
  ],
);

String _getInitialRoute() {
  if (!AuthService.isLoggedIn) return '/login';
  final user = HiveService.getUser();
  // Biometric lock is a device feature (local_auth); not available on web.
  if (!kIsWeb && user != null && user.biometricEnabled) return '/biometric';
  return '/dashboard';
}
