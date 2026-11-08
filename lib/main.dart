import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
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

  // Set preferred orientations (no-op in browsers)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Hive (IndexedDB on web)
  await HiveService.init();

  final user = HiveService.getUser();

  if (kIsWeb) {
    // Google Identity Services keeps no session across page loads.
    AuthService.initWeb();
  } else {
    // Notifications & Home Widget are Android/iOS only.
    await NotificationService.init();
    await WidgetService.init();
    final planned = HiveService.getPlanned();
    await NotificationService.syncAllNotifications(user: user, payments: planned);
  }

  if (!kIsWeb && user != null) {
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

  // Google Drive sync (pull newer Drive data, auto-upload changes). Started
  // after the first frame so its dialogs have a navigator. With the biometric
  // lock on, the lock screen starts it after a successful unlock.
  if (kIsWeb || user == null || !user.biometricEnabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(CloudSyncService.instance.start());
    });
  }
}
