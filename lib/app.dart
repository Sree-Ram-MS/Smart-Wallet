import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'widgets/add_transaction_sheet.dart';

class SmartWalletApp extends ConsumerStatefulWidget {
  const SmartWalletApp({super.key});

  @override
  ConsumerState<SmartWalletApp> createState() => _SmartWalletAppState();
}

class _SmartWalletAppState extends ConsumerState<SmartWalletApp> {
  @override
  void initState() {
    super.initState();
    _handleWidgetLaunch();
  }

  void _handleWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_processUri);
    HomeWidget.widgetClicked.listen(_processUri);
  }

  void _processUri(Uri? uri) {
    if (uri == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null) return;

      if (uri.host == 'quick-add') {
        final type = uri.queryParameters['type'] ?? 'expense';
        final isSplit = type == 'split';
        showModalBottomSheet(
          context: navCtx,
          isScrollControlled: true,
          builder: (_) => AddTransactionSheet(
            ref: ref,
            initialType: isSplit ? 'expense' : type,
            initialSplit: isSplit,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isDark = user?.isDarkMode ?? true;

    return MaterialApp.router(
      title: 'Smart Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
