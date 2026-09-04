import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Hive
  await HiveService.init();

  // Initialize Notifications & Home Widget
  await NotificationService.init();
  await WidgetService.init();
  final user = HiveService.getUser();
  final planned = HiveService.getPlanned();
  await NotificationService.syncAllNotifications(user: user, payments: planned);

  if (user != null) {
    final netWallet = HiveService.getNetWallet();
    await WidgetService.updateWidgetData(
      netBalance: netWallet,
      currency: user.baseCurrency,
    );
  }

  runApp(
    const ProviderScope(
      child: SmartWalletApp(),
    ),
  );
}
