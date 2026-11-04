package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * Phase 3: local reminder scheduling, mirroring the Flutter
 * NotificationService rules (lib/services/notification_service.dart):
 *
 *  - Channel "smart_wallet_channel_v3" / "Smart Wallet Reminders".
 *  - Daily reminder: notification id 100, fires every day at the
 *    profile's hour:minute (next occurrence today, else tomorrow),
 *    title "Update Your Daily Transactions 📝".
 *  - Planned reminders: ids 200..499, one per non-completed planned
 *    payment, at 09:00 on (due date − plannedReminderDaysBefore),
 *    only when that moment is still in the future.
 *  - Exact alarms when the system allows them; otherwise an inexact
 *    setAndAllowWhileIdle fallback (never a crash).
 *
 * Differences from Flutter, deliberately: Flutter re-schedules the
 * daily alarm with matchDateTimeComponents (a repeating system
 * alarm); native schedules one shot and the receiver re-runs sync()
 * after it fires, which chains the next day. Flutter also never
 * cancels stale planned ids above its current counter when
 * re-syncing while enabled; native cancels the whole 200..499 window
 * before scheduling, so deleted/edited payments can't leave ghost
 * reminders. Titles/bodies match Flutter's wording.
 *
 * sync() is called on app start, after every planned-payment change,
 * after reminder-settings changes, and from BootReceiver.
 */
public final class NotifService {

    public static final String CHANNEL_ID = "smart_wallet_channel_v3";
    public static final String CHANNEL_NAME = "Smart Wallet Reminders";

    static final int DAILY_ID = 100;
    static final int PLANNED_FIRST = 200;
    static final int PLANNED_LAST = 499;

    static final String EXTRA_ID = "notif_id";
    static final String EXTRA_TITLE = "notif_title";
    static final String EXTRA_BODY = "notif_body";

    private NotifService() {}

    public static void ensureChannel(Context ctx) {
        NotificationManager nm = (NotificationManager)
                ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            NotificationChannel ch = new NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription(
                    "Notifications for daily transaction logging and upcoming payment alerts");
            ch.enableVibration(true);
            nm.createNotificationChannel(ch);
        }
    }

    /** Android 13+ runtime notification permission. */
    public static void requestPermission(Activity act) {
        if (Build.VERSION.SDK_INT >= 33
                && act.checkSelfPermission("android.permission.POST_NOTIFICATIONS")
                        != PackageManager.PERMISSION_GRANTED) {
            act.requestPermissions(
                    new String[]{"android.permission.POST_NOTIFICATIONS"}, 7001);
        }
    }

    /** True when exact alarms are usable right now (always true < API 31). */
    public static boolean canScheduleExact(Context ctx) {
        if (Build.VERSION.SDK_INT < 31) return true;
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        return am != null && am.canScheduleExactAlarms();
    }

    /** Recompute every reminder from the stored profile + planned payments. */
    public static void sync(Context ctx) {
        try {
            ensureChannel(ctx);
            AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
            NotificationManager nm = (NotificationManager)
                    ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (am == null) return;

            Store store = new Store(ctx);
            WalletDb db = store.load();
            UserProfile user = db.user != null ? db.user : defaultUser();
            LocalDateTime now = LocalDateTime.now();

            // Clear the planned window so no ghost reminders survive.
            for (int id = PLANNED_FIRST; id <= PLANNED_LAST; id++) {
                am.cancel(pendingIntent(ctx, id, "", ""));
                if (nm != null) nm.cancel(id);
            }

            // Daily reminder.
            cancelOne(ctx, am, nm, DAILY_ID);
            if (user.dailyReminderEnabled) {
                LocalDateTime when = WalletLogic.nextDailyReminder(
                        now, user.dailyReminderHour, user.dailyReminderMinute);
                schedule(ctx, am, DAILY_ID, when,
                        "Update Your Daily Transactions 📝",
                        "Don't forget to record today's income, expenses and wallet activity!");
            }

            // Planned payment reminders.
            if (user.plannedReminderEnabled) {
                int id = PLANNED_FIRST;
                for (PlannedPayment p : WalletLogic.plannedSorted(db)) {
                    if (id > PLANNED_LAST) break;
                    if (p.isCompleted) continue;
                    LocalDateTime when = WalletLogic.plannedReminderTime(
                            p, user.plannedReminderDaysBefore);
                    if (when == null || !when.isAfter(now)) continue;
                    String daysText = user.plannedReminderDaysBefore == 0 ? "today"
                            : user.plannedReminderDaysBefore == 1 ? "tomorrow"
                            : "in " + user.plannedReminderDaysBefore + " days";
                    String body = "Your payment of " + WalletLogic.formatINR(p.amount)
                            + " is due " + daysText + " (" + Ui.prettyDate(p.nextDueDate) + ").";
                    schedule(ctx, am, id++, when,
                            "Upcoming Payment Due: " + (p.name == null ? "" : p.name) + " ⏰",
                            body);
                }
            }
        } catch (Exception ignored) {
            // Reminders are best-effort: a scheduling failure must never
            // break the screen that triggered the sync.
        }
    }

    private static UserProfile defaultUser() {
        // Same defaults as Flutter's _defaultUser + reminder fields.
        UserProfile u = new UserProfile();
        u.id = "guest_user";
        u.name = "Guest User";
        u.email = "guest@smartwallet.local";
        u.isDarkMode = true;
        return u;
    }

    private static void cancelOne(Context ctx, AlarmManager am,
                                  NotificationManager nm, int id) {
        am.cancel(pendingIntent(ctx, id, "", ""));
        if (nm != null) nm.cancel(id);
    }

    private static PendingIntent pendingIntent(Context ctx, int id,
                                               String title, String body) {
        Intent i = new Intent(ctx, NotifReceiver.class);
        i.putExtra(EXTRA_ID, id);
        i.putExtra(EXTRA_TITLE, title);
        i.putExtra(EXTRA_BODY, body);
        return PendingIntent.getBroadcast(ctx, id, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void schedule(Context ctx, AlarmManager am, int id,
                                 LocalDateTime when, String title, String body) {
        long trigger = when.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
        PendingIntent pi = pendingIntent(ctx, id, title, body);
        try {
            if (canScheduleExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi);
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi);
            }
        } catch (SecurityException e) {
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi);
            } catch (Exception ignored) {
                // Permission fully denied: stay silent rather than crash.
            }
        }
    }
}
