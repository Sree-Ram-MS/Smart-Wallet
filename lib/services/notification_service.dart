import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/models.dart';
import '../core/utils/utils.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const int _dailyReminderNotificationId = 100;
  static const String _channelId = 'smart_wallet_channel_v3';
  static const String _channelName = 'Smart Wallet Reminders';
  static const String _channelDescription =
      'Notifications for daily transaction logging and upcoming payment alerts';

  /// Initialize local notification plugin and configure timezones
  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      const androidSettings =
          AndroidInitializationSettings('ic_notification');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open notification');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Create notification channel and request permissions on Android
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidImpl?.deleteNotificationChannel(channelId: 'smart_wallet_channel');
        await androidImpl?.deleteNotificationChannel(channelId: 'smart_wallet_channel_v2');

        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('wallet_tone'),
          enableVibration: true,
        );
        await androidImpl?.createNotificationChannel(channel);
        await androidImpl?.requestNotificationsPermission();
        await androidImpl?.requestExactAlarmsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  static void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final timeZoneName = now.timeZoneName;

      // 1. Try matching the exact timezone name
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('Detected timezone by name: $timeZoneName');
        return;
      }

      // 2. Try common timezone alias mappings
      const aliasMap = {
        'IST': 'Asia/Kolkata',
        'EST': 'America/New_York',
        'EDT': 'America/New_York',
        'CST': 'America/Chicago',
        'CDT': 'America/Chicago',
        'MST': 'America/Denver',
        'MDT': 'America/Denver',
        'PST': 'America/Los_Angeles',
        'PDT': 'America/Los_Angeles',
        'GMT': 'UTC',
        'UTC': 'UTC',
        'BST': 'Europe/London',
        'CET': 'Europe/Paris',
        'CEST': 'Europe/Paris',
        'JST': 'Asia/Tokyo',
        'SGT': 'Asia/Singapore',
        'AEST': 'Australia/Sydney',
        'AEDT': 'Australia/Sydney',
      };

      if (aliasMap.containsKey(timeZoneName)) {
        final locName = aliasMap[timeZoneName]!;
        if (tz.timeZoneDatabase.locations.containsKey(locName)) {
          tz.setLocalLocation(tz.getLocation(locName));
          debugPrint('Detected timezone by alias: $timeZoneName -> $locName');
          return;
        }
      }

      // 3. Fallback: match by UTC offset
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == now.timeZoneOffset) {
          tz.setLocalLocation(loc);
          debugPrint('Detected timezone by offset (${now.timeZoneOffset}): ${loc.name}');
          return;
        }
      }
    } catch (e) {
      debugPrint('Error detecting local timezone: $e');
    }
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('wallet_tone'),
      enableVibration: true,
      icon: 'ic_notification',
      color: Color(0xFF0085FA),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Show an instant notification (e.g. for testing)
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    try {
      await _notifications.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: _notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Schedule recurring daily transaction reminder at a given hour and minute
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await init();
    try {
      await cancelDailyReminder();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time for today has already passed, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        id: _dailyReminderNotificationId,
        title: 'Update Your Daily Transactions 📝',
        body: "Don't forget to record today's income, expenses and wallet activity!",
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder',
      );
      debugPrint('Daily reminder scheduled for: $scheduledDate (Timezone: ${tz.local.name})');
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  /// Cancel the daily transaction reminder
  static Future<void> cancelDailyReminder() async {
    try {
      await _notifications.cancel(id: _dailyReminderNotificationId);
    } catch (e) {
      debugPrint('Error cancelling daily reminder: $e');
    }
  }

  /// Schedule upcoming planned payment reminders
  static Future<void> schedulePlannedPaymentReminders(
    List<PlannedPayment> payments,
    int daysBefore, {
    bool enabled = true,
  }) async {
    await init();
    if (!enabled) {
      for (int i = 200; i < 500; i++) {
        try {
          await _notifications.cancel(id: i);
        } catch (_) {}
      }
      return;
    }

    try {
      final now = DateTime.now();
      int idCounter = 200;

      for (final p in payments) {
        if (p.isCompleted) continue;

        final reminderDate = p.nextDueDate.subtract(Duration(days: daysBefore));
        final scheduledTarget = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          9,
          0,
        );

        if (scheduledTarget.isAfter(now)) {
          final tzScheduled = tz.TZDateTime.from(scheduledTarget, tz.local);
          final daysText = daysBefore == 0
              ? 'today'
              : daysBefore == 1
                  ? 'tomorrow'
                  : 'in $daysBefore days';

          await _notifications.zonedSchedule(
            id: idCounter,
            title: 'Upcoming Payment Due: ${p.name} ⏰',
            body:
                'Your payment of ${CurrencyUtil.format(p.amount, '')} is due $daysText (${DateUtil.formatDate(p.nextDueDate)}).',
            scheduledDate: tzScheduled,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'planned_${p.id}',
          );
          idCounter++;
          if (idCounter > 500) break;
        }
      }
    } catch (e) {
      debugPrint('Error scheduling planned payment reminders: $e');
    }
  }

  /// Sync all notifications with user profile settings and current planned payments
  static Future<void> syncAllNotifications({
    required UserProfile? user,
    required List<PlannedPayment> payments,
  }) async {
    if (user == null) return;
    await init();

    if (user.dailyReminderEnabled) {
      await scheduleDailyReminder(
        hour: user.dailyReminderHour,
        minute: user.dailyReminderMinute,
      );
    } else {
      await cancelDailyReminder();
    }

    if (user.plannedReminderEnabled) {
      await schedulePlannedPaymentReminders(
        payments,
        user.plannedReminderDaysBefore,
        enabled: true,
      );
    } else {
      await schedulePlannedPaymentReminders(
        payments,
        user.plannedReminderDaysBefore,
        enabled: false,
      );
    }
  }
}
